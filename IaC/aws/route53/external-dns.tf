# Default our region
provider "aws" {
  region = "us-east-2"
}

# IAM Policy to give external-dns pod to make changes in Route53
resource "aws_iam_policy" "external-dns-policy" {
  name = "K8sExternalDNSPolicy"
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
data "aws_route53_zone" "saas-tenant" {
  name         = "saas-tenant.cloud."
  private_zone = false
}

# External DNS Template that substitute tenant Route53 zone
data "template_file" "external-dns" {
  template = templatefile("${path.module}/external-dns.yaml", {tenant-zone-id = data.aws_route53_zone.saas-tenant.zone_id})
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

