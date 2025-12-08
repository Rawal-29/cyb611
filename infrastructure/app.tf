
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/../scripts/app.py"
  output_path = "${path.module}/package.zip"
}


resource "aws_iam_role" "scanner" {
  name = "S3ScannerRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}


resource "aws_iam_role_policy" "scanner" {
  name = "S3ScannerPolicy"
  role = aws_iam_role.scanner.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketPublicAccessBlock",
          "s3:GetBucketEncryption",
          "s3:GetBucketVersioning",
          "s3:GetBucketPolicy",
          "s3:GetBucketAcl",
          "s3:GetBucketLogging",
          "s3:GetBucketCORS",
          "s3:ListAllMyBuckets"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_lambda_function" "scanner" {
  function_name    = "S3SecurityScanner"
  role             = aws_iam_role.scanner.arn
  handler          = "app.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 15
}

resource "aws_lambda_function_url" "scanner" {
  function_name      = aws_lambda_function.scanner.function_name
  authorization_type = "NONE"
}

output "api_endpoint" {
  value = aws_lambda_function_url.scanner.function_url
}
