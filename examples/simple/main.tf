## Create CloudFront Distribution
resource "aws_cloudfront_distribution" "cloudfront_distribution" {

  ## https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/CNAMEs.html
  ## https://docs.aws.amazon.com/cloudfront/latest/APIReference/API_Aliases.html
  aliases = var.aliases

  comment = format("CloudFront Distribution for %s", join(", ", var.aliases))

  default_cache_behavior {

    ## https://docs.aws.amazon.com/cloudfront/latest/APIReference/API_AllowedMethods.html
    allowed_methods = [
      "HEAD",
      "GET"]

    ## https://docs.aws.amazon.com/ja_jp/cloudfront/latest/APIReference/API_CachedMethods.html
    cached_methods = [
      "HEAD",
      "GET"]

    forwarded_values {
      cookies {
        forward = "none"
      }
      headers = []
      query_string = true
    }

    target_origin_id = var.cloudfront_origin_id

    compress = "true"

    ## Set TTL
    ## https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Expiration.html#ExpirationDownloadDist

    ## https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/distribution-web-values-specify.html#DownloadDistValuesDefaultTTL
    default_ttl = var.cloudfront_default_ttl
    ## https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/distribution-web-values-specify.html#DownloadDistValuesMinTTL
    min_ttl = var.cloudfront_min_ttl
    ## https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/distribution-web-values-specify.html#DownloadDistValuesMaxTTL
    max_ttl = var.cloudfront_max_ttl

    ## https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-https-viewers-to-cloudfront.html
    ## https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/distribution-web-values-specify.html#DownloadDistValuesViewerProtocolPolicy
    ## https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-https-cloudfront-to-s3-origin.html
    viewer_protocol_policy = "redirect-to-https"
  }

  ## https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/DefaultRootObject.html
  default_root_object = "index.html"

  ## set static website bucket as origin
  origin {
    ## > When you specify the Amazon S3 bucket that you want CloudFront to get objects from, we recommend that you use the following format to access the bucket:
    ## > bucket-name.s3.region.amazonaws.com
    ## https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/DownloadDistS3AndCustomOrigins.html#concept_S3Origin
    ## https://www.terraform.io/docs/providers/aws/r/s3_bucket.html#bucket_regional_domain_name
    domain_name = aws_s3_bucket.static_website_bucket.bucket_regional_domain_name

    origin_id = var.cloudfront_origin_id

    ## restring access to static website bucket
    ## https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin-access-identity.cloudfront_access_identity_path
    }
  }

  enabled = true

  ## https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/distribution-web-values-specify.html#DownloadDistValuesSupportedHTTPVersions
  http_version = "http2"

  ## CloudFront access log
  ## https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/AccessLogs.html
  logging_config {
    ## ${ACCESS_LOG_BUCKET_NAME}.s3.amazonaws.com
    ## https://docs.aws.amazon.com/ja_jp/cloudfront/latest/APIReference/API_LoggingConfig.html
    bucket = format("%s.s3.amazonaws.com", aws_s3_bucket.cloudfront_access_logs_bucket.id)
    include_cookies = true
    prefix = var.cloudfront_access_log_prefix
  }

  ## https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/PriceClass.html
  ## https://docs.aws.amazon.com/cloudfront/latest/APIReference/API_DistributionConfig.html#cloudfront-Type-DistributionConfig-PriceClass
  price_class = var.cloudfront_price_class

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    ## https://docs.aws.amazon.com/acm/latest/userguide/acm-regions.html
    ## > To use an ACM Certificate with Amazon CloudFront, you must request or import the certificate in the US East (N. Virginia) region. ACM Certificates in this region that are associated with a CloudFront distribution are distributed to all the geographic locations configured for that distribution.
    ## https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cnames-and-https-requirements.html#https-requirements-aws-region
    acm_certificate_arn = var.acm_certificate_arn

    ## > We recommend that you specify TLSv1.1_2016 unless your users are using browsers or devices that don't support TLSv1.1 or later.
    ## https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/secure-connections-supported-viewer-protocols-ciphers.html#secure-connections-supported-ciphers
    minimum_protocol_version = "TLSv1.1_2016"

    # use sni
    # https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cnames-https-dedicated-ip-or-sni.html#cnames-https-sni
    ssl_support_method = "sni-only"
  }

  tags = merge(
  var.tags
  )
}

