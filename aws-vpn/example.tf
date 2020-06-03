provider "aws" {
  profile = "default"
  region  = "us-east-2"
}

# Create a VPC to launch our instances into
resource "aws_vpc" "vpc-tf" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  tags = {
    Name = "${var.name}-demo"
  }
}

# Create a private subnet
resource "aws_subnet" "private-ft" {
  vpc_id            = aws_vpc.vpc-tf.id
  cidr_block        = var.private_subnet
  availability_zone = var.zone
  tags = {
    Name = "${var.name}-private-subnet"
  }
}

# Create an internet gateway to give our subnets access to the outside world
resource "aws_internet_gateway" "vpc-igw-tf" {
  vpc_id = aws_vpc.vpc-tf.id
  tags = {
    Name = "${var.name}-igw"
  }
}

# Grant the VPC internet access on its main route table
resource "aws_route" "igw-route-tf" {
  route_table_id         = aws_vpc.vpc-tf.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.vpc-igw-tf.id
}

# Create a VPN Gateway
resource "aws_vpn_gateway" "vpc-vgw-tf" {
  vpc_id = aws_vpc.vpc-tf.id
  tags = {
    Name = "${var.name}-vgw"
  }
}

# Grant the VPC access to the VPN gateway on its main route table
resource "aws_route" "vgw-route-tf" {
  route_table_id         = aws_vpc.vpc-tf.main_route_table_id
  destination_cidr_block = var.vpn_dst_cidr_block
  gateway_id             = aws_vpn_gateway.vpc-vgw-tf.id
}

# Create the remote customer gateway profile
resource "aws_customer_gateway" "vpc-cgw-tf" {
  bgp_asn    = var.vpn_bgp_asn
  ip_address = var.vpn_ip_address
  type       = "ipsec.1"
  tags = {
    Name = "${var.name}-cgw"
  }
}

# Create the VPN tunnel to customer gateway
resource "aws_vpn_connection" "vpc-vpn-tf" {
  vpn_gateway_id        = aws_vpn_gateway.vpc-vgw-tf.id
  customer_gateway_id   = aws_customer_gateway.vpc-cgw-tf.id
  type                  = "ipsec.1"
  static_routes_only    = true
  tunnel1_preshared_key = var.preshared_key
  tunnel2_preshared_key = var.preshared_key
  tags = {
    Name = "${var.name}-vpn"
  }
}

# define a static route between a VPN connection and a customer gateway
# create a route to GCP test subnet
resource "aws_vpn_connection_route" "gcp_route_test" {
  #  destination_cidr_block = "172.16.1.0/24"
  destination_cidr_block = var.vpn_dst_cidr_block
  vpn_connection_id      = aws_vpn_connection.vpc-vpn-tf.id
}

# Our default security group to access
# the instances over SSH and ICMP
resource "aws_security_group" "default" {
  name   = "vpn_ft_security_group"
  vpc_id = aws_vpc.vpc-tf.id

  # ICMP access from remote GCP loadbalancer subnet
  # containing web server frontends
  ingress {
    from_port = 8
    to_port   = 0
    protocol  = "icmp"
    #    cidr_blocks = ["${var.gcp_bastion_cidr}"]
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port         = 0
    to_port           = 0
    protocol          = "-1"
    cidr_blocks       = [ var.cidr_block,
                          var.vpn_dst_cidr_block
                          ]
  }

  egress {
    from_port         = 0
    to_port           = 0
    protocol          = "-1"
    cidr_blocks       = ["0.0.0.0/0"]
  }

}

resource "aws_security_group" "allow_ssh" {
  name   = "vpn_ft_ssh_security_group"
  vpc_id = aws_vpc.vpc-tf.id

  # ICMP access from remote GCP loadbalancer subnet
  # containing web server frontends
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }



}

# Create the instance
resource "aws_instance" "welcome_to_google" {
  instance_type = "t2.micro"

  # Lookup the correct AMI based on the region
  # we specified
  #  ami = lookup(var.amis, var.region)

  ami = "ami-083ebc5a49573896a"

  # The name of our SSH keypair you've created and downloaded
  # from the AWS console.
  # https://console.aws.amazon.com/ec2/v2/home?region=eu-west-1#KeyPairs:
  key_name = var.key_name

  associate_public_ip_address = true

  # Our Security group to allow SSH and ICMP access
  vpc_security_group_ids = ["${aws_security_group.default.id}", "${aws_security_group.allow_ssh.id}"]
  subnet_id              = aws_subnet.private-ft.id

  #Instance tags
  tags = {
    Name = "${var.name}-instance"
  }
}

