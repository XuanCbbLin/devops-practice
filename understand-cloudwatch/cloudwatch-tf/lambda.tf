data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.mjs"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda-discord-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "cw_to_discord" {
  function_name = "cwAlarmToDiscord"
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  role          = aws_iam_role.lambda_role.arn
  filename      = data.archive_file.lambda_zip.output_path

  environment {
    variables = {
      DISCORD_WEBHOOK_URL = var.discord_webhook_url
    }
  }
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cw_to_discord.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.cw_cpu_alerts.arn
}

resource "aws_sns_topic_subscription" "sns_to_lambda" {
  topic_arn = aws_sns_topic.cw_cpu_alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.cw_to_discord.arn
}
