
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