## Create CloudFront access log bucket
resource "aws_s3_bucket" "cloudfront_access_logs_bucket" {

  bucket = var.cloudfront_access_logs_bucket_name

  acl = "private"

  versioning {
    enabled = true
  }

  force_destroy = true

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = merge(
  var.tags,
  map("Name", var.cloudfront_access_logs_bucket_name)
  )
}

## Manages S3 bucket-level Public Access Block configuration for CloudFront access log bucket
resource "aws_s3_bucket_public_access_block" "cloudfront_access_logs_bucket_s3_bucket_public_access_block" {
  bucket = aws_s3_bucket.cloudfront_access_logs_bucket.id

  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

## Create a metrics configuration for CloudFront access log bucket
### https://docs.aws.amazon.com/AmazonS3/latest/dev/metrics-configurations.html
resource "aws_s3_bucket_metric" "cloudfront_access_logs_bucket_s3_bucket_metrics" {
  bucket = aws_s3_bucket.static_website_bucket.bucket
  name = "EntireBucket"
}

## Create CloudFront Origin Access Identity
### https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html#private-content-creating-oai
resource "aws_cloudfront_origin_access_identity" "origin-access-identity" {
  comment = format("Origin Access Identity to access to %s", var.static_website_bucket_name)
}

## Create static website bucket

### > If you use an Amazon S3 bucket configured as a website endpoint,
### > you must set it up with CloudFront as a custom origin and you can't use the origin access identity feature described in this topic.his bucket should not be configured as
### https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html
### https://aws.amazon.com/blogs/aws/amazon-s3-block-public-access-another-layer-of-protection-for-your-accounts-and-buckets/
resource "aws_s3_bucket" "static_website_bucket" {

  bucket = var.static_website_bucket_name

  acl = "private"

  versioning {
    enabled = true
  }

  force_destroy = true

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = merge(
  map("Name", var.static_website_bucket_name),
  var.tags
  )
}

## Attach Bucket Policy to the static website bucket
resource "aws_s3_bucket_policy" "static_website_bucket_s3_bucket_policy" {
  bucket = aws_s3_bucket.static_website_bucket.id
  policy = data.aws_iam_policy_document.static_website_bucket_s3_bucket_policy_iam_policy_document.json
}

## Generate S3 Bucket Policy Document that will be attached to S3 Bucket for static website
### https://www.terraform.io/docs/providers/aws/r/cloudfront_origin_access_identity.html#updating-your-bucket-policy
### https://www.terraform.io/docs/providers/aws/r/cloudfront_origin_access_identity.html#updating-your-bucket-policy
### https://docs.aws.amazon.com/AmazonS3/latest/dev/example-bucket-policies.html#example-bucket-policies-use-case-6
data "aws_iam_policy_document" "static_website_bucket_s3_bucket_policy_iam_policy_document" {

  statement {
    sid = format("Grant CloudFront Origin Access Identity access to objects in bucket(%s)", aws_s3_bucket.static_website_bucket.id)

    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    principals {
      type = "AWS"

      identifiers = [
        aws_cloudfront_origin_access_identity.origin-access-identity.iam_arn,
      ]
    }

    resources = [
      format("arn:aws:s3:::%s/*", aws_s3_bucket.static_website_bucket.id)
    ]
  }
}

## Manages S3 bucket-level Public Access Block configuration for static website bucket
resource "aws_s3_bucket_public_access_block" "static_website_bucket_s3_bucket_public_access_block" {
  bucket = aws_s3_bucket.static_website_bucket.id

  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

## Create a metrics configuration for static website bucket
### https://docs.aws.amazon.com/AmazonS3/latest/dev/metrics-configurations.html
resource "aws_s3_bucket_metric" "static_website_bucket_s3_bucket_metrics" {
  bucket = aws_s3_bucket.static_website_bucket.bucket
  name = "EntireBucket"
}

## Upload index.html to static website bucket
resource "aws_s3_bucket_object" "index_html_s3_bucket_object" {
  bucket = aws_s3_bucket.static_website_bucket.id
  key = "index.html"
  source = "${path.module}/files/index.html"
  content_type = "text/html; charset=UTF-8"
  etag = filemd5("${path.module}/files/index.html")
  force_destroy = true
  tags = merge(
  var.tags
  )
}