# cloudtrail.tf

# 1. Get current account info (needed for policies)
data "aws_caller_identity" "current" {}

# 2. Create a Bucket specifically for CloudTrail Logs
resource "aws_s3_bucket" "trail_bucket" {
  bucket        = "cyb611-cloudtrail-logs-phish-bits-12345"
  force_destroy = true
}

# 3. Allow CloudTrail to write to this bucket
resource "aws_s3_bucket_policy" "trail_bucket_policy" {
  bucket = aws_s3_bucket.trail_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck",
        Effect = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        },
        Action   = "s3:GetBucketAcl",
        Resource = aws_s3_bucket.trail_bucket.arn
      },
      {
        Sid    = "AWSCloudTrailWrite",
        Effect = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        },
        Action   = "s3:PutObject",
        Resource = "${aws_s3_bucket.trail_bucket.arn}/prefix/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# 4. Create the Trail
resource "aws_cloudtrail" "main_trail" {
  name                          = "cyb611-management-events-trail"
  s3_bucket_name                = aws_s3_bucket.trail_bucket.id
  s3_key_prefix                 = "prefix"
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true
}