# main.tf - the RESOURCES: what actually gets created in AWS.
# Everything here builds ONE thing: a locked-down S3 bucket that stores Terraform state
# for the rest of the project.

# A "data source" READS something that already exists instead of creating it.
# Here: your AWS account ID, used to make the bucket name globally unique.
data "aws_caller_identity" "current" {}

# 1. The bucket itself.
resource "aws_s3_bucket" "tfstate" {
  # S3 bucket names are GLOBAL across all AWS customers, so adding the account ID avoids clashes.
  # Result: secure-vault-tfstate-551529689172
  bucket = "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}"

  # Safety catch: Terraform will REFUSE to delete this bucket, even with `terraform destroy`.
  # Losing the state file means Terraform forgets everything it built.
  lifecycle {
    prevent_destroy = true
  }
}

# 2. Versioning: every time the state file changes, the old version is kept.
#    If the state ever gets corrupted, you can roll back to a previous version.
resource "aws_s3_bucket_versioning" "tfstate" {
  # "aws_s3_bucket.tfstate.id" is a REFERENCE: "the ID of the bucket above".
  # Terraform uses references to work out the build order (bucket first, then this).
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# 3. Encryption at rest with KMS.
#    No key ID given, so it uses the AWS-managed key "aws/s3": no monthly fee, unlike your own key.
#    State files can contain secrets in plain text, so encryption is non-negotiable.
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true # caches the key briefly, cutting KMS requests (and cost) by ~99%
  }
}

# 4. Block ALL public access: four switches, all on.
#    Even if someone later adds a bad policy or ACL, S3 will refuse to make anything public.
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 5. Disable ACLs (the old permission system) entirely. Only IAM and bucket policies control access.
resource "aws_s3_bucket_ownership_controls" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# 6. Bucket policy: DENY any request that isn't over HTTPS.
#    "Deny" always wins in AWS. Even an admin can't read the state over plain HTTP.
resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  # Make sure the public access block is in place first (avoids a race when creating both).
  depends_on = [aws_s3_bucket_public_access_block.tfstate]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.tfstate.arn,        # the bucket itself
          "${aws_s3_bucket.tfstate.arn}/*", # every object inside it
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" } # true only when the request is NOT using HTTPS
        }
      }
    ]
  })
}

# 7. Lifecycle: keep old state versions for 90 days, then delete them, so storage doesn't grow forever.
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  # Lifecycle rules on a versioned bucket must wait until versioning is on.
  depends_on = [aws_s3_bucket_versioning.tfstate]

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {} # empty filter = apply to every object in the bucket

    noncurrent_version_expiration {
      noncurrent_days = var.state_version_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7 # clean up half-finished uploads
    }
  }
}
