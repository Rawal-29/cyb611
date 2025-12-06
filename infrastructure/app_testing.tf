# infrastructure/attacker.tf

# 1. Zip the script
data "archive_file" "attacker_zip" {
  type        = "zip"
  source_file = "${path.module}/../scripts/verify_exploits.py"
  output_path = "${path.module}/attacker.zip"
}

# 2. IAM Role for the Attacker
resource "aws_iam_role" "attacker_role" {
  name = "S3RedTeamRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# 3. Permissions (Needs S3 Read to simulate insider threats)
resource "aws_iam_role_policy" "attacker_policy" {
  name = "S3RedTeamPolicy"
  role = aws_iam_role.attacker_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = ["s3:ListAllMyBuckets", "s3:ListBucket", "s3:GetObject", "s3:GetBucketVersioning"],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# 4. The Lambda Function
resource "aws_lambda_function" "attacker_lambda" {
  filename      = data.archive_file.attacker_zip.output_path
  function_name = "S3RedTeamScanner"
  role          = aws_iam_role.attacker_role.arn
  handler       = "verify_exploits.lambda_handler"
  runtime       = "python3.12"
  timeout       = 15

  source_code_hash = data.archive_file.attacker_zip.output_base64sha256
}

# 5. Public URL for Triggering
resource "aws_lambda_function_url" "attacker_url" {
  function_name      = aws_lambda_function.attacker_lambda.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["GET"]
  }
}

output "attacker_endpoint" {
  value = aws_lambda_function_url.attacker_url.function_url
}