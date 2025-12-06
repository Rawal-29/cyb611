resource "random_string" "dev_id" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_s3_bucket" "dev_bucket" {
  bucket        = "cyb611-dev-scratchpad-${random_string.dev_id.result}"   
  acl           = "private"
  force_destroy = true

  versioning {
    enabled = true
  }

  tags = {
    Name        = "Dev Scratchpad"
    Environment = "Development"
  }
}

resource "aws_s3_bucket_policy" "dev_policy" {
  bucket = aws_s3_bucket.dev_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [
          "${aws_s3_bucket.dev_bucket.arn}",
          "${aws_s3_bucket.dev_bucket.arn}/*"
        ]
      }
    ]
  })
}

# UPLOAD CONFIG
resource "aws_s3_object" "initial_config" {
  bucket       = aws_s3_bucket.dev_bucket.id
  key          = "sensitive_data/mock_pii.csv"
  content_type = "text/csv"
  content      = "id,secret\n1,DevData"
}