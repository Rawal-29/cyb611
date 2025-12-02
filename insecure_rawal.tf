# ---------------------------------------------------------
# 1. THE VULNERABLE BUCKET RESOURCE
# ---------------------------------------------------------
resource "aws_s3_bucket" "insecure_bucket" {
  bucket        = "cyb611-insecure-phish-bits-12345" # Ensure this is unique
  force_destroy = true # Allows deleting the bucket even if it contains files
  
  tags = {
    Name        = "CYB611 Vulnerable Target"
    Environment = "Attack-Simulation"
  }
}

# ---------------------------------------------------------
# 2. DISABLE PUBLIC ACCESS BLOCKS
# ---------------------------------------------------------
# VULNERABILITY: This removes the "Guardrails" that normally prevent
# a bucket from becoming public. We set everything to 'false'.
resource "aws_s3_bucket_public_access_block" "insecure_block" {
  bucket = aws_s3_bucket.insecure_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# ---------------------------------------------------------
# 3. WEAK OWNERSHIP & PUBLIC ACLs
# ---------------------------------------------------------
# VULNERABILITY: Enabling "BucketOwnerPreferred" allows us to use Legacy ACLs.
resource "aws_s3_bucket_ownership_controls" "insecure_ownership" {
  bucket = aws_s3_bucket.insecure_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# VULNERABILITY: Setting ACL to "public-read" allows anyone to list files.
resource "aws_s3_bucket_acl" "insecure_acl" {
  bucket = aws_s3_bucket.insecure_bucket.id
  acl    = "public-read"

  # IMPORTANT: Wait for the Block settings to be disabled first!
  depends_on = [
    aws_s3_bucket_ownership_controls.insecure_ownership,
    aws_s3_bucket_public_access_block.insecure_block
  ]
}

# ---------------------------------------------------------
# 4. ENCRYPTION DISABLED
# ---------------------------------------------------------
# VULNERABILITY: We intentionally OMIT the encryption configuration block.
# This means files are stored in Plain Text.

# ---------------------------------------------------------
# 5. VERSIONING DISABLED
# ---------------------------------------------------------
# VULNERABILITY: Turning off versioning means if a hacker overwrites 
# a file (ransomware style), the original data is lost forever.
resource "aws_s3_bucket_versioning" "insecure_versioning" {
  bucket = aws_s3_bucket.insecure_bucket.id
  versioning_configuration {
    status = "Suspended"
  }
}

# ---------------------------------------------------------
# 6. INSECURE BUCKET POLICY (The Main Exploit)
# ---------------------------------------------------------
# VULNERABILITY: This policy explicitly grants "s3:GetObject" permission
# to Principal "*", which means "Anyone on the Internet".
resource "aws_s3_bucket_policy" "insecure_policy" {
  bucket = aws_s3_bucket.insecure_bucket.id

  # FIX: This 'depends_on' prevents the "Access Denied" error.
  # It ensures Terraform completely disables the public block BEFORE applying this policy.
  depends_on = [aws_s3_bucket_public_access_block.insecure_block]

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.insecure_bucket.arn}/*"
      }
    ]
  })
}

# ---------------------------------------------------------
# 7. CORS MISCONFIGURATION
# ---------------------------------------------------------
# VULNERABILITY: This allows malicious scripts running on OTHER websites
# to read data from your bucket using the browser.
resource "aws_s3_bucket_cors_configuration" "insecure_cors" {
  bucket = aws_s3_bucket.insecure_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"] # The wildcard "*" allows ANY site to access data
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}