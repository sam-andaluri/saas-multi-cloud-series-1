# Follow this to create certs
# https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/client-authentication.html#mutual
# Adopted from 
# https://craig-godden-payne.medium.com/setup-managed-client-vpn-in-aws-using-terraform-342584d4f1e3

provider "aws" {
  region = "us-east-2"
}

variable "vpc_id" {}
variable "client_cert_arn" {}
variable "server_cert_arn" {}
variable "client_cidr" {}
variable "subnet1" {}
variable "subnet2" {}

resource aws_route53_resolver_endpoint vpn_dns {
   name = "vpn-dns-access"
   direction = "INBOUND"
   security_group_ids = [aws_security_group.vpn_dns.id]
   ip_address {
     subnet_id = var.subnet1
   }
   ip_address {
     subnet_id = var.subnet2
   }
 }

resource "null_resource" "client_vpn_ingress" {
   depends_on = [aws_ec2_client_vpn_endpoint.vpn]
   provisioner "local-exec" {
     when    = create
     command = "aws ec2 authorize-client-vpn-ingress --client-vpn-endpoint-id ${aws_ec2_client_vpn_endpoint.vpn.id} --target-network-cidr 0.0.0.0/0 --authorize-all-groups"
   }
   lifecycle {
     create_before_destroy = true
   }
 }
 
 resource "null_resource" "client_vpn_security_group" {
   depends_on = [aws_ec2_client_vpn_endpoint.vpn]
   provisioner "local-exec" {
     when = create
     command = "aws ec2 apply-security-groups-to-client-vpn-target-network --client-vpn-endpoint-id ${aws_ec2_client_vpn_endpoint.vpn.id} --vpc-id ${aws_security_group.vpn_access.vpc_id} --security-group-ids ${aws_security_group.vpn_access.id}"
   }
   lifecycle {
     create_before_destroy = true
   }
 }

resource "aws_security_group" "vpn_access" {
   name = "shared-vpn-access"
   vpc_id = var.vpc_id
   ingress {
     from_port = 0
     protocol = "-1"
     to_port = 0
     cidr_blocks = ["0.0.0.0/0"]
   }
   egress {
     from_port = 0
     protocol = "-1"
     to_port = 0
     cidr_blocks = ["0.0.0.0/0"]
   }
 }
 
 resource "aws_security_group" "vpn_dns" {
   name = "vpn_dns"
   vpc_id = var.vpc_id
   ingress {
     from_port = 0
     protocol = "-1"
     to_port = 0
     security_groups = [aws_security_group.vpn_access.id]
   }
   egress {
     from_port = 0
     protocol = "-1"
     to_port = 0
     cidr_blocks = ["0.0.0.0/0"]
   }
 }

resource "aws_ec2_client_vpn_endpoint" "vpn" {
   client_cidr_block      = var.client_cidr
   split_tunnel           = false
   server_certificate_arn = var.server_cert_arn
   dns_servers = [
     aws_route53_resolver_endpoint.vpn_dns.ip_address.*.ip[0], 
     aws_route53_resolver_endpoint.vpn_dns.ip_address.*.ip[1]
   ]
   
   authentication_options {
     type                       = "certificate-authentication"
     root_certificate_chain_arn = var.client_cert_arn
   }
   
   connection_log_options {
     enabled = false
   }   
 }

 resource "aws_ec2_client_vpn_network_association" "subnet1" {
   client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id
   subnet_id              = var.subnet1
 }

  resource "aws_ec2_client_vpn_network_association" "subnet2" {
   client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn.id
   subnet_id              = var.subnet2
 }
