# Default our region
provider "aws" {
  region = "us-east-2"
}

variable "domain_name" {
   description = "domain name"
}

data "aws_iam_policy_document" "eks_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      identifiers = ["eks.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "external_dns" {
  name        = "eks-external-dns"
  description = "Permissions required by the Kubernetes AWS EKS External Name controller to do it's job."
  path        = "/"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json
}

data "aws_iam_policy_document" "external_dns" {
  statement {
    actions = [
      "route53:ChangeResourceRecordSets",
    ]

    resources = ["arn:aws:route53:::hostedzone/*"]
  }
  statement {
    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "external_dns" {
  name        = "external_dns"
  description = "Allows access to resources needed to run external dns."
  policy      = data.aws_iam_policy_document.external_dns.json
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  role       = aws_iam_role.external_dns.name
  policy_arn = aws_iam_policy.external_dns.arn
}

# Lookup zone in Route53
data "aws_route53_zone" "zone" {
  name         = var.domain_name
  private_zone = false
}

# External DNS Template that substitute Route53 zone
data "template_file" "external-dns" {
  template = templatefile("${path.module}/external-dns.yaml", {zone-id = data.aws_route53_zone.zone.zone_id, role-arn = aws_iam_role.external_dns.arn})
}

# Deploy external-dns template 
resource "null_resource" "deploy" {
  provisioner "local-exec" {
    command = "kubectl apply -f -<<EOF\n${data.template_file.external-dns.rendered}\nEOF"
  }
}

#Test rendered output
output "template-out" {
  value = data.template_file.external-dns.rendered
}

