# S3 靜態網頁部署研究

## [S3 內存放靜態網站（可以使用簡單的 index.html 跟 index.js 實作）](./s3-static-site/main.tf)

### 新增以下檔案

-   main.tf
-   index.html
-   index.js

### 執行

```bash
terraform init
terraform plan
terraform apply --auto-approve
```

### 看是否成功建立 S3 Bucket

到 AWS S3 頁面，查看是否有成功建立 Bucket
找到建立的 Bucket: `my-static-site-1011` 點開後會有 `index.html` 跟 `index.js` 兩個檔案

![alt text](/understand-static-page-deploy/s3-static-site/image1.png)

### 遇到的問題

#### IAM USER 權限不足

```bash
creating S3 Bucket (my-static-site): operation error S3: CreateBucket, https response error StatusCode: 403, RequestID: 2Z5GDX1ASF4MQVAG, HostID: m3bs792TatfeyAQCzqNw1fJyZnlCN+Ie9eShgv5t0WXRd65K+06SjJr2VR93B4T/9u6NF4E98eZG4+gE4QrC6rcmgm9cztaTuVhnlrPxhMg=, api error AccessDenied: User: arn:aws:iam::420627799355:user/terraform-user is not authorized to perform: s3:CreateBucket on resource: "arn:aws:s3:::my-static-site" because no identity-based policy allows the s3:CreateBucket action
│
│   with aws_s3_bucket.static_site,
│   on main.tf line 6, in resource "aws_s3_bucket" "static_site":
│    6: resource "aws_s3_bucket" "static_site" {
│
```

因為 terraform-user 沒有權限建立 S3 Bucket，所以到 AWS console 裡面去給權限
`IAM > Users > terraform-user > Add permissions`
加上 `AmazonS3FullAccess` 的權限，就可以把 role 給 terraform-user

![alt text](/understand-static-page-deploy/s3-static-site/image.png)

重新執行 `terraform apply --auto-approve`

#### Bucket 名稱重複

因為 S3 Bucket 名稱是全球唯一的，所以如果有人已經建立過 `my-static-site` 這個名稱的 Bucket，就會出現以下錯誤

```bash
Error: creating S3 Bucket (my-static-site): operation error S3: CreateBucket, https response error StatusCode: 409, RequestID: 2VG9KWTCRHY4Q5ES, HostID: KH+TYn8o+n/1vwV2E7s1BA0PeJ4l0J7hH4gcpY+uyVljdIo4HvUeyClpU2T/j+XGIfLT61Mm0QpQaO7X+VY2tg==, BucketAlreadyExists:
│
│   with aws_s3_bucket.static_site,
│   on main.tf line 6, in resource "aws_s3_bucket" "static_site":
│    6: resource "aws_s3_bucket" "static_site" {
│
```

到 main.tf 改掉名稱

```hcl
# 建立 bucket
resource "aws_s3_bucket" "static_site" {
  bucket = "my-static-site-1011"
}
```

#### 靜態網站無法開啟

在 S3 > my-static-site-1011 > Properties > Static website hosting

![alt text](/understand-static-page-deploy/s3-static-site/image-2.png)

但打開會看到 `403 Forbidden` 的錯誤，因為 S3 預設是 private 的，但目前我也不讓 s3 公開出去，就先維持 private 狀態

## [實作 Cloudfront CDN 功能](/understand-static-page-deploy/cloudfront-cdn/main.tf)

### 新增以下檔案

-   main.tf

不建立 index.html 跟 index.js，因為這是使用已經存在的 Bucket

### 遇到的問題

#### 缺少 restrictions 區塊

因為 CloudFront 的 restrictions 是必填的

```bash
Insufficient restrictions blocks │ │ on main.tf line 45, in resource "aws_cloudfront_distribution" "cdn": │ 45: resource "aws_cloudfront_distribution" "cdn" { │ │ At least 1 "restrictions" blocks are required.
```

所以要加上 restrictions 區塊

```hcl
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
```

#### 重複的 Bucket 名稱

因為我在 main.tf 裡面是用 `resource "aws_s3_bucket" "static_site"` 來建立 Bucket，但我已經在 S3 建立過 `my-static-site-1011`

```bash

│ Error: creating S3 Bucket (my-static-site-1011): BucketAlreadyExists
│
│ with aws_s3_bucket.static_site,
│ on main.tf line 6, in resource "aws_s3_bucket" "static_site":
│ 6: resource "aws_s3_bucket" "static_site" {
│
╵
```

所以我改成使用已經存在的 Bucket

```hcl
data "aws_s3_bucket" "static_site" {
  bucket = "my-static-site-1011"
}
```

#### IAM USER 沒有 `CloudFront` 權限

新增 `CloudFrontFullAccess` 的權限給 terraform-user
![alt text](/understand-static-page-deploy/cloudfront-cdn/image.png)

```bash
╷
│ Error: creating CloudFront Origin Access Control (s3-oac-static-site): operation error CloudFront: CreateOriginAccessControl, https response error StatusCode: 403, RequestID: 9da501c6-495e-4057-8c4e-bf7e6cba56fb, api error AccessDenied: User: arn:aws:iam::420627799355:user/terraform-user is not authorized to perform: cloudfront:CreateOriginAccessControl on resource: arn:aws:cloudfront::420627799355:origin-access-control/* because no identity-based policy allows the cloudfront:CreateOriginAccessControl action
│
│   with aws_cloudfront_origin_access_control.oac,
│   on main.tf line 13, in resource "aws_cloudfront_origin_access_control" "oac":
│   13: resource "aws_cloudfront_origin_access_control" "oac" {
│
╵
```

#### CloudFront OAC 名稱重複

因為之前已經建立過 `s3-oac-static-site` 這個 OAC 名稱

```bash
╷
│ Error: creating CloudFront Origin Access Control (s3-oac-static-site): operation error CloudFront: CreateOriginAccessControl, https response error StatusCode: 409, RequestID: d889b9a8-2863-4a9b-8ad7-fce6bfb1a13a, OriginAccessControlAlreadyExists: An origin access control with the same name already exists.
│
│   with aws_cloudfront_origin_access_control.oac,
│   on main.tf line 13, in resource "aws_cloudfront_origin_access_control" "oac":
│   13: resource "aws_cloudfront_origin_access_control" "oac" {
│
╵
```

所以我另外新增 OAC name 為 `s3-oac-static-site-1011`

```hcl
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "s3-oac-static-site-20251011"
  description                       = "OAC for S3 static site"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
```

### 實測

到 CloudFront 頁面，找到剛剛建立的 Distribution
![alt text](/understand-static-page-deploy/cloudfront-cdn/image-2.png)

點 `Distribution domain name` 連結，會看到 `index.html` 跟 `index.js` 的內容

![alt text](/understand-static-page-deploy/cloudfront-cdn/image-3.png)

## S3 需要為 private 的，禁止 public 存取，請研究最佳的權限控管方式（ACL 跟 bucket policy 的差別為？）

因為 S3 預設是 private 如果要控制 s3 的權限可以透過 `IAM Policy`、`S3 Bucket Policy`、`S3 ACL`，其中 ACL 跟 bucket policy 官方推薦用 bucket policy 管理權限，以下幾個原因

1. bucket policy:

    - 管理: 是一份 JSON 文件，套用在整個 bucket
    - 安全性: 可以精準限制誰能存取和在什麼情況下存取

2. ACL:
    - 管理: 權限分散在每個物件，規模一大就難以追蹤
    - 安全性: 沒辦法做精確的條件判斷，容易造成誤設公開存取的風險
