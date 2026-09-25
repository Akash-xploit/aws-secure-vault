terraform {
  backend "s3" {
    bucket       = "secure-vault-tfstate-551529689172"
    key          = "secure-vault/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}