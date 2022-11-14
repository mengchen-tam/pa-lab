#### CREATE SGs ####

resource "aws_security_group" "mgmt" {
  name        = "mgmt_sg"
  description = "PA VM - MGMT Security Group"
  vpc_id      = aws_vpc.vpc.id
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }
  ingress {
    cidr_blocks = ["${var.inspection_vpc_cidr_block}"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }
  ingress {
    cidr_blocks = ["${data.http.ip.response_body}/32"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }
  ingress {
    cidr_blocks = ["${data.http.ip.response_body}/32"]
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
  }
  tags = {
    "Name" = "mgmt_sg"
  }
}

resource "aws_security_group" "data" {
  name        = "data_sg"
  description = "PA VM - DATA Interface Security Group"
  vpc_id      = aws_vpc.vpc.id
  ingress {
    cidr_blocks = ["${var.inspection_vpc_cidr_block}"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }
  ingress {
    cidr_blocks = ["${var.inspection_vpc_cidr_block}"]
    from_port   = 6081
    to_port     = 6081
    protocol    = "UDP"
  }  
  egress {
    cidr_blocks = ["${var.inspection_vpc_cidr_block}"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }
  tags = {
    "Name" = "data_sg"
  }
}

resource "aws_security_group" "spoke" {
  name        = "spoke_sg"
  description = "Spoke VPC - Security Group"
  vpc_id      = aws_vpc.spoke_vpc.id
  egress {
    cidr_blocks = ["${aws_vpc.spoke_vpc.cidr_block}"]
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
  }
  tags = {
    "Name" = "spoke_sg"
  }
}


resource "aws_security_group" "ssm_ep" {
  name        = "ssm_ep_sg"
  description = "SSM EP - Spoke VPC Security Group"
  vpc_id      = aws_vpc.spoke_vpc.id
  ingress {
    cidr_blocks = ["${aws_vpc.spoke_vpc.cidr_block}"]
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
  }
  tags = {
    "Name" = "ssm_ep_sg"
  }
}