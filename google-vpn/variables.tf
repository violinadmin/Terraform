#variable "region" {
#  default = "europe-west2"
#}

#variable "region_zone" {
#  default = "europe-west2-a"
#}

#variable "project_name" {
#  description = "gcp-mtu-demo"
#}

#variable "credentials_file_path" {
#  description = "C://Users//salawu//SIM//ssh_keys//remote//dedes.pub"
#}

variable "public_key_path" {
  description = "Path to SSH public key to be attached to cloud instances"
  default     = "/home/a.kocheva/.aws/Terraform-key.pem"
}

#variable "source_service_accounts" {
#  description = "GCE service account"
#}

variable "preshared_key" {
  description = "preshaed key used for tunnels 1 and 2"
  default     = "_KHa1y6KB8MJq7EeCjajt6o51XdEwuzU"
}

variable "vpn_subnet" {
  description = "google subnet for vpn"
  default     = "10.60.1.0/24"
}

variable "remote_cidr" {
  description = "remote cidr ranges"
  default     = "10.82.0.0/16"
}
