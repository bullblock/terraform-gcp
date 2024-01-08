provider "google" {
  credentials = "/home/devops/.config/gcloud/application_default_credentials.json"
  project     = "${var.project-id}"
  region      = "${var.region-id}"
}

resource "google_compute_network" "vpc_network" {
  name                    = "${var.project-name}-vpc"
  mtu                     = 8896
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  network_firewall_policy_enforcement_order = "AFTER_CLASSIC_FIREWALL"
  delete_default_routes_on_create = false
}

resource "google_compute_subnetwork" "public-subnet" {
  name                     = "${var.project-name}-subnet-public"
  ip_cidr_range            = "${var.public-ip-range}"
  network                  = google_compute_network.vpc_network.id
  description              = "${var.project-name} public subnet"
  purpose                  = "PRIVATE_RFC_1918"
  private_ip_google_access = true
  stack_type               = "IPV4_ONLY"
}

resource "google_compute_subnetwork" "private-subnet" {
  name                     = "${var.project-name}-subnet-private"
  ip_cidr_range            = "${var.private-ip-range}"
  network                  = google_compute_network.vpc_network.id
  description              = "${var.project-name} private subnet"
  purpose                  = "PRIVATE_RFC_1918"
  private_ip_google_access = true
  stack_type               = "IPV4_ONLY"
}

resource "google_compute_subnetwork" "service-subnet" {
  name                     = "${var.project-name}-subnet-service"
  ip_cidr_range            = "${var.service-ip-range}"
  network                  = google_compute_network.vpc_network.id
  description              = "${var.project-name} service subnet"
  purpose                  = "PRIVATE_RFC_1918"
  private_ip_google_access = true
  stack_type               = "IPV4_ONLY"
}

resource "google_compute_router" "cloud-router" {
  name                     = "${var.project-name}-cloud-router"
  network                  = google_compute_network.vpc_network.id
  description              = "${var.project-name} cloud router for internet access"
}

resource "google_compute_address" "cloud-nat-ip" {
  name                     = "${var.project-name}-cloud-nat-ip"
  address_type             = "EXTERNAL"
  description              = "${var.project-name} cloud nat ip address"
  network_tier             = "PREMIUM"
  ip_version               = "IPV4"
  region                   = "${var.region-id}"
}

resource "google_compute_router_nat" "cloud-nat" {
  name                               = "${var.project-name}-cloud-nat"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  router                             = google_compute_router.cloud-router.name
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = google_compute_address.cloud-nat-ip.*.self_link
  log_config {
    enable                           = true
    filter                           = "ERRORS_ONLY"
  }
  subnetwork {
    name                             = google_compute_subnetwork.private-subnet.id
    source_ip_ranges_to_nat          = ["PRIMARY_IP_RANGE"]
  }
  subnetwork {
    name                             = google_compute_subnetwork.service-subnet.id
    source_ip_ranges_to_nat          = ["PRIMARY_IP_RANGE"]
  }
}

resource "google_compute_firewall" "firewall-default-icmp" {
  name                               = "${var.project-name}-firewall-default-icmp"
  network                            = google_compute_network.vpc_network.name
  allow {
    protocol                         = "icmp"
  }
  source_ranges                      = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "firewall-default-all" {
  name                               = "${var.project-name}-firewall-default-all"
  network                            = google_compute_network.vpc_network.name
  allow {
    protocol                         = "all"
  }
  source_ranges                    = ["${var.public-ip-range}", "${var.private-ip-range}", "${var.service-ip-range}"]
}

resource "google_compute_firewall" "firewall-default-ssh" {
  name                               = "${var.project-name}-firewall-default-ssh"
  network                            = google_compute_network.vpc_network.name
  allow {
    protocol                         = "tcp"
    ports                            = ["22"]
  }
  source_ranges                      = ["0.0.0.0/0"]
  target_tags                        = ["ssh"]
}

resource "google_compute_firewall" "firewall-default-rdp" {
  name                               = "${var.project-name}-firewall-default-rdp"
  network                            = google_compute_network.vpc_network.name
  allow {
    protocol                         = "tcp"
    ports                            = ["3389"]
  }
    source_ranges                    = ["0.0.0.0/0"]
    target_tags                      = ["rdp"]
}

resource "google_compute_address" "bastion-compute-address" {
  name                               = "${var.project-name}-bastion-ip"
  address_type                       = "EXTERNAL"
  description                        = "external ip address to ${var.project-name}-bastion compute instance"
  network_tier                       = "PREMIUM"
  ip_version                         = "IPV4"
  region                             = "${var.region-id}"
}

resource "google_compute_instance" "bastion" {
  name                               = "${var.project-name}-bastion"
  description                        = "compute instance to ${var.project-name}-bastion"
  zone                               = "${var.region-id}-b"
  machine_type                       = "n2-standard-2"
  allow_stopping_for_update          = true
  desired_status                     = "RUNNING"
  deletion_protection                = false
  tags                               = ["ssh"]
  
  network_interface {
    subnetwork                       = google_compute_subnetwork.public-subnet.name
    nic_type                         = "GVNIC"
    stack_type                       = "IPV4_ONLY"
    access_config {
      nat_ip                         = google_compute_address.bastion-compute-address.address
      network_tier                   = "PREMIUM"
    }
  }
  boot_disk {
    auto_delete                      = true
    device_name                      = "${var.project-name}-bastion-boot"
    initialize_params {
      type                           = "pd-ssd"
      size                           = 128
      image                          = "ubuntu-2204-lts"
    }
  }
  metadata = {
    ssh-keys = "devops: ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDD7H05c/eqWptyyhtyg29WacBW24L9faNM2MGlYVnwD68f9KD1OUyYVXpQMMCxvCXcRjcoddzR8CCEUpkpWeT1arzX6sioE6HJCDBKYCY5lMB+6JfOCBNRLwXJHmMGbOEdaDASwW2GKHntUDEQR0KM6/MBc+OXvpIs6mhYnHfCXRns/ubYhpZQQwf3kO+llJjnjfokQ96bzZ/hs7juAni04+1Rs5L7qK/gT3BWNrULHs4oPI1FOCEwHS8K0bKc763sPmYlVGiLus48vmNM/u//QoE732m1zZ7nHngFm28WE89b/HphpxhnpMH4JzQ4zmRnRIgefZhz6i0I1s12QOqD"
    startup-script = <<-EOF
timedatectl set-timezone Asia/Singapore
timedatectl set-ntp true
apt update
apt upgrade -y
apt autoremove --purge -y
reboot
EOF
  }
}

variable "project-id" {
  type = string
  description = "GCP project name"
  default = "mapbu-partner-apj"
}

variable "region-id" {
  type = string
  description = "GCP region, you may check by gcloud compute regions list"
  default = "us-west1"
}

variable "project-name" {
  type = string
  description = "the prefix name to be added to all variables"
  default = "project"
}

variable "public-ip-range" {
  type = string
  description = "ip range to public subnet"
  default = "10.65.1.0/24"
}

variable "private-ip-range" {
  type = string
  description = "ip range to private subnet"
  default = "10.65.2.0/24"
}

variable "service-ip-range" {
  type = string
  description = "ip range to service subnet"
  default = "10.65.3.0/24"
}
