# network.tf - Private network for the vault Lambdas.
# No internet gateway and no NAT: the Lambdas can only reach S3 and DynamoDB
# through free gateway endpoints.

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "${var.project}-vpc"
  }
}

# Two subnets in two AZs, so the Lambdas keep running if one data center fails.
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "${var.project}-private-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "${var.project}-private-b"
  }
}

# No route blocks on purpose: only the automatic "local" route plus the
# endpoints' routes. There is never a route to 0.0.0.0/0.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-private-rt"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  # Only the vault bucket is reachable through this endpoint, so a compromised
  # Lambda can't copy files into an attacker-owned bucket. What each Lambda may
  # do is limited separately by its own IAM role.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "OnlyTheVaultBucket"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.vault.arn,
          "${aws_s3_bucket.vault.arn}/*",
        ]
      }
    ]
  })

  tags = {
    Name = "${var.project}-endpoint-s3"
  }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  # Only the file metadata table is reachable through this endpoint.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "OnlyTheVaultTable"
        Effect    = "Allow"
        Principal = "*"
        Action    = "dynamodb:*"
        Resource = [
          aws_dynamodb_table.files.arn,
          "${aws_dynamodb_table.files.arn}/*",
        ]
      }
    ]
  })

  tags = {
    Name = "${var.project}-endpoint-dynamodb"
  }
}

# No ingress rules: nothing calls a Lambda over the network.
# Terraform removes AWS's default allow-all egress, so only the rules below apply.
resource "aws_security_group" "lambda" {
  name        = "${var.project}-lambda"
  description = "Vault Lambdas: no inbound, HTTPS out to S3 and DynamoDB only"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_egress_rule" "to_s3" {
  security_group_id = aws_security_group.lambda.id
  description       = "HTTPS to S3 through the gateway endpoint"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = aws_vpc_endpoint.s3.prefix_list_id
}

resource "aws_vpc_security_group_egress_rule" "to_dynamodb" {
  security_group_id = aws_security_group.lambda.id
  description       = "HTTPS to DynamoDB through the gateway endpoint"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = aws_vpc_endpoint.dynamodb.prefix_list_id
}
