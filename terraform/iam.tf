# requestUpload
resource "aws_iam_role" "request_upload" {
  name = "${var.project}-request-upload"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "request_upload_vpc" {
  role       = aws_iam_role.request_upload.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "request_upload" {
  name = "${var.project}-request-upload"
  role = aws_iam_role.request_upload.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "PutUserFiles"
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.vault.arn}/*"
      },
      {
        Sid      = "EncryptWithVaultKey"
        Effect   = "Allow"
        Action   = "kms:GenerateDataKey"
        Resource = aws_kms_key.vault.arn
      }
    ]
  })
}

# onUploadComplete
resource "aws_iam_role" "on_upload_complete" {
  name = "${var.project}-on-upload-complete"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "on_upload_complete_vpc" {
  role       = aws_iam_role.on_upload_complete.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "on_upload_complete" {
  name = "${var.project}-on-upload-complete"
  role = aws_iam_role.on_upload_complete.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # HeadObject is authorized by s3:GetObject.
        Sid      = "ReadFileMetadata"
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.vault.arn}/*"
      },
      {
        Sid      = "WriteCatalogRow"
        Effect   = "Allow"
        Action   = "dynamodb:PutItem"
        Resource = aws_dynamodb_table.files.arn
      },
      {
        # The table uses the vault key.
        Sid      = "UseVaultKeyViaDynamoDB"
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = aws_kms_key.vault.arn
        Condition = {
          StringEquals = { "kms:ViaService" = "dynamodb.${var.region}.amazonaws.com" }
        }
      }
    ]
  })
}

# API Gateway: lets the service write access logs (one setting per account and region)
resource "aws_iam_role" "apigw_cloudwatch" {
  name = "${var.project}-apigw-cloudwatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "apigateway.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "apigw_cloudwatch" {
  role       = aws_iam_role.apigw_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}