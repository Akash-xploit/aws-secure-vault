# variables.tf - INPUTS. Values you might want to change without editing the logic.

variable "region" {
  description = "AWS region for the state bucket"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Short project name, used in resource names and tags"
  type        = string
  default     = "secure-vault"
}

variable "state_version_retention_days" {
  description = "Number of days to retain state versions"
  type        = number
  default     = 90
}
