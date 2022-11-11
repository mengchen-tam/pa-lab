
resource "aws_iam_policy" "lambda_policy" {
  name   = "jenkins_lc_policy"
  policy = data.aws_iam_policy_document.lambda_policy.json
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"
  path = "/system/"
  depends_on = [
    aws_iam_policy.lambda_policy,
  ]
  assume_role_policy  = data.aws_iam_policy_document.lambda-assume-role-policy.json
  managed_policy_arns = [aws_iam_policy.lambda_policy.arn]
}

resource "aws_iam_role" "ssm_role" {
  name                = "ssm_role"
  assume_role_policy  = data.aws_iam_policy_document.ssm_ec2.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM", "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "spoke_ssm_profile"
  role = aws_iam_role.ssm_role.name
}

### PAVM IAM ROLE ###

resource "aws_iam_policy" "pavm_pol" {
  name   = "pavm_cw_policy"
  policy = data.aws_iam_policy_document.pavm_cw_metric_pol.json
}

resource "aws_iam_role" "pavm_cw_role" {
  name                = "pavm_cw_role"
  assume_role_policy  = data.aws_iam_policy_document.pavm_assume_pol.json
  managed_policy_arns = ["${aws_iam_policy.pavm_pol.arn}", "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM", "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
}
resource "aws_iam_instance_profile" "pavm_cw_profile" {
  name = "pavm_profile"
  role = aws_iam_role.pavm_cw_role.name
}