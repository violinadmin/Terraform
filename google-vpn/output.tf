output "application_public_ip" {
  value = "${data.google_compute_address.aws-tf-test.address}"
}