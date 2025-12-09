resource "random_string" "enc_id" {
  length  = 6
  special = false
  upper   = false
}


resource "aws_s3_bucket" "enc_logs" {
  bucket = "cyb611-insecure-no-encryption-logs-${random_string.enc_id.result}"
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "enc_log_ownership" {
  bucket = aws_s3_bucket.enc_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "enc_log_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.enc_log_ownership]
  bucket     = aws_s3_bucket.enc_logs.id
  acl        = "log-delivery-write"
}


resource "aws_s3_bucket" "enc_bucket" {
  bucket = "cyb611-insecure-no-encryption-${random_string.enc_id.result}"
  force_destroy = true
  tags = {
    Name = "Insecure No Encryption"
  }
}


resource "aws_s3_bucket_public_access_block" "enc_block" {
  bucket = aws_s3_bucket.enc_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "enc_ownership" {
  bucket = aws_s3_bucket.enc_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "enc_versioning" {
  bucket = aws_s3_bucket.enc_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_logging" "enc_logging" {
  bucket        = aws_s3_bucket.enc_bucket.id
  target_bucket = aws_s3_bucket.enc_logs.id
  target_prefix = "log/"
}


resource "aws_s3_bucket_policy" "enc_ssl_policy" {
  bucket = aws_s3_bucket.enc_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "DenyInsecureTransport",
        Effect    = "Deny",
        Principal = "*",
        Action    = "s3:*",
        Resource  = [
          aws_s3_bucket.enc_bucket.arn,
          "${aws_s3_bucket.enc_bucket.arn}/*",
        ],
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_object" "enc_file" {
  bucket       = aws_s3_bucket.enc_bucket.id
  key          = "sensitive_data/mock_pii.csv"
  content_type = "text/csv"
  content      = "id,secret\n1,UnencryptedData"
}