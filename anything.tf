resource "aws_s3_bucket" "anything" {
  bucket = "cyb611-phish-bits-insecure-ea-public-access"
  
  tags = {
    Name        = "CYB611 InSecure-EA-public-access"
    Environment = "Test"
  }
}

# [EXISTING BLOCKS KEPT THE SAME]
resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.anything.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
