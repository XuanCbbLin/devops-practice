provider "aws" {
  region = "us-east-1"
}

# 建立 bucket
resource "aws_s3_bucket" "static_site" {
  bucket = "my-static-site-1011"
}

# 上傳 index.html
resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.static_site.bucket
  key          = "index.html"
  source       = "index.html"
  content_type = "text/html"
}

# 上傳 index.js
resource "aws_s3_object" "index_js" {
  bucket       = aws_s3_bucket.static_site.bucket
  key          = "index.js"
  source       = "index.js"
  content_type = "application/javascript"
}

# 啟用靜態網站 hosting
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.static_site.bucket

  index_document {
    suffix = "index.html"
  }
}

