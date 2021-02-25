# Default our region
provider "aws" {
  region = "us-east-2"
}

variable "k8s_namespace" {
  description = "Kubernetes namespace to deploy the AWS External DNS into."
  type        = string
  default     = "kube-system"
}

variable "k8s_replicas" {
  description = "Amount of replicas to be created."
  type        = number
  default     = 1
}

variable "k8s_pod_labels" {
  description = "Additional labels to be added to the Pods."
  type        = map(string)
  default     = {}
}

variable "domain" {
  description = "Domain name"
  type        = string
}

variable "external_dns_version" {
  description = "The AWS External DNS version to use. See https://github.com/kubernetes-sigs/external-dns/releases for available versions"
  type        = string
  default     = "0.7.6"
}

variable "k8s_cluster_type" {
  description = "K8s cluster Type"
  type        = string
  default     = "eks"
}

variable "k8s_cluster_name" {
  description = "Current Cluster Name"
  type        = string
}

locals {
  external_dns_docker_image = "k8s.gcr.io/external-dns/external-dns:v${var.external_dns_version}"
  external_dns_version      = var.external_dns_version
}

data "aws_caller_identity" "current" {}

data "aws_route53_zone" "zone" {
  name         = var.domain
  private_zone = false
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

resource "kubernetes_service_account" "this" {
  automount_service_account_token = true
  metadata {
    name      = "external-dns"
    namespace = var.k8s_namespace
    labels = {
      "app.kubernetes.io/name"       = "external-dns"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "kubernetes_cluster_role" "this" {
  metadata {
    name = "external-dns"

    labels = {
      "app.kubernetes.io/name"       = "external-dns"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  rule {
    api_groups = [
      "",
    ]

    resources = [
      "endpoints",
    ]

    verbs = [
      "get",
      "list",
      "watch",
    ]
  }

  rule {
    api_groups = [
      "",
    ]

    resources = [
      "services",
    ]

    verbs = [
      "get",
      "list",
      "watch",
    ]
  }

  rule {
    api_groups = [
      "",
    ]

    resources = [
      "pods",
    ]

    verbs = [
      "get",
      "list",
      "watch",
    ]
  }
  rule {
    api_groups = [
      "extensions",
    ]

    resources = [
      "ingresses",
    ]

    verbs = [
      "get",
      "watch",
      "list",
    ]
  }
  rule {
    api_groups = [
      "",
    ]

    resources = [
      "nodes",
    ]

    verbs = [
      "list",
      "watch",
    ]
  }
}

resource "kubernetes_cluster_role_binding" "this" {
  metadata {
    name = "external-dns-viewer"

    labels = {
      "app.kubernetes.io/name"       = "external-dns"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.this.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.this.metadata[0].name
    namespace = kubernetes_service_account.this.metadata[0].namespace
  }
}

resource "kubernetes_deployment" "this" {
  depends_on = [kubernetes_cluster_role_binding.this]

  metadata {
    name      = "external-dns"
    namespace = var.k8s_namespace

    labels = {
      "app.kubernetes.io/name"       = "external-dns"
      "app.kubernetes.io/version"    = "v${local.external_dns_version}"
      "app.kubernetes.io/managed-by" = "terraform"
    }

    annotations = {
      "field.cattle.io/description" = "AWS External DNS"
    }
  }

  spec {

    replicas = var.k8s_replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "external-dns"
      }
    }

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = merge(
          {
            "app.kubernetes.io/name"    = "external-dns"
            "app.kubernetes.io/version" = local.external_dns_version
          },
          var.k8s_pod_labels
        )
      }

      spec {
        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              pod_affinity_term {
                label_selector {
                  match_expressions {
                    key      = "app.kubernetes.io/name"
                    operator = "In"
                    values   = ["external-dns"]
                  }
                }
                topology_key = "kubernetes.io/hostname"
              }
            }
          }
        }

        automount_service_account_token = true

        dns_policy = "ClusterFirst"

        restart_policy = "Always"

        container {
          name                     = "server"
          image                    = local.external_dns_docker_image
          image_pull_policy        = "Always"
          termination_message_path = "/dev/termination-log"

          args = [
            "--source=service",
            "--source=ingress",
            "--domain-filter=${var.domain}",
            "--provider=aws",
            "--policy=upsert-only",
            "--aws-zone-type=public",
            "--registry=txt",
            "--txt-owner-id=${data.aws_route53_zone.zone.zone_id}",
          ]
        }
        security_context {
          fs_group = 65534
        }

        service_account_name             = kubernetes_service_account.this.metadata[0].name
        termination_grace_period_seconds = 60
      }
    }
  }
}