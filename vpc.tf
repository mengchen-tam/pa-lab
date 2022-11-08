### CREATE VPC ###

resource "aws_vpc" "vpc" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    "Name" = "inspection_vpc"
  }
}

### CREATE DATA, MGMT AND PRIVATE SUBNETS IN 2 AZs###

resource "aws_subnet" "gwlb_subnet" {
  count                   = "${length(data.aws_availability_zones.available.names)}"
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  cidr_block              = cidrsubnet("${aws_vpc.vpc.cidr_block}", 4, "${1 + count.index}")
  tags = {
    Name = "gwlb_subnet_az${1+ count.index}"
  }
}

resource "aws_subnet" "pavm_mgmt_subnet" {
  count                   = "${length(data.aws_availability_zones.available.names)}"
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  cidr_block              = cidrsubnet("${aws_vpc.vpc.cidr_block}", 4, "${3 + count.index}")
  tags = {
    Name = "mgmt_subnet_az${1+ count.index}"
  }
}

resource "aws_subnet" "tgw_attach_subnet" {
  count                   = "${length(data.aws_availability_zones.available.names)}"
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  cidr_block              = cidrsubnet("${aws_vpc.vpc.cidr_block}", 4, "${5 + count.index}")
  tags = {
    Name = "tgw_subnet_az${1+ count.index}"
  }
}

resource "aws_subnet" "data_subnet" {
  count                   = "${length(data.aws_availability_zones.available.names)}"
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  cidr_block              = cidrsubnet("${aws_vpc.vpc.cidr_block}", 4, "${7 + count.index}")
  tags = {
    Name = "data_subnet_az${1+ count.index}"
  }
}

### IGW ###

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "IGW"
  }
}

## NGW ## 


resource "aws_eip" "ngw_eip" {
  count = length(aws_subnet.pavm_mgmt_subnet.*.id)
  vpc = true
}

resource "aws_nat_gateway" "nat_gateway" {
  count = length(aws_subnet.pavm_mgmt_subnet.*.id)
  allocation_id = aws_eip.ngw_eip[count.index].id
  subnet_id = aws_subnet.pavm_mgmt_subnet[count.index].id
  tags = {
    "Name" = "natgw_az${1+count.index}"
  }
  depends_on = [
    aws_internet_gateway.igw
  ]
}