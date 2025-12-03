# ---------------------------------------------------------
# 1. LOGGING BUCKET (NEW - Required for auditing)
# ---------------------------------------------------------
resource "aws_s3_bucket" "log_bucket" {
  bucket = "cyb611-secure-phish-bits-no-encryption-logs" # UNIQUE NAME
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

# [ EXISTING BLOCK WITHOUT THE ENCRYPTION CONFIG ]
resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.insecure_bucket1.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "ownership" {
  bucket = aws_s3_bucket.insecure_bucket1.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.insecure_bucket1.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ---------------------------------------------------------
# [NEW] ENABLE ACCESS LOGGING
# ---------------------------------------------------------
resource "aws_s3_bucket_logging" "example" {
  bucket        = aws_s3_bucket.insecure_bucket1.id
  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "log/"
}

# ---------------------------------------------------------
[TLS POLICY OMITTED INTENTIONALLY- ALLOWS HTTP CONNECTION-UNENCRYPTED]
# ---------------------------------------------------------
