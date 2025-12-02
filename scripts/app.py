import json
import boto3
from botocore.exceptions import ClientError

# Initialize S3 client in global scope for container reuse (Warm Start)
s3 = boto3.client('s3')

def lambda_handler(event, context):
    """
    Main Entry Point. Handles Routing and Error Management.
    """
    try:
        query_params = event.get('queryStringParameters') or {}
        bucket_name = query_params.get('bucket')

        # Input Validation
        if not bucket_name:
            return create_response(400, {
                "error": "Missing parameter",
                "message": "Please provide a 'bucket' query parameter."
            })

        # Execute Audit
        report = perform_security_audit(bucket_name)
        return create_response(200, report)

    except Exception as e:
        return create_response(500, f"Critical Internal Error: {str(e)}")

def create_response(status, body):
    """Helper to format JSON response with CORS headers."""
    return {
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET"
        },
        "body": json.dumps(body)
    }

def generate_remediation(issue_type, context=None):
    """Generates context-aware remediation steps for failed checks."""
    remediations = {
        "public_block": "S3 Console > Permissions > Block Public Access. Enable 'Block all public access'.",
        "encryption": "Properties > Default Encryption. Select 'SSE-KMS' with a Customer Managed Key.",
        "policy_wildcard": "Edit Bucket Policy. Remove statements with 'Principal': '*' and 'Effect': 'Allow'.",
        "ssl_enforcement": "Update Bucket Policy. Add a 'Deny' statement for condition 'aws:SecureTransport': 'false'.",
        "versioning": "Properties > Bucket Versioning. Select 'Enable' to protect against overwrites.",
        "presigned_url": "Attach IAM Policy to users: Deny 's3:*' if 's3:signatureAge' > 900 seconds.",
        "logging": "Properties > Server access logging. Enable and select a target log bucket."
    }
    return remediations.get(issue_type, "Contact Security Operations.")

