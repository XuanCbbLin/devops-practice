provider "aws" {
  region = "us-east-1"
}

# 使用現有的 S3 bucket（不是重建）
data "aws_s3_bucket" "static_site" {
  bucket = "my-static-site-1011"
}

# -------------------------------------
# CloudFront: 建立 OAC
# -------------------------------------
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "s3-oac-static-site-20251011"
  description                       = "OAC for S3 static site"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# -------------------------------------
# 建立 CloudFront Distribution
# -------------------------------------
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name              = data.aws_s3_bucket.static_site.bucket_regional_domain_name
    origin_id                = "s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-origin"

    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# -------------------------------------
# S3 Bucket Policy：允許 CloudFront OAC 存取
# -------------------------------------
data "aws_iam_policy_document" "allow_cf_oac" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${data.aws_s3_bucket.static_site.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cdn.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "allow_cf_oac" {
  bucket = data.aws_s3_bucket.static_site.id
  policy = data.aws_iam_policy_document.allow_cf_oac.json
}
