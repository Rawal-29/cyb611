# ---------------------------------------------------------
# 1. LOGGING BUCKET (for this misconfigured bucket)
# ---------------------------------------------------------
resource "aws_s3_bucket" "log_bucket_public_rw" {
  bucket = "cyb611-secure-phish-bits-public-rw-logs" # MUST be globally unique
}

resource "aws_s3_bucket_ownership_controls" "log_public_rw_ownership" {
  bucket = aws_s3_bucket.log_bucket_public_rw.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "log_public_rw_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.log_public_rw_ownership]
  bucket     = aws_s3_bucket.log_bucket_public_rw.id
  acl        = "log-delivery-write"
}



# ---------------------------------------------------------
# 2. INSECURE DATA BUCKET – PUBLIC READ/WRITE
# ---------------------------------------------------------
resource "aws_s3_bucket" "insecure_bucket2" {
  bucket = "cyb611-secure-phish-bits-public-rw" # NEW misconfigured bucket name
  
  tags = {
    Name        = "CYB611 Insecure – Public Read/Write"
    Environment = "Test"
    Misconfig   = "public-read-write"
  }
}

# Public access block misconfigured to allow public policies & access
resource "aws_s3_bucket_public_access_block" "public_rw_block" {
  bucket = aws_s3_bucket.insecure_bucket2.id

  # Loosened settings to permit public access
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Ownership controls (still enabled, like secure baseline)
resource "aws_s3_bucket_ownership_controls" "public_rw_ownership" {
  bucket = aws_s3_bucket.insecure_bucket2.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
# Encryption controls (still enabled, like secure baseline)
resource "aws_s3_bucket_server_side_encryption_configuration" "public_rw_encryption" {
  bucket = aws_s3_bucket.insecure_bucket2.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Versioning (kept, like secure baseline)
resource "aws_s3_bucket_versioning" "public_rw_versioning" {
  bucket = aws_s3_bucket.insecure_bucket2.id
  versioning_configuration {
    status = "Enabled"
  }
}


# ---------------------------------------------------------
# ENFORCE HTTPS (TLS)-still enabled, like secure baseline
# ---------------------------------------------------------
resource "aws_s3_bucket_policy" "public_rw_enforce_tls" {
  bucket = aws_s3_bucket.insecure_bucket2.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [
          aws_s3_bucket.insecure_bucket2.arn,
          "${aws_s3_bucket.insecure_bucket2.arn}/*",
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



# ---------------------------------------------------------
# 3. ENABLE ACCESS LOGGING FOR THE MISCONFIGURED BUCKET
# ---------------------------------------------------------
resource "aws_s3_bucket_logging" "public_rw_logging" {
  bucket        = aws_s3_bucket.insecure_bucket2.id
  target_bucket = aws_s3_bucket.log_bucket_public_rw.id
  target_prefix = "log/"
}

# ---------------------------------------------------------
# 4. PUBLIC READ/WRITE BUCKET POLICY
# ---------------------------------------------------------
resource "aws_s3_bucket_policy" "public_rw_policy" {
  bucket = aws_s3_bucket.insecure_bucket2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadWrite"
        Effect    = "Allow"
        Principal = "*"
        Action    = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${aws_s3_bucket.insecure_bucket2.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.public_rw_block]
}