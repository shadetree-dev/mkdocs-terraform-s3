# NOTE: buckets are globally unique, so make sure it is not taken
resource "aws_s3_bucket" "mkdocs" {
  bucket = var.name

  # set timeout, because it SHOULD create quickly; something up if not 
  timeouts {
    create = "1m"
  }

  tags = local.tags
}

# Policy that allows admin within your org and basic public read
resource "aws_s3_bucket_policy" "website_policy" {
  bucket = aws_s3_bucket.mkdocs.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}

# Enable S3 encryption with Amazon-managed key
resource "aws_s3_bucket_server_side_encryption_configuration" "sse" {
  bucket = aws_s3_bucket.mkdocs.id

  rule {
    bucket_key_enabled = true
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Enable versioning
resource "aws_s3_bucket_versioning" "mkdocs" {
  bucket = aws_s3_bucket.mkdocs.id
  versioning_configuration {
    status = "Enabled"
  }
}


# Allow public access for website usage
# BE MINDFUL OF THESE SETTINGS AND OTHER CONTROL MECHANISMS TO SECURE YOUR CONTENT!
resource "aws_s3_bucket_public_access_block" "allow_public" {
  bucket                  = aws_s3_bucket.mkdocs.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Set the static hosting configuration parameters
resource "aws_s3_bucket_website_configuration" "mkdocs" {
  depends_on = [
    aws_s3_bucket_public_access_block.allow_public
  ]
  bucket = aws_s3_bucket.mkdocs.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

# Create a new CloudFront distribution for frontend proxy/SSL of your bucket with custom domain name
resource "aws_cloudfront_distribution" "s3_distribution" {
  depends_on = [
    aws_s3_bucket.mkdocs
  ]

  # Create a custom origin, as we need to use the S3 website config, not just S3 origin
  origin {
    # Origin is the website endpoint of the S3 bucket, NOT publicly accessible S3 endpoint itself
    # https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteEndpoints.html
    domain_name = aws_s3_bucket_website_configuration.mkdocs.website_endpoint
    origin_id = local.name
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      # The origin has to be on HTTP
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CDN for HTTPS access of S3 static website via custom domain"
  default_root_object = "index.html"

  # In locals we add wildcard if it is not already there
  aliases = local.domain

  # Default cache is to NOT cache so that updates to your site show up immediately
  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.name
    # Redirect from HTTP (required for S3 to CloudFront) to HTTPS (for viewer)
    viewer_protocol_policy = "redirect-to-https"

    ## Managed-CachingOptimized - change to this policy if you want caching
    # cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"

    # Managed-CachingDisabled
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"

    # Managed-AllViewerExceptHostHeader
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"

    # Set compression and TTL according to your needs
    compress                 = true
    min_ttl                  = 0
    default_ttl              = 300
    max_ttl                  = 3600
  }

  # Cheapest price class default to North America and Europe
  # If you want global can use a more default approach of PriceClass_200
  price_class = "PriceClass_100"

  # Required for none, whitelist, or blacklisting
  restrictions {
    geo_restriction {
      restriction_type = "blacklist"
      # Common blacklisted geo list, edit as needed
      locations = [
        "RU",
        "CN",
        "KP",
        "IR",
        "SY",
        "SD",
        "BY",
        "PK",
        "VE",
        "CU",
        "NG",
        "SO",
        "AF",
        "IQ",
        "YE",
        "CD",
        "ZW",
        "ER"
      ]
    }
  }

  # Use ACM certificate for HTTPS
  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.issued.arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }

  # Set some default tags
  tags = local.tags
}