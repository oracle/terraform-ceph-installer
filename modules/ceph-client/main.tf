
locals {
  output_filename = "/tmp/terraform.ceph-client-exec.out"
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
# Create Ceph Client Instances
#------------------------------------------------------------------------------------
resource "oci_core_instance" "instance" {
  count = "${var.num_client}"
  availability_domain =  "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.availability_domain_index - 1],"name")}"
  compartment_id = "${var.compartment_ocid}"
  display_name = "${var.hostname}"
  hostname_label = "${var.hostname}"
  image = "${lookup(data.oci_core_images.image_ocid.images[0], "id")}"
  shape = "${var.shape}"
  subnet_id = "${var.subnet_id}"
  metadata {
    ssh_authorized_keys = "${file(var.ssh_public_key_file)}"
  }
  timeouts {
    create = "${var.instance_create_timeout}"
  }
}

#------------------------------------------------------------------------------------
# Setup Ceph Client Instances
#------------------------------------------------------------------------------------
resource "null_resource" "setup" {
  count = "${var.num_client}"
  provisioner "remote-exec" {
    connection {
      agent = false
      timeout = "30m"
      host = "${oci_core_instance.instance.public_ip}"
      user = "${var.ssh_username}"
      private_key = "${file(var.ssh_private_key_file)}"
    }
    inline = [
      #"sudo yum update -y > ${local.output_filename}",
      "sudo yum-config-manager --enable ol7_ceph ol7_latest ol7_optional_latest ol7_addons >> ${local.output_filename}",
      "sudo systemctl stop firewalld >> ${local.output_filename}",
      "sudo systemctl disable firewalld >> ${local.output_filename}",
    ]
  }
}

#------------------------------------------------------------------------------------
# Passwordless SSH Setup (from deployer to OSDs)
# - Get the ssh key from the Ceph Deployer Instance and install on OSDs
#------------------------------------------------------------------------------------
resource "null_resource" "wait_for_deployer_setup" {
  count = "${var.num_client}"
  provisioner "local-exec" {
    command = "echo 'Waited for Deployer Setup (${var.deployer_setup}) to complete'"
  }
}

resource "null_resource" "copy_key" {
  count = "${var.num_client}"
  depends_on = ["null_resource.setup", "null_resource.wait_for_deployer_setup"]
  provisioner "local-exec" {
     command = "${var.bashscript_directory}/installkey.sh ${var.ceph_deployer_ip} ${oci_core_instance.instance.public_ip}"
  }
}

resource "null_resource" "add_to_deployer_known_hosts" {
  count = "${var.num_client}"
  depends_on = ["null_resource.copy_key"]
  provisioner "remote-exec" {
    connection {
      agent = false
      timeout = "30m"
      host = "${var.ceph_deployer_ip}"
      user = "${var.ssh_username}"
      private_key = "${file(var.ssh_private_key_file)}"
    }
    inline = [
      "~/add_to_etc_hosts.sh ${oci_core_instance.instance.private_ip} ${oci_core_instance.instance.hostname_label}",
      "~/add_to_known_hosts.sh ${oci_core_instance.instance.private_ip} ${oci_core_instance.instance.hostname_label}",
    ]
  }
}

#------------------------------------------------------------------------------------
# 1. Deploy Ceph
# 2. Make the client an admin node
# 3. Make the keyfiles on the client readable
#------------------------------------------------------------------------------------
resource "null_resource" "wait_for_cluster_create" {
  count = "${var.num_client}"
  provisioner "local-exec" {
    command = "echo 'Waited for create new cluster ${var.new_cluster} to complete'"
  }
}

resource "null_resource" "deploy" {
  count = "${var.num_client}"
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
      "ceph-deploy install ${oci_core_instance.instance.hostname_label}",
      "ceph-deploy admin ${oci_core_instance.instance.hostname_label}",
      "ssh -l opc ${oci_core_instance.instance.hostname_label} sudo chmod +r /etc/ceph/ceph.client.admin.keyring"
     ]
  }
}

#------------------------------------------------------------------------------------
# 1. Create the Rados block device
# 2. Create a File System and mount on /var/vol01/opc
#------------------------------------------------------------------------------------
resource "null_resource" "wait_for_add_disk" {
  count = "${var.num_client}"
  provisioner "local-exec" {
    command = "echo 'Waited for disk add on OSDs ${var.add_disk} to complete'"
  }
}

resource "null_resource" "create_rbd" {
  depends_on = [ "null_resource.deploy", "null_resource.wait_for_add_disk" ]
  count = "${var.num_client}"
  provisioner "remote-exec" {
    connection {
      agent = false
      timeout = "30m"
      host = "${oci_core_instance.instance.public_ip}"
      user = "${var.ssh_username}"
      private_key = "${file(var.ssh_private_key_file)}"
    }
    inline = [
      "ceph osd pool create ${var.datastore_name} ${var.datastore_value} ${var.datastore_value}",
      "rbd create --size ${var.rbd_size} --pool ${var.datastore_name} ${var.rbd_name}",
      "sudo rbd map ${var.rbd_name} --pool ${var.datastore_name}",
      "sudo mkfs.ext4 -m0 /dev/rbd/${var.datastore_name}/${var.rbd_name}",
      "sudo mkdir ${var.filesystem_mount_point}",
      "sudo mount /dev/rbd/${var.datastore_name}/${var.rbd_name} ${var.filesystem_mount_point}",
      "sudo mkdir ${var.filesystem_mount_point}/${var.user_directoy_name}",
      "sudo chown opc ${var.filesystem_mount_point}/${var.user_directoy_name}",
      "sudo chgrp opc ${var.filesystem_mount_point}/${var.user_directoy_name}",
    ]
  }
}