def perform_security_audit(bucket_name):
    """Executes assessment against 7 distinct security controls."""
    report = {
        "target_bucket": bucket_name,
        "scan_type": "Automated Security Compliance Audit",
        "tests": []
    }

    # TEST 1: Public Access Block
    pab_test = {"control": "1. Public Access Block", "status": "", "details": "", "remediation": "N/A"}
    try:
        conf = s3.get_public_access_block(Bucket=bucket_name)['PublicAccessBlockConfiguration']
        if all(conf.values()):
            pab_test['status'] = "PASS"
            pab_test['details'] = "Secure. All 4 blocking settings are active."
        else:
            pab_test['status'] = "FAIL"
            pab_test['details'] = f"Vulnerable. Settings found: {conf}"
            pab_test['remediation'] = generate_remediation("public_block")
    except ClientError:
        pab_test['status'] = "FAIL"
        pab_test['details'] = "No Blocking Configuration Found."
        pab_test['remediation'] = generate_remediation("public_block")
    report['tests'].append(pab_test)

    # TEST 2: Encryption Configuration
    enc_test = {"control": "2. Data Encryption", "status": "", "details": "", "remediation": "N/A"}
    try:
        rules = s3.get_bucket_encryption(Bucket=bucket_name)['ServerSideEncryptionConfiguration']['Rules']
        algo = rules[0]['ApplyServerSideEncryptionByDefault']['SSEAlgorithm']
        if algo == 'aws:kms':
            enc_test['status'] = "PASS"
            enc_test['details'] = "Secure. Using AWS KMS (Customer Managed Keys)."
        else:
            enc_test['status'] = "WARN"
            enc_test['details'] = f"Weak. Using default '{algo}'."
            enc_test['remediation'] = generate_remediation("encryption")
    except ClientError:
        enc_test['status'] = "FAIL"
        enc_test['details'] = "Unencrypted. Data stored in plain text."
        enc_test['remediation'] = generate_remediation("encryption")
    report['tests'].append(enc_test)

    # TEST 3: Bucket Policy Wildcards
    policy_test = {"control": "3. Permission Scope", "status": "PASS", "details": "", "remediation": "N/A"}
    try:
        policy_res = s3.get_bucket_policy(Bucket=bucket_name)
        policy_str = policy_res['Policy']
        if '"Principal": "*"' in policy_str.replace(" ", "") and '"Effect": "Allow"' in policy_str:
            policy_test['status'] = "FAIL"
            policy_test['details'] = "CRITICAL: Found 'Principal: *' with Allow action."
            policy_test['remediation'] = generate_remediation("policy_wildcard")
        else:
            policy_test['details'] = "Secure. No global wildcard Allow statements found."
    except ClientError:
        policy_test['status'] = "WARN"
        policy_test['details'] = "No Bucket Policy found (Default)."
    report['tests'].append(policy_test)

    # TEST 4: Secure Transport (SSL)
    ssl_test = {"control": "4. SSL/TLS Enforcement", "status": "", "details": "", "remediation": "N/A"}
    try:
        policy_res = s3.get_bucket_policy(Bucket=bucket_name)
        policy_str = policy_res['Policy']
        if '"aws:SecureTransport": "false"' in policy_str.replace(" ", ""):
            ssl_test['status'] = "PASS"
            ssl_test['details'] = "Secure. Policy explicitly denies insecure HTTP."
        else:
            ssl_test['status'] = "WARN"
            ssl_test['details'] = "Vulnerable. HTTP (Port 80) access not blocked."
            ssl_test['remediation'] = generate_remediation("ssl_enforcement")
    except ClientError:
        ssl_test['status'] = "WARN"
        ssl_test['details'] = "No Policy found to enforce SSL."
        ssl_test['remediation'] = generate_remediation("ssl_enforcement")
    report['tests'].append(ssl_test)

    # TEST 5: Versioning Status
    ver_test = {"control": "5. Data Integrity (Versioning)", "status": "", "details": "", "remediation": "N/A"}
    try:
        ver = s3.get_bucket_versioning(Bucket=bucket_name)
        if ver.get('Status') == 'Enabled':
            ver_test['status'] = "PASS"
            ver_test['details'] = "Enabled. Data recovery is possible."
        else:
            ver_test['status'] = "FAIL"
            ver_test['details'] = "Disabled. Overwritten data is lost forever."
            ver_test['remediation'] = generate_remediation("versioning")
    except:
        ver_test['status'] = "FAIL"
        ver_test['details'] = "Unknown/Disabled."
    report['tests'].append(ver_test)

    # TEST 6: Presigned URL Config Check
    url_test = {"control": "6. Presigned URL Configuration", "status": "WARN", "details": "Simulation Success (7-day URL).", "remediation": generate_remediation("presigned_url")}
    try:
        s3.generate_presigned_url('get_object', Params={'Bucket': bucket_name, 'Key': 'test.txt'}, ExpiresIn=604800)
    except Exception as e:
        url_test['status'] = "PASS"
        url_test['details'] = f"Generation Blocked: {str(e)}"
        url_test['remediation'] = "N/A"
    report['tests'].append(url_test)

    # TEST 7: Logging & CORS Audit
    log_test = {"control": "7. Logging & CORS Audit", "status": "PASS", "details": [], "remediation": "N/A"}
    try:
        logs = s3.get_bucket_logging(Bucket=bucket_name)
        if 'LoggingEnabled' in logs:
            log_test['details'].append("Logging: ENABLED")
        else:
            log_test['status'] = "WARN"
            log_test['details'].append("Logging: DISABLED")
            log_test['remediation'] = generate_remediation("logging")
    except:
        pass

    try:
        cors = s3.get_bucket_cors(Bucket=bucket_name)
        for rule in cors['CORSRules']:
            if '*' in rule.get('AllowedOrigins', []):
                log_test['status'] = "FAIL"
                log_test['details'].append("CORS: Insecure Wildcard '*'")
                break
        else:
            log_test['details'].append("CORS: Secure")
    except ClientError:
        log_test['details'].append("CORS: Default")
    
    log_test['details'] = " | ".join(log_test['details'])
    report['tests'].append(log_test)

    return report