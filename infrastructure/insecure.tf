resource "random_string" "rand_id" {
  length  = 6
  special = false
  upper   = false
}

# 1. PRIMARY BUCKET
resource "aws_s3_bucket" "main_bucket" {
  bucket        = "cyb611-marketing-assets-${random_string.rand_id.result}"
  force_destroy = true
  
  tags = {
    Name        = "Marketing Assets"
    Environment = "Production"
  }
}

# 2. PUBLIC ACCESS CONFIGURATION
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.main_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# 3. OWNERSHIP CONTROLS
resource "aws_s3_bucket_ownership_controls" "ownership" {
  bucket = aws_s3_bucket.main_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.main_bucket.id
  acl    = "public-read"

  depends_on = [
    aws_s3_bucket_ownership_controls.ownership,
    aws_s3_bucket_public_access_block.public_access
  ]
}

# 4. VERSIONING
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.main_bucket.id
  versioning_configuration {
    status = "Suspended"
  }
}

# 5. BUCKET POLICY
resource "aws_s3_bucket_policy" "read_policy" {
  bucket = aws_s3_bucket.main_bucket.id
  depends_on = [aws_s3_bucket_public_access_block.public_access]

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowPublicRead",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.main_bucket.arn}/*"
      }
    ]
  })
}

# 6. CORS CONFIG
resource "aws_s3_bucket_cors_configuration" "cors_config" {
  bucket = aws_s3_bucket.main_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# 7. UPLOAD INITIAL DATASET
resource "aws_s3_object" "dataset_upload" {
  bucket       = aws_s3_bucket.main_bucket.id
  key          = "sensitive_data/mock_pii.csv"
  content_type = "text/csv"
  content      = "id,secret\n1,TargetAcquired"
  depends_on   = [aws_s3_bucket_policy.read_policy]
}