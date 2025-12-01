resource "aws_s3_bucket" "public_s3_rw_access" {
  bucket = "cyb611-phish-bits-insecure-ea-s3-public-write"
  
  tags = {
    Name        = "CYB611 InSecure-EA-public-access"
    Environment = "Test"
  }
}


# [Public Read-Write Access]
resource "aws_s3_bucket_public_access_block" "public_rw_disable" {
  bucket = aws_s3_bucket.public_s3_rw_access.id

  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_rw_policy" {
  bucket = aws_s3_bucket.public_s3_rw_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicWrite"
      Effect    = "Allow"
      Principal = "*"
      Action    = ["s3:PutObject", "s3:PutObjectAcl"]
      Resource  = "${aws_s3_bucket.public_s3_rw_access.arn}/*"
    }]
  })
}