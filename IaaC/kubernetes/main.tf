module "dev_cluster" {
  source = "./cluster"

  cluster_name = "dev-saas"
}

# module "staging_cluster" {
#   source = "./cluster"

#   cluster_name = "staging-saas"
# }

# module "production_cluster" {
#   source = "./cluster"

#   cluster_name = "production-saas"
# }
