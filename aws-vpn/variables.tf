variable "name" {
  description = "The name of the VPC."
  default     = "IPsec"
}

variable "region" {
  description = "aws region"
  default     = "us-east-2"
}

variable "cidr_block" {
  description = "The CIDR block for the VPC."
  default     = "10.82.0.0/16"
}

variable "key_name" {
  default = "Terraform-key"
}

variable "vpn_ip_address" {
  description = "Internet-routable IP address of the customer gateway's external interface."
  default     = "34.72.33.99"
}

variable "vpn_bgp_asn" {
  description = "BPG Autonomous System Number (ASN) of the customer gateway for a dynamically routed VPN connection."
  default     = "65000"
}

variable "vpn_dst_cidr_block" {
  description = "Internal network IP range to advertise over the VPN connection to the VPC."
  default     = "10.60.0.0/16"
}

variable "private_subnet" {
  description = "CIDR block to use as private subnet; instances launced will NOT be assigned a public IP address."
  default     = "10.82.0.0/24"
}

variable "zone" {
  description = "availability zone to use."
  default     = "us-east-2a"
}

variable "preshared_key" {
  description = "preshaed key used for tunnels 1 and 2"
  default     = "_KHa1y6KB8MJq7EeCjajt6o51XdEwuzU"
}

variable "amis" {
  description = "Terraform-key"
  default = {
    "eu-east-2" = "ami-083ebc5a49573896a"
  }
}