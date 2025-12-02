# =============================================================================
# NON-COMPLIANT BUCKET (Fails checks - For Validation)
# =============================================================================


resource "aws_s3_bucket" "insecure" {
  bucket = "cyb611-secure-phish-bits-insecure-bucket-001"
  force_destroy = true
  
  tags = {
    Name        = "CYB611 InSecure"
    Environment = "Test"
  }
}

resource "aws_s3_bucket_public_access_block" "insecure" {
  bucket = aws_s3_bucket.insecure.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "insecure" {
  bucket     = aws_s3_bucket.insecure.id
  # Wait for block settings to apply before adding public policy
  depends_on = [aws_s3_bucket_public_access_block.insecure] 
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadWrite"
      Effect    = "Allow"
      Principal = "*"
      Action    = ["s3:GetObject", "s3:PutObject"]
      Resource  = "${aws_s3_bucket.insecure.arn}/*"
    }]
  })
}