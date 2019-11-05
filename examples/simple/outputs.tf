output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.cloudfront_distribution.id
  description = "The ID of the CloudFront Distribution"
}