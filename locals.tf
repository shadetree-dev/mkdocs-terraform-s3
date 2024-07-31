locals {
  # Make sure name is lowercase and pseudo name it if not provided
  name = var.name != "" ? lower(var.name) : "example-mkdocs-bucket-${formatdate("YYYYMMDD", timestamp())}"

  # Define your web domain, where we add the wildcard if you don't include it
  # Make sure the first index is the one that matches ACM cert so you can use the data.tf lookup
  domain = (
    length(var.domain) < 2 ?
    concat(var.domain,["*.${var.domain}"]) : 
    var.domain
  )

  # Get your AWS Organizations org ID dynamically and set here for re-use
  org_id = data.aws_organizations_organization.my_org.id

  # Get our SSO roles, supposing we are (hopefully) using SSO!
  sso_roles = tolist(data.aws_iam_roles.sso_roles[0].arns)

  # Set some standard tags we can pass to resources
  tags = {
    purpose        = "mkdocs-site"
    iac_last_apply = timestamp()
  }
}