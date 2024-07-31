provider "aws" {
  region  = var.region
  profile = var.sso_profile
  assume_role {
    role_arn = var.sso_profile != null ? null : "arn:aws:iam::${var.account_id}:role/OrganizationAccountAccessRole"
  }
}

provider "aws" {
  region  = "us-east-1"
  alias   = "acm"
  profile = var.sso_profile
  assume_role {
    role_arn = var.sso_profile != null ? null : "arn:aws:iam::${var.account_id}:role/OrganizationAccountAccessRole"
  }
}