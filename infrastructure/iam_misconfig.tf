resource "aws_s3_bucket" "b" {
  bucket = "phishing-iam-testing-1234"   
  acl    = "private"

  versioning {
    enabled = true
  }

  tags = {
    Name        = "iam Misconfig Bucket"
    Environment = "Dev"
  }
}

# Overly permissive IAM policy misconfiguration
resource "aws_s3_bucket_policy" "overly_permissive_policy" {
  bucket = aws_s3_bucket.b.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [
          "${aws_s3_bucket.b.arn}",
          "${aws_s3_bucket.b.arn}/*"
        ]
      }
    ]
  })
}
