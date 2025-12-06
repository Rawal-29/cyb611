resource "random_string" "legacy_id" {
  length  = 6
  special = false
  upper   = false
}


resource "aws_s3_bucket" "legacy_logs" {
  bucket = "cyb611-archive-logs-${random_string.legacy_id.result}"
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "legacy_log_ownership" {
  bucket = aws_s3_bucket.legacy_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "legacy_log_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.legacy_log_ownership]
  bucket     = aws_s3_bucket.legacy_logs.id
  acl        = "log-delivery-write"
}

resource "aws_s3_bucket_public_access_block" "log_block" {
  bucket = aws_s3_bucket.legacy_logs.id
  block_public_acls       = false
  block_public_policy     = true
  ignore_public_acls      = false
  restrict_public_buckets = true
}


resource "aws_s3_bucket" "legacy_data" {
  bucket = "cyb611-legacy-archive-${random_string.legacy_id.result}"
  force_destroy = true

  tags = {
    Name        = "Legacy Archive"
    Environment = "Staging"
  }
}

resource "aws_s3_bucket_public_access_block" "legacy_block" {
  bucket                  = aws_s3_bucket.legacy_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "legacy_ownership" {
  bucket = aws_s3_bucket.legacy_data.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "legacy_versioning" {
  bucket = aws_s3_bucket.legacy_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_logging" "legacy_logging_config" {
  bucket        = aws_s3_bucket.legacy_data.id
  target_bucket = aws_s3_bucket.legacy_logs.id
  target_prefix = "log/"
  
  depends_on = [
    aws_s3_bucket_acl.legacy_log_acl,
    aws_s3_bucket_public_access_block.log_block
  ]
}


resource "aws_s3_object" "archive_file" {
  bucket       = aws_s3_bucket.legacy_data.id
  key          = "sensitive_data/mock_pii.csv"
  content_type = "text/csv"
  content      = "id,secret\n1,UnencryptedData"
}