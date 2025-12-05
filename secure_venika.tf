# ========================================
# COMPREHENSIVE SECURE S3 BUCKET
# ========================================

resource "aws_s3_bucket" "fully_secure" {
  bucket = "fully-secure-bucket-example"
}

# Enable versioning for data protection
resource "aws_s3_bucket_versioning" "secure" {
  bucket = aws_s3_bucket.fully_secure.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "fully_secure" {
  bucket = aws_s3_bucket.fully_secure.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "fully_secure" {
  bucket = aws_s3_bucket.fully_secure.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Least privilege bucket policy
resource "aws_s3_bucket_policy" "fully_secure" {
  bucket = aws_s3_bucket.fully_secure.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnforcedTLSRequestsOnly"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          "${aws_s3_bucket.fully_secure.arn}",
          "${aws_s3_bucket.fully_secure.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# Enable logging
resource "aws_s3_bucket_logging" "secure" {
  bucket = aws_s3_bucket.fully_secure.id

  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "log/"
}

resource "aws_s3_bucket" "log_bucket" {
  bucket = "secure-bucket-logs"
}

resource "aws_s3_bucket_acl" "log_bucket_acl" {
  bucket = aws_s3_bucket.log_bucket.id
  acl    = "log-delivery-write"
}
