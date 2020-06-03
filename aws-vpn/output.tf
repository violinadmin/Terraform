output "vpn_connection_tunnel1_address" {
  value = "${aws_vpn_connection.vpc-vpn-tf.tunnel1_address}"
}

output "vpn_connection_tunnel2_address" {
  value = "${aws_vpn_connection.vpc-vpn-tf.tunnel2_address}"
}
