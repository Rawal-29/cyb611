import json
import boto3
from botocore.exceptions import ClientError

# Initialize S3 client (Warm Start optimization)
s3 = boto3.client('s3')

# ---------------------------------------------------------
# SCORING CONFIGURATION (Weighted Risk)
# ---------------------------------------------------------
SCORE_WEIGHTS = {
    "public_block": 40,    # CRITICAL: Public exposure
    "policy_wildcard": 30, # CRITICAL: Global access allowed
    "encryption": 10,      # HIGH: Data protection
    "versioning": 10,      # MEDIUM: Data integrity
    "ssl_enforcement": 5,  # LOW: Network security
    "logging": 5           # LOW: Forensics
}

def lambda_handler(event, context):
    """
    Main Entry Point.
    Route 1: /?bucket=name -> Detailed Audit (with Remediation)
    Route 2: /             -> Dashboard View (All Buckets, Scores Only)
    """
    try:
        query_params = event.get('queryStringParameters') or {}
        bucket_name = query_params.get('bucket')

        if bucket_name:
            # Route 1: Scan specific bucket
            report = perform_security_audit(bucket_name, include_remediation=True)
            return create_response(200, report)
        else:
            # Route 2: Scan all project buckets
            summary = scan_all_buckets()
            return create_response(200, summary)

    except Exception as e:
        return create_response(500, {"error": f"Internal Error: {str(e)}"})

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

def scan_all_buckets():
    """Lists all buckets, filters for project 'cyb611', and generates scores."""
    try:
        all_buckets = s3.list_buckets()
        project_buckets = []
        
        for b in all_buckets['Buckets']:
            name = b['Name']
            # Filter: Only scan buckets related to this project
            if "cyb611" in name:
                # Run audit WITHOUT remediation details to keep it clean
                audit = perform_security_audit(name, include_remediation=False)
                project_buckets.append(audit)
        
        return {
            "dashboard_title": "CYB611 Security Posture Dashboard",
            "total_scanned": len(project_buckets),
            "buckets": project_buckets
        }
    except Exception as e:
        return {"error": f"Failed to list buckets: {str(e)}"}

def calculate_grade(score):
    if score >= 90: return "A (Secure)"
    if score >= 80: return "B (Good)"
    if score >= 60: return "C (At Risk)"
    if score >= 40: return "D (High Risk)"
    return "F (Critical)"

def perform_security_audit(bucket_name, include_remediation=True):
    """Executes 7 security checks and calculates a risk score."""
    
    current_score = 100
    report = {
        "target_bucket": bucket_name,
        "scan_type": "Automated Security Compliance Audit",
        "tests": []
    }

    # Helper to add test results
    def add_result(control, status, details, remediation_text, weight_key=None):
        nonlocal current_score
        if status != "PASS" and weight_key:
            current_score -= SCORE_WEIGHTS.get(weight_key, 0)
        
        test_entry = {
            "control": control,
            "status": status,
            "details": details
        }
        if include_remediation and status != "PASS":
            test_entry["remediation"] = remediation_text
        
        report["tests"].append(test_entry)

    # 1. Public Access Block
    try:
        conf = s3.get_public_access_block(Bucket=bucket_name)['PublicAccessBlockConfiguration']
        if all(conf.values()):
            add_result("1. Public Access Block", "PASS", "Secure. All settings active.", "")
        else:
            add_result("1. Public Access Block", "FAIL", f"Vulnerable. Settings: {conf}", 
                       "Enable 'Block all public access' in Permissions.", "public_block")
    except ClientError:
        add_result("1. Public Access Block", "FAIL", "No Configuration Found.", 
                   "Enable 'Block all public access' in Permissions.", "public_block")

    # 2. Encryption
    try:
        enc = s3.get_bucket_encryption(Bucket=bucket_name)
        rules = enc['ServerSideEncryptionConfiguration']['Rules']
        algo = rules[0]['ApplyServerSideEncryptionByDefault']['SSEAlgorithm']
        if algo == 'aws:kms':
            add_result("2. Data Encryption", "PASS", "Secure (SSE-KMS).", "")
        else:
            add_result("2. Data Encryption", "WARN", f"Weak. Using default '{algo}'.", 
                       "Upgrade to SSE-KMS for better control.", "encryption")
    except ClientError:
        add_result("2. Data Encryption", "FAIL", "Unencrypted (Plain Text).", 
                   "Enable Default Encryption in Properties.", "encryption")

    # 3. Policy Wildcards
    try:
        policy = s3.get_bucket_policy(Bucket=bucket_name)['Policy']
        if '"Principal": "*"' in policy.replace(" ", "") and '"Effect": "Allow"' in policy:
            add_result("3. Permission Scope", "FAIL", "CRITICAL: Global Wildcard (*) Allow found.", 
                       "Remove statements allowing access to '*'.", "policy_wildcard")
        else:
            add_result("3. Permission Scope", "PASS", "Secure. No global wildcards.", "")
    except ClientError:
        # No policy is neutral/safe by default (unless ACLs are open)
        add_result("3. Permission Scope", "PASS", "No Bucket Policy (Default Private).", "")

    # 4. SSL Enforcement
    try:
        policy = s3.get_bucket_policy(Bucket=bucket_name)['Policy']
        if '"aws:SecureTransport": "false"' in policy.replace(" ", ""):
            add_result("4. SSL/TLS Enforcement", "PASS", "Secure. HTTP denied.", "")
        else:
            add_result("4. SSL/TLS Enforcement", "WARN", "HTTP allowed (No Deny Policy).", 
                       "Add Bucket Policy to deny non-SSL transport.", "ssl_enforcement")
    except:
        add_result("4. SSL/TLS Enforcement", "WARN", "HTTP allowed (No Policy).", 
                   "Add Bucket Policy to deny non-SSL transport.", "ssl_enforcement")

    # 5. Versioning
    try:
        ver = s3.get_bucket_versioning(Bucket=bucket_name)
        if ver.get('Status') == 'Enabled':
            add_result("5. Data Integrity", "PASS", "Versioning Enabled.", "")
        else:
            add_result("5. Data Integrity", "FAIL", "Versioning Disabled/Suspended.", 
                       "Enable Bucket Versioning in Properties.", "versioning")
    except:
        add_result("5. Data Integrity", "FAIL", "Unknown State.", "Enable Versioning.", "versioning")

    # 6. Presigned URL (Simulation)
    # Note: We don't deduct points here as it's a capability check, not a config error
    add_result("6. Presigned URL Config", "WARN", "Simulation: 7-day URL generation possible.", 
               "Restrict IAM 's3:signatureAge' if needed.")

    # 7. Logging & CORS
    try:
        logs = s3.get_bucket_logging(Bucket=bucket_name)
        cors = {}
        try: 
            cors = s3.get_bucket_cors(Bucket=bucket_name) 
        except: 
            pass

        issues = []
        if 'LoggingEnabled' not in logs:
            issues.append("Logging Disabled")
        
        cors_rules = cors.get('CORSRules', [])
        for r in cors_rules:
            if '*' in r.get('AllowedOrigins', []):
                issues.append("CORS Wildcard (*)")
        
        if not issues:
            add_result("7. Logging & CORS", "PASS", "Logging On & CORS Restricted.", "")
        else:
            add_result("7. Logging & CORS", "FAIL", " | ".join(issues), 
                       "Enable Logging and restrict CORS origins.", "logging")
    except:
        pass

    # Final Calculation
    final_score = max(0, current_score)
    report["security_score"] = f"{final_score}/100"
    report["risk_grade"] = calculate_grade(final_score)

    return report