resource "random_string" "iam_id" {
  length  = 6
  special = false
  upper   = false
}


resource "aws_s3_bucket" "iam_logs" {
  bucket = "cyb611-insecure-iam-logs-${random_string.iam_id.result}"
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "iam_log_ownership" {
  bucket = aws_s3_bucket.iam_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "iam_log_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.iam_log_ownership]
  bucket     = aws_s3_bucket.iam_logs.id
  acl        = "log-delivery-write"
}


resource "aws_s3_bucket" "iam_bucket" {
  bucket        = "cyb611-insecure-iam-${random_string.iam_id.result}"   
  force_destroy = true
  tags = {
    Name = "Insecure IAM"
  }
}


resource "aws_s3_bucket_public_access_block" "iam_unsafe" {
  bucket = aws_s3_bucket.iam_bucket.id
  block_public_acls       = true
  block_public_policy     = false # FAIL
  ignore_public_acls      = true
  restrict_public_buckets = false # FAIL
}

# SECURE: Versioning Enabled (Blocks Ransomware)
resource "aws_s3_bucket_versioning" "iam_versioning" {
  bucket = aws_s3_bucket.iam_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_s3_bucket_logging" "iam_logging" {
  bucket        = aws_s3_bucket.iam_bucket.id
  target_bucket = aws_s3_bucket.iam_logs.id
  target_prefix = "log/"
}


resource "aws_s3_bucket_ownership_controls" "iam_ownership" {
  bucket = aws_s3_bucket.iam_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}


resource "aws_s3_bucket_policy" "iam_policy" {
  bucket = aws_s3_bucket.iam_bucket.id
  depends_on = [aws_s3_bucket_public_access_block.iam_unsafe]

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "InsecureWildcard",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:*",
        Resource  = [
          "${aws_s3_bucket.iam_bucket.arn}",
          "${aws_s3_bucket.iam_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_s3_object" "iam_file" {
  bucket       = aws_s3_bucket.iam_bucket.id
  key          = "sensitive_data/mock_pii.csv"
  content_type = "text/csv"
  content      = "id,secret\n1,DevData"
}