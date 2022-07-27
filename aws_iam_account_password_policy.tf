resource "aws_iam_account_password_policy" "polciy" {
  minimum_password_length      = 7
  require_lowercase_characters = false
  require_numbers              = false
  require_uppercase_characters   = false
  require_symbols                = false
  allow_users_to_change_password = false
  password_reuse_prevention      = 1
  max_password_age               = 1
}
