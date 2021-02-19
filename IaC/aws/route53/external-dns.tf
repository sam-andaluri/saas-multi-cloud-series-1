# Default our region
provider "aws" {
  region = "us-east-2"
}

variable "domain_name" {
   description = "domain name"
}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  lower   = true
  number  = false
  special = false
}

# IAM Policy to give external-dns pod to make changes in Route53
resource "aws_iam_policy" "external-dns-policy" {
  name = "K8sExternalDNSPolicy-${random_string.suffix.result}"
  description = "Allows EKS nodes to modify Route53 to support ExternalDNS."

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "route53:ChangeResourceRecordSets"
        ],
        "Resource": [
          "arn:aws:route53:::hostedzone/*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets"
        ],
        "Resource": [
          "*"
        ]
      }
    ]
}
EOF
}

# Lookup zone in Route53
data "aws_route53_zone" "zone" {
  name         = var.domain_name
  private_zone = false
}

# External DNS Template that substitute Route53 zone
data "template_file" "external-dns" {
  template = templatefile("${path.module}/external-dns.yaml", {zone-id = data.aws_route53_zone.zone.zone_id, suffix = random_string.suffix.result})
}

# Deploy external-dns template if there is a change
resource "null_resource" "depoly-if-changed" {
  triggers = {
    manifest_sha1 = sha1(data.template_file.external-dns.rendered)
  }

  provisioner "local-exec" {
    command = "kubectl apply -f -<<EOF\n${data.template_file.external-dns.rendered}\nEOF"
  }
}

#Test rendered output
output "template-out" {
  value = data.template_file.external-dns.rendered
}

