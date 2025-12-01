import json
import boto3
from botocore.exceptions import ClientError

s3 = boto3.client('s3')

def lambda_handler(event, context):
    try:
        query_params = event.get('queryStringParameters') or {}
        bucket_name = query_params.get('bucket')
        
        if not bucket_name:
            return create_response(400, "Error: Missing bucket parameter")

        report = scan_bucket(bucket_name)
        return create_response(200, report)

    except Exception as e:
        return create_response(500, str(e))

def create_response(status, body):
    return {
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps(body)
    }

def scan_bucket(bucket_name):
    results = {"target": bucket_name, "findings": {}}
    
    try:
        pab = s3.get_public_access_block(Bucket=bucket_name)
        conf = pab['PublicAccessBlockConfiguration']
        results['findings']['public_access_block'] = "PASS" if all(conf.values()) else "FAIL"
    except ClientError:
        results['findings']['public_access_block'] = "FAIL (Not Found)"

    try:
        enc = s3.get_bucket_encryption(Bucket=bucket_name)
        rules = enc['ServerSideEncryptionConfiguration']['Rules']
        algo = rules[0]['ApplyServerSideEncryptionByDefault']['SSEAlgorithm']
        results['findings']['encryption'] = "PASS" if algo == 'aws:kms' else f"WARN ({algo})"
    except ClientError:
        results['findings']['encryption'] = "FAIL (None)"

    try:
        ver = s3.get_bucket_versioning(Bucket=bucket_name)
        results['findings']['versioning'] = "PASS" if ver.get('Status') == 'Enabled' else "FAIL"
    except ClientError:
        results['findings']['versioning'] = "FAIL"

    try:
        
        policy_res = s3.get_bucket_policy(Bucket=bucket_name)
        policy_str = policy_res['Policy']
        
        if '"Principal": "*"' in policy_str.replace(" ", "") and '"Effect": "Allow"' in policy_str:
             results['findings']['public_policy'] = "FAIL (Wildcard Found)"
        else:
             results['findings']['public_policy'] = "PASS"
             
        if '"aws:SecureTransport": "false"' in policy_str.replace(" ", ""):
             results['findings']['ssl_enforced'] = "PASS"
        else:
             results['findings']['ssl_enforced'] = "WARN (Not Enforced)"
        
    except ClientError:
        results['findings']['public_policy'] = "WARN (No Policy)"
        results['findings']['ssl_enforced'] = "WARN (No Policy)"

    return results