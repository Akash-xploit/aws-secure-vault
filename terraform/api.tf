resource "aws_api_gateway_rest_api" "vault" {
  name = "${var.project}-api"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_authorizer" "cognito" {
  name            = "${var.project}-cognito"
  rest_api_id     = aws_api_gateway_rest_api.vault.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [aws_cognito_user_pool.users.arn]
  identity_source = "method.request.header.Authorization"
}

# POST /upload -> requestUpload
resource "aws_api_gateway_resource" "upload" {
  rest_api_id = aws_api_gateway_rest_api.vault.id
  parent_id   = aws_api_gateway_rest_api.vault.root_resource_id
  path_part   = "upload"
}

resource "aws_api_gateway_method" "upload_post" {
  rest_api_id   = aws_api_gateway_rest_api.vault.id
  resource_id   = aws_api_gateway_resource.upload.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "upload_post" {
  rest_api_id             = aws_api_gateway_rest_api.vault.id
  resource_id             = aws_api_gateway_resource.upload.id
  http_method             = aws_api_gateway_method.upload_post.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST" # Lambda is always invoked with POST
  uri                     = aws_lambda_function.request_upload.invoke_arn
}

resource "aws_lambda_permission" "apigw_invoke_request_upload" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.request_upload.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.vault.execution_arn}/*/POST/upload"
}

resource "aws_api_gateway_deployment" "vault" {
  rest_api_id = aws_api_gateway_rest_api.vault.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.upload.id,
      aws_api_gateway_method.upload_post.id,
      aws_api_gateway_integration.upload_post.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "v1" {
  rest_api_id   = aws_api_gateway_rest_api.vault.id
  deployment_id = aws_api_gateway_deployment.vault.id
  stage_name    = "v1"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access.arn
    format = jsonencode({
      requestId = "$context.requestId"
      ip        = "$context.identity.sourceIp"
      user      = "$context.authorizer.claims.sub"
      method    = "$context.httpMethod"
      path      = "$context.resourcePath"
      status    = "$context.status"
      error     = "$context.error.message"
    })
  }

  depends_on = [aws_api_gateway_account.this]
}

resource "aws_api_gateway_account" "this" {
  cloudwatch_role_arn = aws_iam_role.apigw_cloudwatch.arn
}

resource "aws_cloudwatch_log_group" "api_access" {
  name              = "/aws/apigateway/${var.project}-api"
  retention_in_days = 14
}

# Applies to every route, including ones added later
resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.vault.id
  stage_name  = aws_api_gateway_stage.v1.stage_name
  method_path = "*/*"

  settings {
    throttling_rate_limit  = 10
    throttling_burst_limit = 20
    metrics_enabled        = true
  }
}
