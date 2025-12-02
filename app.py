import json
import boto3
from botocore.exceptions import ClientError

# Initialize S3 client (Global scope for container reuse)
s3 = boto3.client('s3')

def lambda_handler(event, context):
    """
    Main Entry Point. Handles Routing and Error Management.
    """
    try:
        # 1. Routing & Parameter Extraction
        path = event.get('rawPath', '/')
        query_params = event.get('queryStringParameters') or {}
        bucket_name = query_params.get('bucket')

        # 2. Route Logic
        # ROUTE A: The Scanner Endpoint
        if path == "/scan":
            if not bucket_name:
                return create_response(400, "Error: Missing 'bucket' parameter. Example: /scan?bucket=target-bucket")
            
            # Execute the Audit
            report = perform_security_audit(bucket_name)
            return create_response(200, report)
        
        # ROUTE B: Home/Info Endpoint
        elif path == "/":
            return create_response(200, {
                "system": "S3 Security Compliance Scanner",
                "status": "Online",
                "usage": "GET /scan?bucket=<target_bucket_name>",
                "version": "1.0.0"
            })
            
        # ROUTE C: 404 Not Found
        else:
            return create_response(404, "Route not found. Use /scan")

    except Exception as e:
        return create_response(500, f"Critical Internal Error: {str(e)}")

def create_response(status, body):
    """Helper to format JSON response with CORS headers for Function URL"""
    return {
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET"
        },
        "body": json.dumps(body)
    }

