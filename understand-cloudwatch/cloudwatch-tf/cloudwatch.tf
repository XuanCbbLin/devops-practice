resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "CPU-High-70-${aws_instance.monitor_ec2.id}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "CPU usage above 70%"
  dimensions = {
    InstanceId = aws_instance.monitor_ec2.id
  }

  alarm_actions = [aws_sns_topic.cw_cpu_alerts.arn]
}
