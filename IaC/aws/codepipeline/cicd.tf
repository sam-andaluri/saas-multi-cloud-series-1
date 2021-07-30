# BEFORE applying this module:
# Create a secret with name docker, key-value pair of username: docker username, password: docker password
#
# AFTER applying this module, 
# 1. codepipeline fails as there is no github connection.
# https://docs.aws.amazon.com/codepipeline/latest/userguide/connections-github.html#connections-github-cli
# 
# 2. kubectl edit -n kube-system configmap/aws-auth
# Add the following where ROLE is the value of "${var.ecr_repo}_role"
#     - rolearn: arn:aws:iam::<AWS_ACCOUNT_ID>:role/<ROLE>
#      username: <ROLE>
#      groups:
#        - system:masters        
# 
variable "github_user" {
  default = "github-user"
}

variable "github_repo" {
  default = "github_repo"
}
variable "github_branch" {
  default = "master"
}
variable "github_token" {
  default = "12345"
}

variable "ecr_repo" {
  default = "ecr_repo"
}
variable "account_id" {
  default = "1234567890"
}

variable "region" {
  default = "us-east-2"
}

variable "eks_cluster_name" {
  default = "saas-eks"
}

provider "aws" {
  region = var.region
}

terraform {
  required_version = "~> 0.12"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# A shared secret between GitHub and AWS that allows AWS
# CodePipeline to authenticate the request came from GitHub.
locals {
  webhook_secret = var.github_token
}

# AWS CodePipeLine to download source and build
resource "aws_codepipeline" "codepipeline" {
  name = "${var.ecr_repo}-pipeline"

  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        Owner      = var.github_user
        Repo       = var.github_repo
        Branch     = var.github_branch
        OAuthToken = local.webhook_secret
      }
    }
  }

  stage {
    name = "Build"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source_output"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.saas-app-image-build.name
      }
    }
  }
}

# This is not used but is required for code pipleline
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket        = var.github_repo
  acl           = "private"
  force_destroy = true
}

# Merged IAM Role for CodePipeLine and CodeBuild 
resource "aws_iam_role" "codepipeline_role" {
  name = "${var.ecr_repo}_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "codebuild.amazonaws.com",
          "codepipeline.amazonaws.com"
        ],
        "AWS": "arn:aws:iam::${var.account_id}:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Merged IAM Role policy for CodePipeLine and CodeBuild
resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "${var.ecr_repo}_policy"
  role = aws_iam_role.codepipeline_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.codepipeline_bucket.arn}",
        "${aws_s3_bucket.codepipeline_bucket.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": ["sts:AssumeRole"],
      "Resource": "${aws_iam_role.codepipeline_role.arn}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "ec2:CreateNetworkInterface",
        "ec2:DescribeDhcpOptions",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeVpcs",
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages",
        "ecr:BatchGetImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage",
        "eks:Describe*",
        "eks:ListClusters",
        "codecommit:CancelUploadArchive",
        "codecommit:GetBranch",
        "codecommit:GetCommit",
        "codecommit:GetUploadArchiveStatus",
        "codecommit:UploadArchive",
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild",
        "ssm:GetParameterHistory",
        "ssm:GetParametersByPath",
        "ssm:GetParameters",
        "ssm:GetParameter",
        "ssm:DescribeParameters",
        "secretsmanager:*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterfacePermission"
      ],
      "Resource": [
        "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:network-interface/*"
      ],
      "Condition": {
        "StringEquals": {
          "ec2:AuthorizedService": "codebuild.amazonaws.com"
        }
      }
    }
  ]
}
EOF
}

data "aws_secretsmanager_secret_version" "docker_secrets" {
  secret_id = "docker"
}


# CodeBuild project to build source. buildspec.yml is includes in source.
resource "aws_codebuild_project" "saas-app-image-build" {
  name         = "${var.ecr_repo}-build"
  description  = "Terraform SaaS React App Image Build"
  service_role = aws_iam_role.codepipeline_role.id

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = var.ecr_repo
    }

    environment_variable {
      name  = "AWS_REGION"
      value = var.region
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.account_id
    }

    environment_variable {
      name  = "PIPELINE_ROLE_ARN"
      value = aws_iam_role.codepipeline_role.arn
    }

    environment_variable {
      name  = "EKS_CLUSTER_NAME"
      value = var.eks_cluster_name
    }
    
    environment_variable {
      name  = "docker_user"
      value = jsondecode(data.aws_secretsmanager_secret_version.docker_secrets.secret_string)["username"]
    }
    
    environment_variable {
      name  = "docker_password"
      value = jsondecode(data.aws_secretsmanager_secret_version.docker_secrets.secret_string)["password"]
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }

}

