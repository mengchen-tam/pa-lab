#### AWS ASG: LAUNCH TEMPLATE ####

resource "aws_launch_template" "tmpl" {
  name_prefix   = "pavmasg_tmpl"
  image_id      = var.pavm_ami
  instance_type = "m4.large"
  key_name      = var.key_name
  user_data     = filebase64("${path.module}/scripts/userdata.sh")
  iam_instance_profile {
    name = aws_iam_instance_profile.pavm_cw_profile.name
  }
  network_interfaces {
    associate_public_ip_address = false
    device_index                = 0
    security_groups             = [aws_security_group.data.id]
  }
  metadata_options {
    http_tokens = "required"
  }
  monitoring {
    enabled = true
  }
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = "65"
      volume_type = "gp2"
      encrypted   = true
    }
  }
}

## PAVM: ASG ##

resource "aws_autoscaling_group" "myasg" {
  name                      = "myasg"
  max_size                  = 4
  min_size                  = 2
  health_check_grace_period = 1800
  health_check_type         = "EC2"
  force_delete              = true
  target_group_arns         = [aws_lb_target_group.gwlb_tg.arn]
  initial_lifecycle_hook {
    name                 = "launch"
    default_result       = "ABANDON"
    heartbeat_timeout    = 300
    lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
  }
  initial_lifecycle_hook {
    name                 = "terminate"
    default_result       = "ABANDON"
    heartbeat_timeout    = 300
    lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
  }
  launch_template {
    id      = aws_launch_template.tmpl.id
    version = "$Latest"
  }
  vpc_zone_identifier = [for subnet in aws_subnet.data_subnet : subnet.id]
  timeouts {
    delete = "20m"
  }
  wait_for_capacity_timeout = "20m"
  depends_on = [
    aws_lb_target_group.gwlb_tg,
    aws_cloudwatch_event_rule.cw_rule,
    aws_lambda_function.lambda,
    aws_lambda_permission.event_bridge,
    aws_cloudwatch_event_target.cw_lambda_target
  ]
  tag {
    key                 = "Name"
    value               = "pavm"
    propagate_at_launch = true
  }
}

### PAVM: ASG Scaling Policies ###

resource "aws_autoscaling_policy" "panSessionUtilization" {
  autoscaling_group_name = aws_autoscaling_group.myasg.name
  name                   = "panSessionUtilization"
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    target_value = 50
    customized_metric_specification {
      metric_name = "panSessionUtilization"
      namespace   = "VMseries"
      statistic   = "Average"
    }
  }
}

resource "aws_autoscaling_policy" "DataPlaneCPUUtilizationPct" {
  autoscaling_group_name = aws_autoscaling_group.myasg.name
  name                   = "DataPlaneCPUUtilizationPct"
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    target_value = 50
    customized_metric_specification {
      metric_name = "DataPlaneCPUUtilizationPct"
      namespace   = "VMseries"
      statistic   = "Average"
    }
  }
}