resource "random_string" "secure_id" {
  length  = 6
  special = false
  upper   = false
}

# 1. LOGGING STORAGE
resource "aws_s3_bucket" "access_logs" {
  bucket = "cyb611-internal-logs-${random_string.secure_id.result}"
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "log_ownership" {
  bucket = aws_s3_bucket.access_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "log_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.log_ownership]
  bucket     = aws_s3_bucket.access_logs.id
  acl        = "log-delivery-write"
}

# 2. SECURE STORAGE
resource "aws_s3_bucket" "secure_storage" {
  bucket = "cyb611-finance-backup-${random_string.secure_id.result}"
  force_destroy = true
  
  tags = {
    Name        = "Finance Backup"
    Environment = "Production"
  }
}

resource "aws_s3_bucket_public_access_block" "block_public" {
  bucket = aws_s3_bucket.secure_storage.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "secure_ownership" {
  bucket = aws_s3_bucket.secure_storage.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "default_enc" {
  bucket = aws_s3_bucket.secure_storage.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "secure_versioning" {
  bucket = aws_s3_bucket.secure_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_logging" "log_config" {
  bucket        = aws_s3_bucket.secure_storage.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "log/"
}

resource "aws_s3_bucket_policy" "enforce_ssl" {
  bucket = aws_s3_bucket.secure_storage.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "DenyHttp",
        Effect    = "Deny",
        Principal = "*",
        Action    = "s3:*",
        Resource  = [
          aws_s3_bucket.secure_storage.arn,
          "${aws_s3_bucket.secure_storage.arn}/*",
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

# 3. UPLOAD SAMPLE RECORD
resource "aws_s3_object" "sample_record" {
  bucket       = aws_s3_bucket.secure_storage.id
  key          = "sensitive_data/mock_pii.csv"
  content_type = "text/csv"
  content      = "id,secret\n1,SecureData"
}