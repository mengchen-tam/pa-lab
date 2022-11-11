resource "aws_lambda_function" "lambda" {
  filename         = "${path.module}/scripts/lambda_function.zip"
  function_name    = "lambda_function"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime          = "python3.8"
  timeout          = 600
  environment {
    variables = {
      mgmt_sg         = "mgmt_sg"
      mgmt_subnet_az1 = "mgmt_subnet_az1"
      mgmt_subnet_az2 = "mgmt_subnet_az2"
    }
  }
  depends_on = [
    aws_iam_role.lambda_role,
  ]
}

resource "aws_lambda_permission" "event_bridge" {
  statement_id  = "AllowExecutionFromEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  source_arn    = aws_cloudwatch_event_rule.cw_rule.arn
  principal     = "events.amazonaws.com"
  depends_on = [
    aws_lambda_function.lambda,
  ]
}

resource "aws_cloudwatch_event_rule" "cw_rule" {
  name          = "lambda_trigger"
  description   = "Invoke Lambda"
  event_pattern = <<EOF
{
  "source": [
    "aws.autoscaling"
  ],
  "detail-type": [
    "EC2 Instance-launch Lifecycle Action",
    "EC2 Instance-terminate Lifecycle Action"
  ]
}
EOF
}

resource "aws_cloudwatch_event_target" "cw_lambda_target" {
  target_id = "InvokeLambdaAttachENI"
  rule      = aws_cloudwatch_event_rule.cw_rule.name
  arn       = aws_lambda_function.lambda.arn
  depends_on = [
    aws_cloudwatch_event_rule.cw_rule,
  ]
}