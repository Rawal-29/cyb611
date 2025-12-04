# ---------------------------------------------------------
# 1. LOGGING BUCKET (NEW - Required for auditing)
# ---------------------------------------------------------
resource "aws_s3_bucket" "log_bucket_no_encryption" {
  bucket = "cyb611-secure-phish-bits-no-encryption-logs" # UNIQUE NAME
}


resource "aws_s3_bucket_ownership_controls" "log_ownership_no_encryption" {
  bucket = aws_s3_bucket.log_bucket_no_encryption.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "log_acl_no_encryption" {
  depends_on = [aws_s3_bucket_ownership_controls.log_ownership_no_encryption]
  bucket     = aws_s3_bucket.log_bucket_no_encryption.id
  acl        = "log-delivery-write"
}

# Public access block for logging bucket - allows log delivery service to write
# Note: Log delivery requires ACLs to be allowed, so we can't block public ACLs
resource "aws_s3_bucket_public_access_block" "log_public_access_no_encryption" {
  bucket = aws_s3_bucket.log_bucket_no_encryption.id

  block_public_acls       = false # Required for log delivery ACL
  block_public_policy     = true  # Still block public policies
  ignore_public_acls      = false # Required for log delivery ACL
  restrict_public_buckets = true  # Still restrict public bucket access
}


# ---------------------------------------------------------
# 2. INSECURE DATA BUCKET 
# ---------------------------------------------------------
resource "aws_s3_bucket" "insecure_bucket1" {
  bucket = "cyb611-secure-phish-bits-no-encryption" # YOUR EXISTING BUCKET NAME

  tags = {
    Name        = "CYB611 Insecure – No Encryption"
    Environment = "Test"
    Misconfig   = "no-encryption"
  }
}


#  EXISTING BLOCK WITHOUT THE ENCRYPTION CONFIG 
resource "aws_s3_bucket_public_access_block" "block_no_encryption" {
  bucket                  = aws_s3_bucket.insecure_bucket1.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Ownership controls (still enabled, like secure baseline)
resource "aws_s3_bucket_ownership_controls" "ownership_no_encryption" {
  bucket = aws_s3_bucket.insecure_bucket1.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "versioning_no_encryption" {
  bucket = aws_s3_bucket.insecure_bucket1.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ---------------------------------------------------------
# [NEW] ENABLE ACCESS LOGGING
# ---------------------------------------------------------
resource "aws_s3_bucket_logging" "logging_no_encryption" {
  bucket        = aws_s3_bucket.insecure_bucket1.id
  target_bucket = aws_s3_bucket.log_bucket_no_encryption.id
  target_prefix = "log/"

  depends_on = [
    aws_s3_bucket_acl.log_acl_no_encryption,
    aws_s3_bucket_public_access_block.log_public_access_no_encryption
  ]
}

# ---------------------------------------------------------
# TLS POLICY OMITTED INTENTIONALLY- ALLOWS HTTP CONNECTION-UNENCRYPTED
# ---------------------------------------------------------