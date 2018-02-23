
output "ip_list" { 
  value = "${oci_core_instance.instances.*.public_ip}"
} 

output "hostname_list" {
  value = "${oci_core_instance.instances.*.hostname_label}"
} 

output "add_disk" {
  value = "${null_resource.add_disk.0.id}"
}
