data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "zone-name"
    values = ["${data.aws_region.current.name}a", "${data.aws_region.current.name}b"]
  }
}
data "aws_iam_policy_document" "lambda-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    sid = "AllowActions"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DetachNetworkInterface",
      "autoscaling:CompleteLifecycleAction",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:DeleteNetworkInterface",
      "autoscaling:PutLifecycleHook",
      "autoscaling:DetachLoadBalancerTargetGroups",
      "ec2:AttachNetworkInterface",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "autoscaling:AttachLoadBalancerTargetGroups",
      "ec2:DeleteTags",
      "ec2:CreateTags",
    ]
    resources = [
      "arn:aws:autoscaling:*:${data.aws_caller_identity.current.account_id}:autoScalingGroup:*:autoScalingGroupName/*",
      "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:instance/*",
      "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:network-interface/*",
      "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:subnet/*",
      "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:security-group/*"
    ]
  }
  statement {
    sid = "AllowActionsLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = [
      "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:*"
    ]
  }
  statement {
    sid = "DescribeActions"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeNetworkInterfaceAttribute",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSecurityGroupRules",
      "ec2:DescribeTags"
    ]
    resources = [
      "*"
    ]
  }
}

data "archive_file" "lambda" {
  type             = "zip"
  source_file      = "${path.module}/scripts/lambda_function.py"
  output_file_mode = "0666"
  output_path      = "${path.module}/scripts/lambda_function.zip"
}

data "aws_iam_policy_document" "ssm_ec2" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "pavm_cw_metric_pol" {
  statement {
    sid = "AllowCWMetrics"
    actions = [
      "cloudwatch:PutMetricData"
    ]
    resources = [
      "*"
    ]
  }
}
data "aws_iam_policy_document" "pavm_assume_pol" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "http" "ip" {
  url = "https://ifconfig.me/ip"
}
