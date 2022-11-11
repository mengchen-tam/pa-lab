resource "aws_lb" "gwlb" {
  name               = "gwlb"
  internal           = false
  load_balancer_type = "gateway"
  subnets            = [for subnet in aws_subnet.gwlb_subnet : subnet.id]

  enable_deletion_protection       = false
  enable_cross_zone_load_balancing = true

  tags = {
    Environment = "poc"
  }
}

resource "aws_lb_target_group" "gwlb_tg" {
  name     = "pavm"
  port     = 6081
  protocol = "GENEVE"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    port     = 443
    protocol = "HTTPS"
    path     = "/php/login.php"
  }
}

resource "aws_lb_listener" "gwlb_lstnr" {
  load_balancer_arn = aws_lb.gwlb.id

  default_action {
    target_group_arn = aws_lb_target_group.gwlb_tg.id
    type             = "forward"
  }
}

## GWLB ENDPOINT ## 


resource "aws_vpc_endpoint_service" "gwlb_ep_svc" {
  acceptance_required        = false
  gateway_load_balancer_arns = [aws_lb.gwlb.arn]
  tags = {
    "Name" = "gwlb_endpoint_service"
  }
}

resource "aws_vpc_endpoint" "gwlb_ep" {
  count             = length(aws_subnet.gwlb_subnet.*.id)
  service_name      = aws_vpc_endpoint_service.gwlb_ep_svc.service_name
  subnet_ids        = [aws_subnet.gwlb_subnet[count.index].id]
  vpc_endpoint_type = aws_vpc_endpoint_service.gwlb_ep_svc.service_type
  vpc_id            = aws_vpc.vpc.id
  tags = {
    "Name" = "gwlb_endpoint_az${1 + count.index}"
  }
}