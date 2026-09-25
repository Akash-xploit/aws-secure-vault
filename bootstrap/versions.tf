# versions.tf - WHICH Terraform and WHICH plugins this code needs.
# Pinning versions means your laptop and the CI pipeline behave identically.

terraform {
  required_version = ">= 1.10" # 1.10+ needed for native S3 state locking (used by the main project)

  required_providers {
    aws = {
      source  = "hashicorp/aws" # the official AWS plugin, downloaded by `terraform init`
      version = "~> 6.0"        # any 6.x version, but not 7.0 (major versions can break things)
    }
  }

  # NOTE: no "backend" block here. The bootstrap keeps its state LOCALLY
  # (bootstrap/terraform.tfstate) because the remote bucket doesn't exist yet.
  # That's the chicken-and-egg problem this folder solves.
}

# The provider = the plugin that talks to AWS. It uses your `aws login` credentials automatically.
provider "aws" {
  region = var.region

  # Tags added to EVERY resource this code creates, so you can filter costs
  # and see at a glance that Terraform (not a human) manages it.
  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
      Component = "bootstrap"
    }
  }
}
