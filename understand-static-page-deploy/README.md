# S3 靜態網頁部署研究

## [S3 內存放靜態網站（可以使用簡單的 index.html 跟 index.js 實作）](./s3-static-site/)

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
