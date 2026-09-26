# Customer-managed KMS key that encrypts every file in the vault bucket.

resource "aws_kms_key" "vault" {
  description             = "Encrypts user files in the Secure Vault bucket"
  enable_key_rotation     = true
  rotation_period_in_days = 365
  deletion_window_in_days = 7 # shortest wait (learning project)

  # No key policy yet: the AWS default lets IAM decide. Tightened once Lambda roles exist.
}

resource "aws_kms_alias" "vault" {
  name          = "alias/${var.project}"
  target_key_id = aws_kms_key.vault.key_id
}
