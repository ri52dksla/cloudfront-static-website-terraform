variable "aliases" {
  type = list(string)
  description = "alternate domain names"
}

variable "cloudfront_access_logs_bucket_name" {
  type = string
  description = "The name of the CloudFront access log S3 bucket"
}

variable "cloudfront_access_log_prefix" {
  type = string
  description = "prefix to the CloudFront access log"
  default = null
}

variable "cloudfront_price_class" {
  type = string
  description = "CloudFront Price Class"
}

variable "cloudfront_default_ttl" {
  type = number
  description = ""
}

variable "cloudfront_min_ttl" {
  type = number
  description = ""
}

variable "cloudfront_max_ttl" {
  type = number
  description = ""
}

variable "acm_certificate_arn" {
  type = string
  description = "The ARN of the Certificate. The certificate must be in US East region"
}

variable "cloudfront_origin_id" {
  type = string
  description = ""
}

variable "static_website_bucket_name" {
  type = string
  description = "The name of the static website S3 bucket"
}

variable "tags" {
  type = map(string)
  default = {}
  description = "Tags applied to all created resources"
}