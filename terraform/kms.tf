# Encrypts the vault bucket and the file table.

resource "aws_kms_key" "vault" {
  description             = "Encrypts user files in the Secure Vault bucket"
  enable_key_rotation     = true
  rotation_period_in_days = 365
  deletion_window_in_days = 7

  # Default key policy: access is granted through IAM.
}

resource "aws_kms_alias" "vault" {
  name          = "alias/${var.project}"
  target_key_id = aws_kms_key.vault.key_id
}
