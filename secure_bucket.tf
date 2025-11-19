# ---------------------------------------------------------
# 1. LOGGING BUCKET (NEW - Required for auditing)
# ---------------------------------------------------------
resource "aws_s3_bucket" "log_bucket" {
  bucket = "cyb611-access-logs-phish-bits-12345" # UNIQUE NAME
}

# Security controls for the log bucket itself
resource "aws_s3_bucket_ownership_controls" "log_ownership" {
  bucket = aws_s3_bucket.log_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred" # Required for log delivery
  }
}

resource "aws_s3_bucket_acl" "log_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.log_ownership]
  bucket     = aws_s3_bucket.log_bucket.id
  acl        = "log-delivery-write"
}

# ---------------------------------------------------------
# 2. SECURE DATA BUCKET (UPDATED)
# ---------------------------------------------------------
resource "aws_s3_bucket" "secure_bucket" {
  bucket = "cyb611-secure-phish-bits-12345" # YOUR EXISTING BUCKET NAME
  
  tags = {
    Name        = "CYB611 Secure Baseline"
    Environment = "Test"
  }
}

# [EXISTING BLOCKS KEPT THE SAME]
resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.secure_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "ownership" {
  bucket = aws_s3_bucket.secure_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.secure_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.secure_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ---------------------------------------------------------
# [NEW] ENABLE ACCESS LOGGING
# ---------------------------------------------------------
resource "aws_s3_bucket_logging" "example" {
  bucket        = aws_s3_bucket.secure_bucket.id
  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "log/"
}

# ---------------------------------------------------------
# [NEW] ENFORCE HTTPS (TLS)
# ---------------------------------------------------------
resource "aws_s3_bucket_policy" "enforce_tls" {
  bucket = aws_s3_bucket.secure_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "DenyInsecureTransport",
        Effect    = "Deny",
        Principal = "*",
        Action    = "s3:*",
        Resource  = [
          aws_s3_bucket.secure_bucket.arn,
          "${aws_s3_bucket.secure_bucket.arn}/*",
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