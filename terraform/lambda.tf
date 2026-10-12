data "archive_file" "request_upload" {
  type        = "zip"
  source_dir  = "${path.module}/../backend/functions/request_upload"
  output_path = "${path.module}/build/request_upload.zip"
  excludes    = ["__pycache__"]
}

data "archive_file" "on_upload_complete" {
  type        = "zip"
  source_dir  = "${path.module}/../backend/functions/on_upload_complete"
  output_path = "${path.module}/build/on_upload_complete.zip"
  excludes    = ["__pycache__"]
}

# requestUpload: returns a pre-signed POST for one file
resource "aws_cloudwatch_log_group" "request_upload" {
  name              = "/aws/lambda/${var.project}-request-upload"
  retention_in_days = 14
}

resource "aws_lambda_function" "request_upload" {
  function_name = "${var.project}-request-upload"
  role          = aws_iam_role.request_upload.arn
  handler       = "app.lambda_handler"
  runtime       = "python3.13"
  architectures = ["arm64"]
  timeout       = 10
  memory_size   = 128

  filename         = data.archive_file.request_upload.output_path
  source_code_hash = data.archive_file.request_upload.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.vault.bucket
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  depends_on = [
    aws_cloudwatch_log_group.request_upload,
    aws_iam_role_policy_attachment.request_upload_vpc,
  ]
}

# onUploadComplete: records each new upload in the file table
resource "aws_cloudwatch_log_group" "on_upload_complete" {
  name              = "/aws/lambda/${var.project}-on-upload-complete"
  retention_in_days = 14
}

resource "aws_lambda_function" "on_upload_complete" {
  function_name = "${var.project}-on-upload-complete"
  role          = aws_iam_role.on_upload_complete.arn
  handler       = "app.lambda_handler"
  runtime       = "python3.13"
  architectures = ["arm64"]
  timeout       = 10
  memory_size   = 128

  filename         = data.archive_file.on_upload_complete.output_path
  source_code_hash = data.archive_file.on_upload_complete.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.files.name
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  depends_on = [
    aws_cloudwatch_log_group.on_upload_complete,
    aws_iam_role_policy_attachment.on_upload_complete_vpc,
  ]
}

# S3 trigger
resource "aws_lambda_permission" "s3_invoke_on_upload_complete" {
  statement_id   = "AllowS3Invoke"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.on_upload_complete.function_name
  principal      = "s3.amazonaws.com"
  source_arn     = aws_s3_bucket.vault.arn
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_s3_bucket_notification" "vault" {
  bucket = aws_s3_bucket.vault.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.on_upload_complete.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.s3_invoke_on_upload_complete]
}
