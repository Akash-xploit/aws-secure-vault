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