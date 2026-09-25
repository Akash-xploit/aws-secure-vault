# outputs.tf - values Terraform PRINTS after `apply`. The rest of the project needs the bucket name.

output "state_bucket_name" {
  description = "Name of the S3 bucket that stores Terraform state"
  value       = aws_s3_bucket.tfstate.bucket
}

output "state_bucket_arn" {
  description = "ARN of the S3 bucket that stores Terraform state"
  value       = aws_s3_bucket.tfstate.arn
}

output "backend_config" {
  description = "Paste this into terraform/backend.tf in the main project"
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket       = "${aws_s3_bucket.tfstate.bucket}"
        key          = "secure-vault/terraform.tfstate"
        region       = "${var.region}"
        encrypt      = true
        use_lockfile = true
      }
    }
  EOT
}
 