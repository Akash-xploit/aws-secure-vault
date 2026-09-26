# Vault bucket: where users' files are stored.
# Later additions: CORS (Day 4, needs the website URL), VPC-endpoint-only admin rule (Day 2).

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "vault" {
  bucket = "${var.project}-files-${data.aws_caller_identity.current.account_id}"
  # No prevent_destroy: the project is torn down with `terraform destroy` at the end.
}

resource "aws_s3_bucket_versioning" "vault" {
  bucket = aws_s3_bucket.vault.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "vault" {
  bucket = aws_s3_bucket.vault.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.vault.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "vault" {
  bucket = aws_s3_bucket.vault.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "vault" {
  bucket = aws_s3_bucket.vault.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "vault" {
  bucket     = aws_s3_bucket.vault.id
  depends_on = [aws_s3_bucket_public_access_block.vault]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.vault.arn,
          "${aws_s3_bucket.vault.arn}/*",
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      {
        # Rejects uploads that request any key other than the vault key.
        # Uploads that name no key get the vault key from default encryption (verified with head-object).
        Sid       = "DenyUploadsWithoutVaultKey"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.vault.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption-aws-kms-key-id" = aws_kms_key.vault.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "vault" {
  bucket     = aws_s3_bucket.vault.id
  depends_on = [aws_s3_bucket_versioning.vault]

  rule {
    id     = "expire-old-file-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
