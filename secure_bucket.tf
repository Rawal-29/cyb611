resource "aws_s3_bucket" "secure_bucket" {
  bucket = "cyb611-secure-phish-bits-12345" 
  
  tags = {
    Name        = "CYB611 Secure Baseline"
    Environment = "Test"
  }
}
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



resource "aws_s3_bucket" "secure_bucket" {
  bucket = "cyb611-secure-phish-bits-29333" 
  
  tags = {
    Name        = "CYB611 Secure Baseline"
    Environment = "Test"
  }
}