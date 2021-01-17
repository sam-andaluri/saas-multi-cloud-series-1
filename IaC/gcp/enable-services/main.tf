module "project-services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "4.0.0"

  project_id  = "sam-manning-s1-p2p3"

  activate_apis = [
      "networkservices.googleapis.com",
      "vpcaccess.googleapis.com",
      "cloudresourcemanager.googleapis.com",
      "container.googleapis.com",
      "gkehub.googleapis.com",
      "gkeconnect.googleapis.com",
      "logging.googleapis.com",
      "monitoring.googleapis.com",
      "serviceusage.googleapis.com",
      "stackdriver.googleapis.com",
      "storage-api.googleapis.com",
      "storage-component.googleapis.com"
  ]
}