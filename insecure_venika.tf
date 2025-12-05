# ========================================
# 1. PUBLIC ACCESS BLOCK CONFIGURATION
# ========================================

# INSECURE: Public Access Block Disabled
resource "aws_s3_bucket" "insecure_public_access" {
  bucket = "insecure-bucket-public-access"
}

# No public access block configured - allows public access
# This is dangerous as bucket can be made public via ACLs or policies

# ========================================
# 2. ENCRYPTION CONFIGURATION
# ========================================

# INSECURE: No Encryption
resource "aws_s3_bucket" "insecure_encryption" {
  bucket = "insecure-bucket-no-encryption"
}

# ========================================
# 3. IAM POLICY CONFIGURATION
# ========================================

# INSECURE: Overly Permissive Policy (Public Read Access)
resource "aws_s3_bucket" "insecure_policy" {
  bucket = "insecure-bucket-overly-permissive"
}

resource "aws_s3_bucket_policy" "insecure" {
  bucket = aws_s3_bucket.insecure_policy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadAccess"
        Effect    = "Allow"
        Principal = "*"  # DANGER: Anyone can access
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.insecure_policy.arn}",
          "${aws_s3_bucket.insecure_policy.arn}/*"
        ]
      }
    ]
  })
}

# INSECURE: Wildcard Actions
resource "aws_s3_bucket" "insecure_wildcard" {
  bucket = "insecure-bucket-wildcard-actions"
}

resource "aws_s3_bucket_policy" "insecure_wildcard" {
  bucket = aws_s3_bucket.insecure_wildcard.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "WildcardActions"
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::123456789012:user/some-user"
        }
        Action   = "s3:*"  # DANGER: All S3 actions allowed
        Resource = "${aws_s3_bucket.insecure_wildcard.arn}/*"
      }
    ]
  })
}
