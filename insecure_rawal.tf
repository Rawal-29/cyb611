resource "aws_s3_bucket" "insecure_bucket" {
  bucket = "cyb611-secure-phish-bits-insecure-bucket-001"
  
  tags = {
    Name        = "CYB611 InSecure"
    Environment = "Test"
  }
}