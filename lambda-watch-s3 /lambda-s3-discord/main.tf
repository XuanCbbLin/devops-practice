terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.6.0"
}

provider "aws" {
  region = "ap-northeast-1" # 東京區域
}

resource "aws_s3_bucket" "invoices" {
  bucket = "lambda-s3-discord-demo-bucket"
}

resource "aws_s3_bucket_notification" "notify_lambda" {
  bucket = aws_s3_bucket.invoices.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.notify_discord.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

