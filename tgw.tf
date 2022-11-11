resource "aws_ec2_transit_gateway" "tgw" {
  description                     = "Transit Gateway FOR CENTRALIZED EGRESS"
  amazon_side_asn                 = "64526"
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"
  tags = {
    "Name" = "tgw_inspection_vpc"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "inspection" {
  subnet_ids             = [for subnet in aws_subnet.tgw_attach_subnet : subnet.id]
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
  vpc_id                 = aws_vpc.vpc.id
  appliance_mode_support = "enable"
  tags = {
    "Name" = "inspection_attach"
  }
}


resource "aws_ec2_transit_gateway_vpc_attachment" "spoke" {
  subnet_ids         = [for subnet in aws_subnet.app_tgw_subnet : subnet.id]
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.spoke_vpc.id
  tags = {
    "Name" = "spoke_attach"
  }
}
