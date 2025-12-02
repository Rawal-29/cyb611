# ---------------------------------------------------------
# 1. THE INSECURE BUCKET
# ---------------------------------------------------------
resource "aws_s3_bucket" "insecure_bucket" {
  bucket = "cyb611-insecure-phish-bits-12345" # Ensure this is unique
  force_destroy = true # Allows deleting bucket even if it has files (for easy cleanup)

  tags = {
    Name        = "CYB611 Vulnerable Target"
    Environment = "Attack-Simulation"
  }
}

# ---------------------------------------------------------
# 2. DISABLE PUBLIC ACCESS BLOCKS (Proposal Item: "Block Public Access disabled")
# ---------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "insecure_block" {
  bucket = aws_s3_bucket.insecure_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# ---------------------------------------------------------
# 3. WEAK OWNERSHIP & ACLs (Proposal Item: "Overly permissive ACLs")
# ---------------------------------------------------------
resource "aws_s3_bucket_ownership_controls" "insecure_ownership" {
  bucket = aws_s3_bucket.insecure_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred" # Allows ACLs to function
  }
}

resource "aws_s3_bucket_acl" "insecure_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.insecure_ownership]
  bucket     = aws_s3_bucket.insecure_bucket.id
  acl        = "public-read" # DANGER: Allows anyone on the internet to list files
}

# ---------------------------------------------------------
# 4. MISSING ENCRYPTION (Proposal Item: "Missing/weak encryption")
# ---------------------------------------------------------
# NOTE: We intentionally DO NOT add the "aws_s3_bucket_server_side_encryption_configuration" block.
# This leaves data in plain text, satisfying the project requirement.

# ---------------------------------------------------------
# 5. DISABLED VERSIONING (Proposal Item: "Versioning disabled")
# ---------------------------------------------------------
resource "aws_s3_bucket_versioning" "insecure_versioning" {
  bucket = aws_s3_bucket.insecure_bucket.id
  versioning_configuration {
    status = "Suspended"
  }
}

# ---------------------------------------------------------
# 6. BAD BUCKET POLICY (Proposal Item: "Unrestricted buckets permission")
# ---------------------------------------------------------
# This explicitly allows anyone ("*") to Read ("GetObject") any file.
resource "aws_s3_bucket_policy" "insecure_policy" {
  bucket = aws_s3_bucket.insecure_bucket.id
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
# 7. CORS MISCONFIGURATION (Proposal Item: "CORS Misconfiguration")
# ---------------------------------------------------------
# Allows any malicious website to use JavaScript to read your bucket data.
resource "aws_s3_bucket_cors_configuration" "insecure_cors" {
  bucket = aws_s3_bucket.insecure_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"] # DANGER: Allows cross-origin requests from ANY site
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}