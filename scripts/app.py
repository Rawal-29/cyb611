import json
import boto3
from botocore.exceptions import ClientError


s3 = boto3.client('s3')

def lambda_handler(event, context):
    """
    Main Entry Point.
    Supported Routes:
    1. /?bucket=NAME       -> Deep dive one bucket (with remediation)
    2. /?buckets=A,B,C     -> Scan specific list (dashboard view)
    3. /?filter=cyb611     -> Scan all matching filter (dashboard view)
    4. /                   -> Scan EVERYTHING (dashboard view)
    """
    try:
        params = event.get('queryStringParameters') or {}
        if params.get('bucket'):
            report = perform_security_audit(params['bucket'], include_remediation=True)
            return create_response(200, report)
        
        elif params.get('buckets'):
            target_list = [b.strip() for b in params['buckets'].split(',')]
            summary = scan_list_of_buckets(target_list)
            return create_response(200, summary)
            
        else:
            name_filter = params.get('filter')
            summary = scan_all_buckets(name_filter)
            return create_response(200, summary)

    except Exception as e:
        return create_response(500, {"error": f"Internal Error: {str(e)}"})

def create_response(status, body):
    return {
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps(body)
    }

def scan_list_of_buckets(bucket_names):
    results = []
    for name in bucket_names:
        # Check if bucket exists/is accessible before scanning
        try:
            s3.head_bucket(Bucket=name)
            results.append(perform_security_audit(name, include_remediation=False))
        except ClientError:
            results.append({"bucket_name": name, "error": "Access Denied or Not Found"})
            
    return {
        "dashboard_title": "Targeted Compliance Scan",
        "total_scanned": len(results),
        "buckets": results
    }

def scan_all_buckets(name_filter=None):
    try:
        all_buckets = s3.list_buckets()
        results = []
        
        for b in all_buckets['Buckets']:
            name = b['Name']
            # Apply filter if provided
            if name_filter and name_filter not in name:
                continue
            
            # Skip infrastructure buckets (State/Logs) to keep dashboard clean
            if "state" in name or "log" in name:
                continue

            results.append(perform_security_audit(name, include_remediation=False))
        
        title = f"Account Scan ({name_filter})" if name_filter else "Full Account Scan"
        return {
            "dashboard_title": title,
            "total_scanned": len(results),
            "buckets": results
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
    current_score = 100
    findings = []
    is_publically_exposed = False

    # 1. Check Public Access Block (The Gatekeeper)
    try:
        conf = s3.get_public_access_block(Bucket=bucket_name)['PublicAccessBlockConfiguration']
        if not all(conf.values()):
            is_publically_exposed = True
            current_score -= 40 
            findings.append({"control": "1. Public Access Block", "status": "FAIL", "details": "Guardrails disabled."})
        else:
            findings.append({"control": "1. Public Access Block", "status": "PASS", "details": "Active."})
    except ClientError:
        is_publically_exposed = True
        current_score -= 40
        findings.append({"control": "1. Public Access Block", "status": "FAIL", "details": "No config found."})

    # 2. Check Bucket Policy (Context-Aware)
    try:
        policy = s3.get_bucket_policy(Bucket=bucket_name)['Policy']
        if '"Principal": "*"' in policy.replace(" ", "") and '"Effect": "Allow"' in policy:
            if is_publically_exposed:
                current_score -= 30 
                findings.append({"control": "2. Bucket Policy", "status": "FAIL", "details": "Global Wildcard (*)."})
            else:
                findings.append({"control": "2. Bucket Policy", "status": "WARN", "details": "Mitigated: Wildcard Policy exists, but blocked."})
        else:
            findings.append({"control": "2. Bucket Policy", "status": "PASS", "details": "Secure."})
    except ClientError:
        findings.append({"control": "2. Bucket Policy", "status": "PASS", "details": "Default."})

    # 3. Check CORS (Context-Aware)
    try:
        cors = s3.get_bucket_cors(Bucket=bucket_name)
        has_wildcard = any('*' in r.get('AllowedOrigins', []) for r in cors['CORSRules'])
        if has_wildcard:
            if is_publically_exposed:
                current_score -= 10 
                findings.append({"control": "3. CORS", "status": "FAIL", "details": "Insecure Wildcard (*)."})
            else:
                findings.append({"control": "3. CORS", "status": "WARN", "details": "Mitigated: Wildcard CORS."})
        else:
            findings.append({"control": "3. CORS", "status": "PASS", "details": "Secure."})
    except:
        findings.append({"control": "3. CORS", "status": "PASS", "details": "Default."})

    # 4. Check Encryption (Independent Risk)
    try:
        s3.get_bucket_encryption(Bucket=bucket_name)
        findings.append({"control": "4. Encryption", "status": "PASS", "details": "Enabled."})
    except ClientError:
        current_score -= 10
        findings.append({"control": "4. Encryption", "status": "FAIL", "details": "Unencrypted."})

    # 5. Check Versioning (Independent Risk)
    try:
        ver = s3.get_bucket_versioning(Bucket=bucket_name)
        if ver.get('Status') == 'Enabled':
            findings.append({"control": "5. Versioning", "status": "PASS", "details": "Enabled."})
        else:
            current_score -= 10
            findings.append({"control": "5. Versioning", "status": "FAIL", "details": "Disabled."})
    except:
        current_score -= 10
        findings.append({"control": "5. Versioning", "status": "FAIL", "details": "Disabled."})

    # 6. SSL Enforcement
    try:
        policy = s3.get_bucket_policy(Bucket=bucket_name)['Policy']
        if '"aws:SecureTransport": "false"' in policy.replace(" ", ""):
            findings.append({"control": "6. SSL Enforcement", "status": "PASS", "details": "Enforced."})
        else:
            current_score -= 5
            findings.append({"control": "6. SSL Enforcement", "status": "WARN", "details": "Not Enforced."})
    except:
        current_score -= 5
        findings.append({"control": "6. SSL Enforcement", "status": "WARN", "details": "Not Enforced."})

    # 7. Logging Check
    try:
        logs = s3.get_bucket_logging(Bucket=bucket_name)
        if 'LoggingEnabled' in logs:
            findings.append({"control": "7. Logging", "status": "PASS", "details": "Enabled."})
        else:
            current_score -= 5
            findings.append({"control": "7. Logging", "status": "WARN", "details": "Disabled."})
    except:
        pass

    final_score = max(0, current_score)
    
    report = {
        "bucket_name": bucket_name,
        "security_score": f"{final_score}/100",
        "risk_grade": calculate_grade(final_score),
        "access_type": "Public" if is_publically_exposed else "Private",
        "tests": findings
    }
    
    if include_remediation and final_score < 100:
        report["remediation_note"] = "Please review failed controls in AWS Console."

    return report