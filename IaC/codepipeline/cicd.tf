provider "aws" {
  region = var.region
}

terraform {
  required_version = "~> 0.12"
}

# Random string to add to S3 bucket name to make it unique
resource "random_string" "suffix" {
  length  = 5
  upper   = false
  lower   = true
  number  = false
  special = false
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# MANUAL step: Create ECR repository as this is one time setup.
# data "aws_ecr_repository" "current" {
#   name = "saas-react-app"
# }

# MANUAL step: Store the github token in SSM Parameter store as this is one time setup.

# data "aws_ssm_parameter" "current" {
#   name = "manning-saas-multi-cloud-react-app-build"
# }


# A shared secret between GitHub and AWS that allows AWS
# CodePipeline to authenticate the request came from GitHub.
locals {
  webhook_secret = var.github_token
}

# AWS CodePipeLine to download source and build
resource "aws_codepipeline" "codepipeline" {
  name     = "saas-app-pipeline"
  
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
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.saas-app-image-build.name
      }
    }
  }
}

# This is not used but is required for code pipleline
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "${var.github_repo}-${random_string.suffix.result}"
  acl    = "private"
}

# Merged IAM Role for CodePipeLine and CodeBuild 
resource "aws_iam_role" "codepipeline_role" {
  name = "saas-app-codepipeline_role"

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
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Merged IAM Role policy for CodePipeLine and CodeBuild
resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "saas-app-codepipeline_policy"
  role = aws_iam_role.codepipeline_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.codepipeline_bucket.arn}",
        "${aws_s3_bucket.codepipeline_bucket.arn}/*"
      ]
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
        "eks:DescribeCluster",
        "eks:ListClusters",
        "codecommit:CancelUploadArchive",
        "codecommit:GetBranch",
        "codecommit:GetCommit",
        "codecommit:GetUploadArchiveStatus",
        "codecommit:UploadArchive",
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
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

# CodeBuild project to build source. buildspec.yml is includes in source.
resource "aws_codebuild_project" "saas-app-image-build" {
  name          = "saas-app-image-build"
  description   = "Terraform SaaS React App Image Build"
  service_role  = aws_iam_role.codepipeline_role.id

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
  }

  source {
    type            = "CODEPIPELINE"
    buildspec       = "buildspec.yml"
  }

}

# resource "aws_codepipeline_webhook" "saas-app-pipeline-hook" {
#   name            = "saas-app-pipeline-hook"
#   authentication  = "GITHUB_HMAC"
#   target_action   = "Source"
#   target_pipeline = aws_codepipeline.codepipeline.name

#   authentication_configuration {
#     secret_token = local.webhook_secret
#   }

#   filter {
#     json_path    = "$.ref"
#     match_equals = "refs/heads/{Branch}"
#   }
# }

# # Wire the CodePipeline webhook into a GitHub repository.
# resource "github_repository_webhook" "saas-app-github-hook" {
#   repository = var.github_repo

#   configuration {
#     url          = aws_codepipeline_webhook.saas-app-pipeline-hook.url
#     content_type = "json"
#     insecure_ssl = true
#     secret       = local.webhook_secret
#   }

#   events = ["push"]
# }

