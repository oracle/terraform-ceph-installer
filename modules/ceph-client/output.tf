
output "ip" {
  value = "${oci_core_instance.instance.*.public_ip}"
}

output "hostname" {
  value = "${oci_core_instance.instance.*.hostname_label}"
}
