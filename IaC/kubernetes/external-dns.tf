resource "aws_iam_policy" "external-dns-policy" {
    name = "K8sExternalDNSPolicy"
    path = "/"
    description = "Allows EKS nodes to modify Route53 to support ExternalDNS."

    policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "route53:ListHostedZones",
                    "route53:ListResourceRecordSets"
                ],
                "Resource": ["*"]
            },
            {
                "Effect": "Allow",
                "Action": [
                    "route53:ChangeResourceRecordSets"
                ],
                "Resource": ["*"]
            }
        ]
    }
    EOF
}

data "template_file" "your_template" {
  template = "${file("${path.module}/templates/<.yaml>")}"
}

resource "null_resource" "your_deployment" {
  triggers = {
    manifest_sha1 = "${sha1("${data.template_file.your_template.rendered}")}"
  }

  provisioner "local-exec" {
    command = "kubectl create -f -<<EOF\n${data.template_file.your_template.rendered}\nEOF"
  }
}
