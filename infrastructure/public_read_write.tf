resource "random_string" "public_id" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_s3_bucket" "public_assets" {
  bucket = "cyb611-insecure-public-rw-${random_string.public_id.result}"
  force_destroy = true
  
  tags = {
    Name = "Insecure Public RW"
  }
}

# 1. Guardrails: OFF (Allows public access)
resource "aws_s3_bucket_public_access_block" "public_block" {
  bucket = aws_s3_bucket.public_assets.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# 2. Ownership: PREFERRED (Crucial for ACLs to work)
resource "aws_s3_bucket_ownership_controls" "public_ownership" {
  bucket = aws_s3_bucket.public_assets.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# 3. ACL: PUBLIC-READ (The misconfiguration)
resource "aws_s3_bucket_acl" "public_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.public_ownership,
    aws_s3_bucket_public_access_block.public_block
  ]
  bucket = aws_s3_bucket.public_assets.id
  acl    = "public-read"
}

# 4. Versioning: Suspended (Reverted to insecure default)
resource "aws_s3_bucket_versioning" "public_versioning" {
  bucket = aws_s3_bucket.public_assets.id
  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_object" "web_asset" {
  bucket       = aws_s3_bucket.public_assets.id
  key          = "sensitive_data/mock_pii.csv"
  content_type = "text/csv"
  content      = "id,secret\n1,PublicData"
}