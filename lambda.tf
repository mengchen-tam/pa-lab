resource "aws_lambda_function" "lambda" {
  filename      = "${path.module}/scripts/lambda_function.zip"
  function_name = "lambda_function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime = "python3.8"
  timeout = 600
  environment {
    variables = {
      mgmt_sg = "mgmt_sg" 
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
  principal     = "events.amazonaws.com"
  depends_on = [
    aws_lambda_function.lambda,
  ]
}