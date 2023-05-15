# ### CREATE VPC ###

resource "aws_vpc" "spoke_vpc" {
  cidr_block           = var.spoke_vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    "Name" = "spoke_vpc"
  }
}

# ### CREATE PRIVATE SUBNETS ###

resource "aws_subnet" "app_subnet" {
  count                   = length(data.aws_availability_zones.available.names)
  vpc_id                  = aws_vpc.spoke_vpc.id
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = cidrsubnet("${aws_vpc.spoke_vpc.cidr_block}", 4, "${1 + count.index}")
  tags = {
    Name = "spoke_vpc_private_subnet_az${1 + count.index}"
  }
}

resource "aws_subnet" "app_tgw_subnet" {
  count                   = length(data.aws_availability_zones.available.names)
  vpc_id                  = aws_vpc.spoke_vpc.id
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = cidrsubnet("${aws_vpc.spoke_vpc.cidr_block}", 4, "${3 + count.index}")
  tags = {
    Name = "spoke_vpc_tgw_subnet_az${1 + count.index}"
  }
}


# #### Spoke VPC Subnet Routes ####


resource "aws_route_table" "spoke_vpc_subnets_rt" {
  vpc_id = aws_vpc.spoke_vpc.id
  route {
    cidr_block         = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }
  tags = {
    "Name" = "spoke_vpc_subnet_rtb"
  }
}

resource "aws_route_table_association" "spoke_vpc_subnets_rt_assoc" {
  count          = length(aws_subnet.app_subnet.*.id)
  subnet_id      = aws_subnet.app_subnet[count.index].id
  route_table_id = aws_route_table.spoke_vpc_subnets_rt.id
}



resource "aws_route_table" "spoke_vpc_tgw_subnets_rt" {
  vpc_id = aws_vpc.spoke_vpc.id
  tags = {
    "Name" = "spoke_vpc_tgw_subnet_rtb"
  }
}

resource "aws_route_table_association" "spoke_vpc_tgw_subnets_rt_assoc" {
  count          = length(aws_subnet.app_tgw_subnet.*.id)
  subnet_id      = aws_subnet.app_tgw_subnet[count.index].id
  route_table_id = aws_route_table.spoke_vpc_tgw_subnets_rt.id
}

resource "aws_instance" "spoke_vm" {
  count                  = length(aws_subnet.app_subnet.*.id)
  ami                    = "ami-0265f042d3f2c3813"
  instance_type          = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.spoke.id}"]
  subnet_id              = aws_subnet.app_subnet[count.index].id
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }
  tags = {
    "Name" = "spoke_vpc_vm_az${1 + count.index}"
  }
  depends_on = [
    aws_security_group.spoke
  ]
}

## SSM Endpoints for EC2 Connectivity ###

resource "aws_vpc_endpoint" "spoke_vpc_ssm_ep" {
  count = length([
    "com.amazonaws.${data.aws_region.current.name}.ssm",
    "com.amazonaws.${data.aws_region.current.name}.ssmmessages",
    "com.amazonaws.${data.aws_region.current.name}.ec2messages"
  ])
  subnet_ids        = [for subnet in aws_subnet.app_subnet : subnet.id]
  vpc_endpoint_type = "Interface"
  service_name = ([
    "com.amazonaws.${data.aws_region.current.name}.ssm",
    "com.amazonaws.${data.aws_region.current.name}.ssmmessages",
    "com.amazonaws.${data.aws_region.current.name}.ec2messages"
  ][count.index])
  private_dns_enabled = true
  ip_address_type     = "ipv4"
  security_group_ids  = [aws_security_group.ssm_ep.id]
  dns_options {
    dns_record_ip_type = "ipv4"
  }
  vpc_id = aws_vpc.spoke_vpc.id
  tags = {
    "Name" = "spoke_vpc_ssm_endpoint_${1 + count.index}"
  }
}