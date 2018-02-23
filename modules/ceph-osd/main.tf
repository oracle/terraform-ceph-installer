
locals {
  output_filename = "/tmp/terraform.ceph-osd-exec.out"
}

#------------------------------------------------------------------------------------
# Get a list of Availability Domains
#------------------------------------------------------------------------------------
data "oci_identity_availability_domains" "ADs" {
  compartment_id = "${var.tenancy_ocid}"
}

#------------------------------------------------------------------------------------
# Get the OCID of the OS image to use
#------------------------------------------------------------------------------------
data "oci_core_images" "image_ocid" {
  compartment_id = "${var.compartment_ocid}"
  display_name = "${var.instance_os}"
}

#------------------------------------------------------------------------------------
# Create Ceph OSD Server Instances
#------------------------------------------------------------------------------------
resource "oci_core_instance" "instances" {
  count = "${var.instance_count}"
  availability_domain =  "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.availability_domain_index_list[count.index] - 1],"name")}"
  compartment_id = "${var.compartment_ocid}"
  display_name = "${var.hostname_prefix}-${count.index}"
  hostname_label = "${var.hostname_prefix}-${count.index}"
  image = "${lookup(data.oci_core_images.image_ocid.images[0], "id")}"
  shape = "${var.shape}"
  subnet_id = "${var.subnet_id_list[var.availability_domain_index_list[count.index] - 1]}"
  metadata {
    ssh_authorized_keys = "${file(var.ssh_public_key_file)}"
  }
  timeouts {
    create = "${var.instance_create_timeout}"
  }
}

#-----------------------------------------------------------------------------------
# Create Storage for the Ceph OSD Instances
#------------------------------------------------------------------------------------
module "storage" {
  source = "./storage"
  instance_count = "${var.instance_count * var.create_volume}"
  instance_id  = "${oci_core_instance.instances.*.id}"
  compartment_id = "${var.compartment_ocid}"
  availability_domain =  "${data.oci_identity_availability_domains.ADs.availability_domains}"
  availability_domain_index =  "${var.availability_domain_index_list}"
  volume_name_prefix = "${var.volume_name_prefix}"
  volume_size_in_gbs = "${var.volume_size_in_gbs}"
  volume_attachment_type = "${var.volume_attachment_type}"
  host_addresses = "${oci_core_instance.instances.*.public_ip}"
  ssh_private_key = "${file(var.ssh_private_key_file)}"
}

#------------------------------------------------------------------------------------
# Setup Ceph OSD Instances
#------------------------------------------------------------------------------------
resource "null_resource" "setup" {
  depends_on = ["oci_core_instance.instances"]
  count = "${var.instance_count}"
  provisioner "remote-exec" {
    connection {
      agent = false
      timeout = "30m"
      host = "${element(oci_core_instance.instances.*.public_ip, count.index)}"
      user = "${var.ssh_username}"
      private_key = "${file(var.ssh_private_key_file)}"
    }
    inline = [
      "sudo yum-config-manager --enable ol7_ceph ol7_latest ol7_optional_latest ol7_addons >> ${local.output_filename}",
      "sudo firewall-cmd --zone=public --add-port=6800-7300/tcp --permanent >> ${local.output_filename}",
      "sudo systemctl restart firewalld.service >> ${local.output_filename}"
    ]
  }
}

#------------------------------------------------------------------------------------
# Passwordless SSH Setup (from deployer to OSDs)
# - Get the ssh key from the Ceph Deployer Instance and install on OSDs
#------------------------------------------------------------------------------------
resource "null_resource" "wait_for_deployer_setup" {
  provisioner "local-exec" {
    command = "echo 'Waited for Deployer Setup (${var.deployer_setup}) to complete'"
  }
}

resource "null_resource" "copy_key" {
  depends_on = ["null_resource.setup", "null_resource.wait_for_deployer_setup"]
  count = "${var.instance_count}"
  provisioner "local-exec" {
    command = "${var.bashscript_directory}/installkey.sh ${var.ceph_deployer_ip} ${element(oci_core_instance.instances.*.public_ip, count.index)}"
  }
}

resource "null_resource" "add_to_deployer_known_hosts" {
  depends_on = ["null_resource.copy_key"]
  count = "${var.instance_count}"
  provisioner "remote-exec" {
    connection {
      agent = false
      timeout = "30m"
      host = "${var.ceph_deployer_ip}"
      user = "${var.ssh_username}"
      private_key = "${file(var.ssh_private_key_file)}"
    }
    inline = [
      "~/add_to_etc_hosts.sh ${element(oci_core_instance.instances.*.private_ip, count.index)} ${element(oci_core_instance.instances.*.hostname_label, count.index)}", 
      "~/add_to_known_hosts.sh ${element(oci_core_instance.instances.*.private_ip, count.index)} ${element(oci_core_instance.instances.*.hostname_label, count.index)}", 
     ]
  }
}

#------------------------------------------------------------------------------------
# Deploy ceph on OSDs
#------------------------------------------------------------------------------------
resource "null_resource" "wait_for_cluster_create" {
  provisioner "local-exec" {
      command = "echo 'Waited for create new cluster ${var.new_cluster} to complete'"
  }
}

resource "null_resource" "deploy" {
  depends_on = ["null_resource.add_to_deployer_known_hosts", "null_resource.wait_for_cluster_create"]
  provisioner "remote-exec" {
    connection {
      agent = false
      timeout = "30m"
      host = "${var.ceph_deployer_ip}"
      user = "${var.ssh_username}"
      private_key = "${file(var.ssh_private_key_file)}"
    }
    inline = [
      "cd ceph-deploy",
      "ceph-deploy install ${join(" ", oci_core_instance.instances.*.hostname_label)}"
    ]
  }
}

#------------------------------------------------------------------------------------
# Add the disk on OSDs
#------------------------------------------------------------------------------------
resource "null_resource" "add_disk" {
  depends_on = ["null_resource.deploy"]
  count = "${var.instance_count}"
  provisioner "remote-exec" {
    connection {
      agent = false
      timeout = "30m"
      host = "${var.ceph_deployer_ip}"
      user = "${var.ssh_username}"
      private_key = "${file(var.ssh_private_key_file)}"
    }
    inline = [
      "cd ceph-deploy",
      "ceph-deploy osd create --zap-disk --fs-type xfs ${var.hostname_prefix}-${count.index}:${element(var.block_device_for_ceph, var.create_volume)}"
    ]
  }
}
