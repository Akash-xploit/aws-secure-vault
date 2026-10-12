# File catalog: one row per uploaded file.

resource "aws_dynamodb_table" "files" {
  name         = "${var.project}-file-metadata"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ownerId"
  range_key    = "fileId"

  attribute {
    name = "ownerId"
    type = "S"
  }

  attribute {
    name = "fileId"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.vault.arn
  }
}
