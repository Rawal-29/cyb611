resource "random_string" "public_id" {
  length  = 6
  special = false
  upper   = false
}


resource "aws_s3_bucket" "public_logs" {
  bucket = "cyb611-insecure-public-rw-logs-${random_string.public_id.result}"
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "public_log_ownership" {
  bucket = aws_s3_bucket.public_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "public_log_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.public_log_ownership]
  bucket     = aws_s3_bucket.public_logs.id
  acl        = "log-delivery-write"
}


resource "aws_s3_bucket" "public_bucket" {
  bucket = "cyb611-insecure-public-rw-${random_string.public_id.result}"
  force_destroy = true
  tags = {
    Name = "Insecure Public RW"
  }
}


resource "aws_s3_bucket_public_access_block" "public_block" {
  bucket = aws_s3_bucket.public_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}


resource "aws_s3_bucket_ownership_controls" "public_ownership" {
  bucket = aws_s3_bucket.public_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}


resource "aws_s3_bucket_acl" "public_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.public_ownership,
    aws_s3_bucket_public_access_block.public_block
  ]
  bucket = aws_s3_bucket.public_bucket.id
  acl    = "public-read"
}


resource "aws_s3_bucket_versioning" "public_versioning" {
  bucket = aws_s3_bucket.public_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_s3_bucket_logging" "public_logging" {
  bucket        = aws_s3_bucket.public_bucket.id
  target_bucket = aws_s3_bucket.public_logs.id
  target_prefix = "log/"
}



resource "aws_s3_object" "public_file" {
  bucket       = aws_s3_bucket.public_bucket.id
  key          = "sensitive_data/mock_pii.csv"
  content_type = "text/csv"
  content      = "id,secret\n1,PublicData"
}