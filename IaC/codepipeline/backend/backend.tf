module "tenant" {
  source        = "../"
  github_user   = "sam-andaluri"
  github_repo   = "saas-provider-backend"
  github_branch = "master"
  github_token  = "1ff971d0dc076f4d74c2ad6692eee0e756ca1002"
  ecr_repo      = "saas-provider-backend"
  account_id    = "427398298435"
  region        = "us-east-2"
}
