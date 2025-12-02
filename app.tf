data "aws_caller_identity" "current" {}

# =============================================================================
# 1. SHARED SECURITY RESOURCES
# =============================================================================

# KMS Key for Strong Encryption
resource "aws_kms_key" "main" {
  description             = "Master KMS Key for S3 Compliance Project"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

# Log Bucket for Access Audits
resource "aws_s3_bucket" "logs" {
  bucket = "cyb611-access-logs-storage-001"
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "logs" {
  depends_on = [aws_s3_bucket_ownership_controls.logs]
  bucket     = aws_s3_bucket.logs.id
  acl        = "log-delivery-write"
}

# =============================================================================
# 2. SECURE BUCKET (PASSES ALL CHECKS)
# =============================================================================
resource "aws_s3_bucket" "secure" {
  bucket = "cyb611-secure-compliance-bucket"
}

resource "aws_s3_bucket_versioning" "secure" {
  bucket = aws_s3_bucket.secure.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "secure" {
  bucket = aws_s3_bucket.secure.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "secure" {
  bucket = aws_s3_bucket.secure.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "secure" {
  bucket        = aws_s3_bucket.secure.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "secure-bucket-logs/"
}

resource "aws_s3_bucket_policy" "secure" {
  bucket = aws_s3_bucket.secure.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceTLS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = "${aws_s3_bucket.secure.arn}/*"
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      }
    ]
  })
}

# =============================================================================
# 3. INSECURE BUCKET (FAILS CHECKS - For Demonstration)
# =============================================================================
resource "aws_s3_bucket" "insecure" {
  bucket        = "cyb611-insecure-public-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "insecure" {
  bucket = aws_s3_bucket.insecure.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "insecure" {
  bucket     = aws_s3_bucket.insecure.id
  depends_on = [aws_s3_bucket_public_access_block.insecure] # Critical for race condition
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadWrite"
      Effect    = "Allow"
      Principal = "*"
      Action    = ["s3:GetObject", "s3:PutObject"]
      Resource  = "${aws_s3_bucket.insecure.arn}/*"
    }]
  })
}

# =============================================================================
# 4. SERVERLESS SCANNER (LAMBDA)
# =============================================================================

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/app.py"
  output_path = "${path.module}/package.zip"
}

resource "aws_iam_role" "scanner" {
  name = "S3ScannerRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "scanner" {
  name = "S3ScannerPolicy"
  role = aws_iam_role.scanner.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketPublicAccessBlock",
          "s3:GetBucketEncryption",
          "s3:GetBucketVersioning",
          "s3:GetBucketPolicy",
          "s3:GetBucketAcl",
          "s3:GetBucketLogging",
          "s3:GetBucketCORS"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_lambda_function" "scanner" {
  function_name    = "S3SecurityScanner"
  role             = aws_iam_role.scanner.arn
  handler          = "app.lambda_handler"
  runtime          = "python3.9"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 15
}

resource "aws_lambda_function_url" "scanner" {
  function_name      = aws_lambda_function.scanner.function_name
  authorization_type = "NONE"
}

output "api_endpoint" {
  value = aws_lambda_function_url.scanner.function_url
}