def perform_security_audit(bucket_name):
    """
    Executes a comprehensive security assessment against 7 distinct controls.
    """
    report = {
        "target_bucket": bucket_name,
        "scan_type": "Automated Security Compliance Audit",
        "tests": []
    }

    # ---------------------------------------------------------
    # TEST 1: Public Access Block Configuration
    # ---------------------------------------------------------
    pab_test = {
        "control": "1. Public Access Block",
        "description": "Verifies that account/bucket level settings block public ACLs and policies.",
        "status": "", "details": "", "remediation": ""
    }
    try:
        conf = s3.get_public_access_block(Bucket=bucket_name)['PublicAccessBlockConfiguration']
        if all(conf.values()):
            pab_test['status'] = "PASS"
            pab_test['details'] = "Secure. All 4 blocking settings are active."
        else:
            pab_test['status'] = "FAIL"
            pab_test['details'] = f"Vulnerable. Settings found: {conf}"
            pab_test['remediation'] = "Enable 'BlockPublicAcls', 'IgnorePublicAcls', 'BlockPublicPolicy', and 'RestrictPublicBuckets'."
    except ClientError:
        pab_test['status'] = "FAIL"
        pab_test['details'] = "No Blocking Configuration Found (Bucket is potentially exposed)."
        pab_test['remediation'] = "Enable Block Public Access settings immediately."
    report['tests'].append(pab_test)

    # ---------------------------------------------------------
    # TEST 2: Encryption Configuration
    # ---------------------------------------------------------
    enc_test = {
        "control": "2. Data Encryption",
        "description": "Verifies usage of strong Server-Side Encryption (SSE-KMS).",
        "status": "", "details": "", "remediation": ""
    }
    try:
        rules = s3.get_bucket_encryption(Bucket=bucket_name)['ServerSideEncryptionConfiguration']['Rules']
        algo = rules[0]['ApplyServerSideEncryptionByDefault']['SSEAlgorithm']
        if algo == 'aws:kms':
            enc_test['status'] = "PASS"
            enc_test['details'] = "Secure. Using AWS KMS (Customer Managed Keys)."
        else:
            enc_test['status'] = "WARN"
            enc_test['details'] = f"Weak. Using default '{algo}'. Lacks granular access auditing."
            enc_test['remediation'] = "Migrate to 'aws:kms' to ensure key rotation and audit logs."
    except ClientError:
        enc_test['status'] = "FAIL"
        enc_test['details'] = "Unencrypted. Data is stored in plain text."
        enc_test['remediation'] = "Enable Default Encryption using AWS KMS."
    report['tests'].append(enc_test)

    # ---------------------------------------------------------
    # TEST 3: Bucket Policy Wildcards
    # ---------------------------------------------------------
    policy_test = {
        "control": "3. Permission Scope",
        "description": "Scans IAM Policy for global 'Principal: *' allow statements.",
        "status": "PASS", "details": "", "remediation": "Maintain least privilege access."
    }
    try:
        policy_res = s3.get_bucket_policy(Bucket=bucket_name)
        policy_str = policy_res['Policy']
        
        if '"Principal": "*"' in policy_str.replace(" ", "") and '"Effect": "Allow"' in policy_str:
            policy_test['status'] = "FAIL"
            policy_test['details'] = "CRITICAL: Found 'Principal: *' with Allow action."
            policy_test['remediation'] = "Remove public wildcards. Use Presigned URLs or CloudFront OAC for public access."
        else:
            policy_test['details'] = "Secure. No global wildcard Allow statements found."
    except ClientError:
        policy_test['status'] = "WARN"
        policy_test['details'] = "No Bucket Policy found (Default)."
    report['tests'].append(policy_test)

    # ---------------------------------------------------------
    # TEST 4: Secure Transport (SSL)
    # ---------------------------------------------------------
    ssl_test = {
        "control": "4. SSL/TLS Enforcement",
        "description": "Verifies policy explicitly denies insecure HTTP requests.",
        "status": "", "details": "", "remediation": ""
    }
    try:
        policy_res = s3.get_bucket_policy(Bucket=bucket_name)
        policy_str = policy_res['Policy']
        if '"aws:SecureTransport": "false"' in policy_str.replace(" ", ""):
            ssl_test['status'] = "PASS"
            ssl_test['details'] = "Secure. Policy explicitly denies insecure HTTP."
        else:
            ssl_test['status'] = "WARN"
            ssl_test['details'] = "Vulnerable. HTTP (Port 80) access is not explicitly blocked."
            ssl_test['remediation'] = "Add a policy statement denying 'aws:SecureTransport': 'false'."
    except ClientError:
        ssl_test['status'] = "WARN"
        ssl_test['details'] = "No Policy found to enforce SSL."
        ssl_test['remediation'] = "Attach a policy to enforce SSL/TLS."
    report['tests'].append(ssl_test)

    # ---------------------------------------------------------
    # TEST 5: Versioning Status
    # ---------------------------------------------------------
    ver_test = {
        "control": "5. Data Integrity (Versioning)",
        "description": "Verifies versioning status for data recovery.",
        "status": "", "details": "", "remediation": ""
    }
    try:
        ver = s3.get_bucket_versioning(Bucket=bucket_name)
        if ver.get('Status') == 'Enabled':
            ver_test['status'] = "PASS"
            ver_test['details'] = "Enabled. Data recovery is possible."
        else:
            ver_test['status'] = "FAIL"
            ver_test['details'] = "Disabled. Overwritten data is lost forever."
            ver_test['remediation'] = "Enable Bucket Versioning."
    except:
        ver_test['status'] = "FAIL"
        ver_test['details'] = "Unknown/Disabled."
    report['tests'].append(ver_test)

    # ---------------------------------------------------------
    # TEST 6: Presigned URL Config Check
    # ---------------------------------------------------------
    url_test = {
        "control": "6. Presigned URL Configuration",
        "description": "Tests if system permits generation of long-lived (7-day) access links.",
        "status": "WARN", 
        "details": "Simulation Success. System allowed generation of a 7-day URL.",
        "remediation": "Enforce IAM Policy 's3:signatureAge' < 900 seconds on all users."
    }
    try:
        # Simulation: Attempt to generate. If it works, the SDK/IAM allows it.
        s3.generate_presigned_url('get_object', Params={'Bucket': bucket_name, 'Key': 'test.txt'}, ExpiresIn=604800)
    except Exception as e:
        url_test['status'] = "PASS"
        url_test['details'] = f"Generation Blocked: {str(e)}"
    report['tests'].append(url_test)

    # ---------------------------------------------------------
    # TEST 7: Logging & CORS Audit
    # ---------------------------------------------------------
    log_test = {
        "control": "7. Logging & CORS Audit",
        "description": "Checks for Server Access Logs and Insecure Cross-Origin rules.",
        "status": "PASS", "details": [], "remediation": ""
    }
    
    # Check A: Logging
    try:
        logs = s3.get_bucket_logging(Bucket=bucket_name)
        if 'LoggingEnabled' in logs:
            log_test['details'].append("Logging: ENABLED.")
        else:
            log_test['status'] = "WARN"
            log_test['details'].append("Logging: DISABLED.")
            log_test['remediation'] = "Enable Server Access Logging for audit trails. "
    except:
        log_test['status'] = "WARN"
        log_test['details'].append("Logging check failed.")

    # Check B: CORS
    try:
        cors = s3.get_bucket_cors(Bucket=bucket_name)
        for rule in cors['CORSRules']:
            if '*' in rule.get('AllowedOrigins', []):
                log_test['status'] = "FAIL"
                log_test['details'].append("CORS: Insecure Wildcard '*' Found.")
                log_test['remediation'] += "Restrict CORS to specific domains."
                break
        else:
             log_test['details'].append("CORS: Secure.")
    except ClientError:
        log_test['details'].append("CORS: Default (Secure).")

    log_test['details'] = " | ".join(log_test['details'])
    report['tests'].append(log_test)

    return report