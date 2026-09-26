output "vault_bucket_name" {
  description = "Name of the S3 bucket that stores user files"
  value       = aws_s3_bucket.vault.bucket
}

output "vault_kms_key_arn" {
  description = "ARN of the KMS key that encrypts user files"
  value       = aws_kms_key.vault.arn
}

output "file_table_name" {
  description = "Name of the DynamoDB table that stores file metadata"
  value       = aws_dynamodb_table.files.name
}

output "user_pool_id" {
  description = "ID of the Cognito user pool"
  value       = aws_cognito_user_pool.users.id
}

output "user_pool_client_id" {
  description = "ID of the web app client (used by the website)"
  value       = aws_cognito_user_pool_client.web.id
}

output "private_subnet_a_id" {
  description = "ID of the private subnet A in the network"
  value       = aws_subnet.private_a.id
}

output "private_subnet_b_id" {
  description = "ID of the private subnet B in the network"
  value       = aws_subnet.private_b.id
}

output "lambda_security_group_id" {
  description = "ID of lambda security group"
  value       = aws_security_group.lambda.id
}