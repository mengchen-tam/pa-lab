### Route Tables ###

resource "aws_route_table" "data_subnet_rtb" {
  vpc_id = aws_vpc.vpc.id
  route = []
  tags = {
    "Name" = "data_subnet_rtb"
  }
}

resource "aws_route_table_association" "data_rt_assoc" {
  count          = length(aws_subnet.data_subnet.*.id)
  subnet_id      = aws_subnet.data_subnet[count.index].id
  route_table_id = aws_route_table.data_subnet_rtb.id
}

### TGW Route Table and Assoc. ###

resource "aws_ec2_transit_gateway_route_table" "inspection" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  tags = {
    "Name" = "inspection"
  }
}

# Routes 

resource "aws_ec2_transit_gateway_route" "inspection_rt" {
  destination_cidr_block         = aws_vpc.spoke_vpc.cidr_block
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke.id
}


resource "aws_ec2_transit_gateway_route_table_association" "inspection_assoc" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.inspection.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection.id
}


#### SPOKE ####


resource "aws_ec2_transit_gateway_route_table" "spoke" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  tags = {
    "Name" = "spoke"
  }
}

# Routes 

resource "aws_ec2_transit_gateway_route" "spoke_rt" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.inspection.id
}


resource "aws_ec2_transit_gateway_route_table_association" "spoke_assoc" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}


#### TGW Attach Subnet Routes - Inspection VPC ####

resource "aws_route_table" "tgw_attach_subnet_az1" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    vpc_endpoint_id = aws_vpc_endpoint.gwlb_ep.*.id[0]
  }
  tags = {
    "Name" = "tgw_attach_subnet_rtb_az1"
  }
} 


resource "aws_route_table_association" "tgw_attach_subnet_rt_az1" {
  count = length([for subnet in aws_subnet.tgw_attach_subnet : subnet.id])  
  subnet_id      = sort(aws_subnet.tgw_attach_subnet.*.id)[0]
  route_table_id = aws_route_table.tgw_attach_subnet_az1.id
}


resource "aws_route_table" "tgw_attach_subnet_az2" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    vpc_endpoint_id = aws_vpc_endpoint.gwlb_ep.*.id[1]
  }
  tags = {
    "Name" = "tgw_attach_subnet_rtb_az2"
  }
}

resource "aws_route_table_association" "tgw_attach_subnet_rt_az2" {
  count =  length([for subnet in aws_subnet.tgw_attach_subnet : subnet.id]) 
  subnet_id      = sort(aws_subnet.tgw_attach_subnet.*.id)[1]
  route_table_id = aws_route_table.tgw_attach_subnet_az2.id
}


#### GWLB  Subnet Routes - Inspection VPC ####



resource "aws_route_table" "gwlb_subnet_az1" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = aws_vpc.spoke_vpc.cidr_block
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.*.id[0]
  }
  tags = {
    "Name" = "gwlb_subnet_rtb_az1"
  }
} 


resource "aws_route_table_association" "gwlb_subnet_rt_az1" {
  subnet_id      = aws_subnet.gwlb_subnet.*.id[0]
  route_table_id = aws_route_table.gwlb_subnet_az1.id
}



resource "aws_route_table" "gwlb_subnet_az2" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = aws_vpc.spoke_vpc.cidr_block
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.*.id[1]
  }
  tags = {
    "Name" = "gwlb_subnet_rtb_az2"
  }
}

resource "aws_route_table_association" "gwlb_subnet_rt_az2" {
  subnet_id      = aws_subnet.gwlb_subnet.*.id[1]
  route_table_id = aws_route_table.gwlb_subnet_az2.id
}


#### NAT GATEWAY  Subnet Routes - Inspection VPC ####

resource "aws_route_table" "ngw_subnet" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    "Name" = "ngw_subnet_rtb"
  }
}

resource "aws_route" "r1" {
  route_table_id            = aws_route_table.ngw_subnet.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id
  depends_on                = [aws_route_table.ngw_subnet]
}

resource "aws_route" "r2" {
  count =   length(aws_subnet.app_subnet.*.id) 
  route_table_id            = aws_route_table.ngw_subnet.id
  destination_cidr_block    = sort(aws_subnet.app_subnet.*.cidr_block)[count.index]
  vpc_endpoint_id = aws_vpc_endpoint.gwlb_ep.*.id[count.index]
  depends_on                = [aws_route_table.ngw_subnet]
}


resource "aws_route_table_association" "ngw_subnet_rt" {
  count = length(aws_subnet.pavm_mgmt_subnet.*.id) 
  subnet_id      = aws_subnet.pavm_mgmt_subnet[count.index].id
  route_table_id = aws_route_table.ngw_subnet.id
}
