# --- Region ---
# AWS Region
provider "aws" {
  region = "us-east-2"
}

# --- VPC ---
# Create a new VPC for EKS cluster with IGW
# IGW is enabled by default

data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.64.0"

  name                 = "saas-eks-vpc"
  cidr                 = "10.1.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  public_subnets       = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/saas-eks" = "shared"
    "kubernetes.io/role/elb"         = "1"
  }

  tags = {
    "Name" = "saas-eks-vpc"
  }
}

# --- Cluster ---
# IAM Roles for Cluster
resource "aws_iam_role" "eks-cluster-role" {
  name = "eks-cluster-role"

assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks-cluster-role-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-cluster-role.name
}

resource "aws_iam_role_policy_attachment" "eks-cluster-role-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks-cluster-role.name
}

# EKS Cluster
resource "aws_eks_cluster" "saas-eks" {
  name     = "saas-eks"
  role_arn = aws_iam_role.eks-cluster-role.arn

  vpc_config {
    subnet_ids = module.vpc.public_subnets
    endpoint_public_access  = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks-cluster-role-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks-cluster-role-AmazonEKSServicePolicy,
    aws_cloudwatch_log_group.saas-eks-cw-log-group
  ]

  timeouts {
    create = "60m"
    delete = "60m"
  }

  enabled_cluster_log_types = ["api", "audit"]
}

# CloudWatch logs for cluster
resource "aws_cloudwatch_log_group" "saas-eks-cw-log-group" {
  name              = "/aws/eks/saas-eks/cluster"
  retention_in_days = 7
}

# --- Nodes ---
# IAM Roles for Nodes
resource "aws_iam_role" "saas-eks-node-role" {
  name = "saas-eks-node-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "saas-eks-node-role-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.saas-eks-node-role.name
}

resource "aws_iam_role_policy_attachment" "saas-eks-node-role-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.saas-eks-node-role.name
}

resource "aws_iam_role_policy_attachment" "saas-eks-node-role-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.saas-eks-node-role.name
}

resource "aws_iam_role_policy_attachment" "saas-eks-node-role-AmazonEC2FullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
  role       = aws_iam_role.saas-eks-node-role.name
}

# EKS Node Group
resource "aws_eks_node_group" "saas-eks-node" {
  cluster_name    = aws_eks_cluster.saas-eks.name
  node_group_name = "saas-eks-nodes"
  node_role_arn   = aws_iam_role.saas-eks-node-role.arn
  subnet_ids      = module.vpc.public_subnets
  
  remote_access {
      ec2_ssh_key = "doit1"
  }
  instance_types = ["t3.large"]
  scaling_config {
    desired_size = 6
    max_size     = 7
    min_size     = 1
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.saas-eks-node-role-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.saas-eks-node-role-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.saas-eks-node-role-AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.saas-eks-node-role-AmazonEC2FullAccess
  ]
}

# Outputs
output "endpoint" {
  value = aws_eks_cluster.saas-eks.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.saas-eks.certificate_authority[0].data
}


