# https://cloud.google.com/compute/docs/load-balancing/http/content-based-example

provider "google" {
  project = "terraform-test-project-278704"
  region  = "us-central1"
  zone    = "us-central1-c"
}

# remote state file for aws containing tunnel 1 and
# tunnel 2 aws vpn addresses needed for the gcp
# tunnel configuration
#---------------------------------------------
data "terraform_remote_state" "aws_data" {
  backend = "local"
  config = {
    path = "/home/a.kocheva/Terraform/aws-gcp-vpn-infrastructure/aws-vpn/terraform.tfstate"
  }
}

# Get the static ip address reserved on gcp console
# to be used for the gcp vpn gateway
data "google_compute_address" "aws-tf-test" {
  name = "vpn-amazon"
}

# Create VPC
#--------------------------------------
resource "google_compute_network" "vpc_tf" {
  name                    = "aws-network"
  auto_create_subnetworks = "false"
}

# Create Subnet
#--------------------------------------
resource "google_compute_subnetwork" "subnet_vpn_tf" {
  name          = "subnet-for-vpn"
  ip_cidr_range = var.vpn_subnet
  network       = google_compute_network.vpc_tf.self_link
}

#Create the instances
#------------------------
resource "google_compute_instance" "vpn_access" {
  name         = "tf-vpn-access"
  machine_type = "f1-micro"
  tags         = ["bastion-tag"]

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-9"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet_vpn_tf.name

    access_config {
      // Ephemeral IP
    }
  }

  metadata = {
    ssh-keys = "kayode:${file("${var.public_key_path}")}"
  }

  service_account {
    scopes = ["https://www.googleapis.com/auth/compute.readonly"]
  }
}

#resource "google_compute_health_check" "health-check" {
#  name = "tf-health-check"

#  http_health_check {}
#}

# FW rule to allow ICMP access from bastion to all vpc instances
# FW rule uses service accounts for rule target
resource "google_compute_firewall" "allow_icmp" {
  name    = "allow-icmp-only"
  network = google_compute_network.vpc_tf.self_link

  allow {
    protocol = "icmp"
    //ports    = ["22"]
  }
}

# FW rule to allow external SSH access into bastion network
resource "google_compute_firewall" "allow_external_ssh" {
  name    = "allow-external-ssh"
  network = google_compute_network.vpc_tf.self_link

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["bastion-tag"]
}


#VPN CONFIGURATION
#===================================

# Attach a VPN gateway to the VPC.
resource "google_compute_vpn_gateway" "target_gateway_tf" {
  name    = "vpn-tf-gateway"
  network = google_compute_network.vpc_tf.self_link
}

# Forward IPSec traffic coming into our static IP to our VPN gateway.
resource "google_compute_forwarding_rule" "fr_esp" {
  name        = "fr-esp"
  ip_protocol = "ESP"
  ip_address  = data.google_compute_address.aws-tf-test.address
  target      = google_compute_vpn_gateway.target_gateway_tf.self_link
  #  network_tier          = "STANDARD"
}

# The following two sets of forwarding rules are used as a part of the IPSec
# protocol
resource "google_compute_forwarding_rule" "fr_udp500" {
  name        = "fr-udp500"
  ip_protocol = "UDP"
  port_range  = "500"
  ip_address  = data.google_compute_address.aws-tf-test.address
  target      = google_compute_vpn_gateway.target_gateway_tf.self_link
  #  network_tier          = "STANDARD"
}

resource "google_compute_forwarding_rule" "fr_udp4500" {
  name        = "fr-udp4500"
  ip_protocol = "UDP"
  port_range  = "4500"
  ip_address  = data.google_compute_address.aws-tf-test.address
  target      = google_compute_vpn_gateway.target_gateway_tf.self_link
  #  network_tier          = "STANDARD"
}

# Each tunnel is responsible for encrypting and decrypting traffic exiting
# and leaving its associated gateway
# We will create 2 tunnels to aws on same GCP VPN gateway
resource "google_compute_vpn_tunnel" "tunnel1" {
  name               = "aws-tunnel1"
  peer_ip            = data.terraform_remote_state.aws_data.outputs.vpn_connection_tunnel1_address
  ike_version        = "1"
  shared_secret      = var.preshared_key
  target_vpn_gateway = google_compute_vpn_gateway.target_gateway_tf.self_link
  local_traffic_selector = [
    google_compute_subnetwork.subnet_vpn_tf.ip_cidr_range
  ]
  remote_traffic_selector = [
    var.remote_cidr
  ]

  depends_on = [google_compute_forwarding_rule.fr_udp500,
    google_compute_forwarding_rule.fr_udp4500,
    google_compute_forwarding_rule.fr_esp,
  ]
}

resource "google_compute_vpn_tunnel" "tunnel2" {
  name               = "aws-tunnel2"
  peer_ip            = data.terraform_remote_state.aws_data.outputs.vpn_connection_tunnel2_address
  ike_version        = "1"
  shared_secret      = var.preshared_key
  target_vpn_gateway = google_compute_vpn_gateway.target_gateway_tf.self_link

  local_traffic_selector = [
    google_compute_subnetwork.subnet_vpn_tf.ip_cidr_range
  ]
  remote_traffic_selector = [
    var.remote_cidr
  ]

  depends_on = [google_compute_forwarding_rule.fr_udp500,
    google_compute_forwarding_rule.fr_udp4500,
    google_compute_forwarding_rule.fr_esp,
  ]
}


resource "google_compute_route" "route_tunnel1" {
  name                = "vpn-tunnel1-route"
  dest_range          = var.remote_cidr
  network             = google_compute_network.vpc_tf.name
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.tunnel1.self_link
  priority            = 1000
}

resource "google_compute_route" "route_tunnel2" {
  name                = "vpn-tunnel2-route"
  dest_range          = var.remote_cidr
  network             = google_compute_network.vpc_tf.name
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.tunnel2.self_link
  priority            = 1000
}