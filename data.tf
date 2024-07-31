# get information about our current session
data "aws_caller_identity" "current" {}

# Get SSL certificate for use with CloudFlare
data "aws_acm_certificate" "issued" {
  provider = aws.acm
  domain   = local.domain[0]
  statuses = ["ISSUED", "PENDING_VALIDATION"]
}

# get our SSO admins, as well, conditionally with a flag
# otherwise lookup might fail and break your plan/apply
data "aws_iam_roles" "sso_roles" {
  count       = var.sso_enabled == true ? 1 : 0
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
  # SET THIS TO YOUR SSO ROLE REGEX PATTERN!
  # NOTE that it will be different per account; the base name is the same
  # but each account gets its own random string appended
  name_regex = "Administrator"
}

# Create a bucket policy to restrict access to specific org role for admin
# and usage by all members of your AWS Organizations org
data "aws_iam_policy_document" "bucket_policy" {
  # statement 1 = OrganizationAccountAccessRole default cross-account admin
  # NOTE that the management account does NOT have this role deployed by default!
  # you should probably avoid creating buckets (or resources in general) in that
  # account anyway, in favor of managed member accounts and delegated admin accounts
  # for specific functions!!!
  statement {
    sid    = "AllowAdminAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = local.sso_roles
    }
    actions = [
      "s3:*"
    ]
    resources = [
      aws_s3_bucket.mkdocs.arn,
      "${aws_s3_bucket.mkdocs.arn}/*"
    ]
  }
  # Grant public read access for website hosting
  statement {
    sid    = "AllowPublicReadAccessForMkDocs"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = [
      "s3:GetObject"
    ]
    # grant access to the bucket and its objects for respective s3 actions
    resources = [
      "${aws_s3_bucket.mkdocs.arn}/*"
    ]
  }
  # Grant CloudFront access
  statement {
    sid    = "AllowCloudFrontAccess"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions = [
      "s3:GetObject"
    ]
    # grant access to the bucket and its objects for respective s3 actions
    resources = [
      "${aws_s3_bucket.mkdocs.arn}/*"
    ]
    # Restrict to the specific CDN
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values = [
        aws_cloudfront_distribution.s3_distribution.arn
      ]
    }
  }
}