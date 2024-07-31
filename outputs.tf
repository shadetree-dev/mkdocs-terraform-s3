output "bucket_name" {
  value = aws_s3_bucket.mkdocs.bucket
}

output "website_url" {
  value = "https://${aws_s3_bucket_website_configuration.mkdocs.website_endpoint}"
}