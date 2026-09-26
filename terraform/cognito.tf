# Cognito login system: user pool (accounts) and web app client (the website).

resource "aws_cognito_user_pool" "users" {
  name = "${var.project}-users"

  # Email is the username. Changing this later forces the pool (and every user) to be recreated.
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  # Optional MFA via authenticator app only. No SMS: it costs money and is exposed to SIM swapping.
  mfa_configuration = "OPTIONAL"
  software_token_mfa_configuration {
    enabled = true
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }
}

resource "aws_cognito_user_pool_client" "web" {
  name         = "${var.project}-web"
  user_pool_id = aws_cognito_user_pool.users.id

  generate_secret               = false # a browser app can't keep a secret
  explicit_auth_flows           = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  prevent_user_existence_errors = "ENABLED"

  # Short-lived ID/access tokens limit how long a stolen token is useful; refresh keeps users signed in.
  id_token_validity      = 15
  access_token_validity  = 15
  refresh_token_validity = 7

  token_validity_units {
    id_token      = "minutes"
    access_token  = "minutes"
    refresh_token = "days"
  }

  enable_token_revocation = true
}
