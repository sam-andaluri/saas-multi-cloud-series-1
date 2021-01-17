
data "aws_vpc" "saas-eks-vpc" {
  tags = {
    "Name" = "saas-eks-vpc"
  }
}

data "aws_vpc" "aws-vpc" {
  tags = {
    "Name" = "aws-vpc"
  }
}
data "aws_subnet_ids" "saas-eks-vpc-subnets" {
  vpc_id = data.aws_vpc.saas-eks-vpc.id
}

data "aws_subnet_ids" "aws-vpc-subnets" {
  vpc_id = data.aws_vpc.aws-vpc.id
}

data "aws_vpn_gateway" "aws-vpn-gw" {
  vpc_id = data.aws_vpc.aws-vpc.id
}

data "aws_route_table" "saas-eks-vpc-subnets-rtb" {
  subnet_id = data.aws_subnet_ids.saas-eks-vpc-subnets.id
}

data "aws_route_table" "aws-vpc-subnets-rtb" {
  subnet_id = data.aws_subnet_ids.aws-vpc-subnets.id
}

data "google_compute_subnetwork" "google-subnet" {
  name   = "gcp-subnet1"
  region = "us-east1"
}

resource "aws_ec2_transit_gateway" "multi-cloud-tgw" {
  description = "Transit Gateway for sharing GCP to AWS VPN with VPCs"
  auto_accept_shared_attachments = enable
  default_route_table_association = disable
  default_route_table_propagation = disable
}

resource "aws_ec2_transit_gateway_vpc_attachment" "saas-eks-vpc" {
  subnet_ids         = data.aws_subnet_ids.saas-eks-vpc-subnets.ids
  transit_gateway_id = aws_ec2_transit_gateway.multi-cloud-tgw.id
  vpc_id             = data.aws_vpc.saas-eks-vpc.id
}

resource "aws_ec2_transit_gateway_vpc_attachment" "aws-vpc" {
  subnet_ids         = data.aws_subnet_ids.aws-vpc-subnets.ids
  transit_gateway_id = aws_ec2_transit_gateway.multi-cloud-tgw.id
  vpc_id             = data.aws_vpc.aws-vpc.id
}

resource "aws_ec2_transit_gateway_route_table" "for_vpc" {
  transit_gateway_id = aws_ec2_transit_gateway.multi-cloud-tgw
}

resource "aws_ec2_transit_gateway_route_table" "for_vpn" {
  transit_gateway_id = aws_ec2_transit_gateway.multi-cloud-tgw
}

resource "aws_ec2_transit_gateway_route_table_association" "saas-eks-vpc_association" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.saas-eks-vpc.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.for_vpc.id
}

resource "aws_ec2_transit_gateway_route_table_association" "aws-vpc_association" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.aws-vpc.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.for_vpc.id
}

resource "aws_ec2_transit_gateway_route_table_association" "aws-vpn-gw_association" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.aws-vpc.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.for_vpn.id
}
resource "aws_ec2_transit_gateway_route_table_propagation" "saas-eks-vpc_propagation" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.saas-eks-vpc.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.for_vpc.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "aws-vpc_propagation" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.aws-vpc.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.for_vpc.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "aws-vpn-gw_propagation" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.aws-vpc.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.for_vpn.id
}

resource "aws_route" "saas-eks-vpc_to_google" {
  route_table_id            = data.aws_route_table.saas-eks-vpc-subnets-rtb.id
  destination_cidr_block    = data.google_compute_subnetwork.google-subnet.ip_cidr_range
  transit_gateway_id = aws_ec2_transit_gateway.multi-cloud-tgw.id
}

resource "aws_route" "aws-vpc_to_google" {
  route_table_id            = data.aws_subnet_ids.aws-vpc-subnets-rtb.id
  destination_cidr_block    = data.google_compute_subnetwork.google-subnet.ip_cidr_range
  transit_gateway_id = aws_ec2_transit_gateway.multi-cloud-tgw.id
}
