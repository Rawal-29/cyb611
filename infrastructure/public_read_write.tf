resource "random_string" "public_id" {
  length  = 6
  special = false
  upper   = false
}

# --- LOGGING SETUP (MATCHING SECURE BASELINE) ---
resource "aws_s3_bucket" "public_logs" {
  bucket = "cyb611-insecure-public-rw-logs-${random_string.public_id.result}"
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "public_log_ownership" {
  bucket = aws_s3_bucket.public_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "public_log_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.public_log_ownership]
  bucket     = aws_s3_bucket.public_logs.id
  acl        = "log-delivery-write"
}

# --- MAIN BUCKET ---
resource "aws_s3_bucket" "public_assets" {
  bucket = "cyb611-insecure-public-rw-${random_string.public_id.result}"
  force_destroy = true
  
  tags = {
    Name = "Insecure Public RW"
  }
}

# MISCONFIGURATION: Guardrails Disabled (Required for Public ACL)
resource "aws_s3_bucket_public_access_block" "public_block" {
  bucket = aws_s3_bucket.public_assets.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# MODIFIED: Changed to 'Preferred' to allow ACLs (Necessary for this test)
resource "aws_s3_bucket_ownership_controls" "public_ownership" {
  bucket = aws_s3_bucket.public_assets.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# MISCONFIGURATION: Public ACL (The specific vulnerability)
resource "aws_s3_bucket_acl" "public_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.public_ownership,
    aws_s3_bucket_public_access_block.public_block
  ]
  bucket = aws_s3_bucket.public_assets.id
  acl    = "public-read"
}

# SECURE: Encryption Enabled (Baseline)
resource "aws_s3_bucket_server_side_encryption_configuration" "public_enc" {
  bucket = aws_s3_bucket.public_assets.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# SECURE: Versioning Enabled (Baseline)
resource "aws_s3_bucket_versioning" "public_versioning" {
  bucket = aws_s3_bucket.public_assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

# SECURE: Logging Enabled (Baseline)
resource "aws_s3_bucket_logging" "public_logging_config" {
  bucket        = aws_s3_bucket.public_assets.id
  target_bucket = aws_s3_bucket.public_logs.id
  target_prefix = "log/"
}

resource "aws_s3_bucket_policy" "enforce_tls_public" {
  bucket = aws_s3_bucket.public_assets.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "DenyInsecureTransport",
        Effect    = "Deny",
        Principal = "*",
        Action    = "s3:*",
        Resource  = [
          aws_s3_bucket.public_assets.arn,
          "${aws_s3_bucket.public_assets.arn}/*",
        ],
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
resource "aws_s3_object" "web_asset" {
  bucket       = aws_s3_bucket.public_assets.id
  key          = "sensitive_data/mock_pii.csv"
  content_type = "text/csv"
  content      = "id,secret\n1,PublicData"
}