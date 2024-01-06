provider "google" {
  credentials = "/home/devops/.config/gcloud/application_default_credentials.json"
  project     = "mapbu-partner-apj"
  region      = "us-west1"
}

resource "google_compute_network" "vpc_network" {
  project                 = "mapbu-partner-apj"
  name                    = "vpc-network"
  mtu                     = 8896
  description             = "testing gcp vpc creation"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  network_firewall_policy_enforcement_order = "AFTER_CLASSIC_FIREWALL"
  delete_default_routes_on_create = false
  
}
