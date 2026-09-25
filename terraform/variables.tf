variable "region" {
  description = "AWS region for all the vault resources"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Short project name, used in resource names and tags"
  type        = string
  default     = "secure-vault"
}