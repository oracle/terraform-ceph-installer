
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
  provisioner "file" {
    source = "${var.scripts_directory}/yum_repo_setup.sh"
    destination = "~/yum_repo_setup.sh"
  }
  provisioner "file" {
    source = "${var.scripts_directory}/ceph_yum_repo"
    destination = "~/ceph_yum_repo"
  }
  provisioner "file" {
    source = "${var.scripts_directory}/ceph_client_setup.sh"
    destination = "~/ceph_client_setup.sh"
  }
  connection {
    host = "${self.public_ip}"
    type = "ssh"
    user = "${var.ssh_username}"
    private_key = "${file(var.ssh_private_key_file)}"
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
      "chmod +x ~/yum_repo_setup.sh",
      "~/yum_repo_setup.sh  ${local.output_filename}",
      "chmod +x ~/ceph_client_setup.sh",
      "sudo systemctl stop firewalld >> ${local.output_filename}",
      "sudo systemctl disable firewalld >> ${local.output_filename}",
    ]
  }
}

#------------------------------------------------------------------------------------
# Passwordless SSH Setup (from deployer to OSDs)
# - Get the ssh key from the Ceph Deployer Instance and install on OSDs
#------------------------------------------------------------------------------------
resource "null_resource" "wait_for_deployer_deploy" {
  count = "${var.num_client}"
  provisioner "local-exec" {
    command = "echo 'Waited for Deployer Setup (${var.deployer_deploy}) to complete'"
  }
}

resource "null_resource" "copy_key" {
  count = "${var.num_client}"
  depends_on = ["null_resource.setup", "null_resource.wait_for_deployer_deploy"]
  provisioner "local-exec" {
     command = "${var.scripts_directory}/installkey.sh ${var.ceph_deployer_ip} ${oci_core_instance.instance.public_ip}"
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
    command = "echo 'Waited for create new cluster ${var.new_cluster} creation'"
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
      "~/ceph_deploy_client.sh ${local.output_filename} ${join(" ", oci_core_instance.instance.*.hostname_label)}"
     ]
  }
}

#------------------------------------------------------------------------------------
# 1. Create the Rados block device
# 2. Create a File System and mount on /var/vol01/opc
#------------------------------------------------------------------------------------
resource "null_resource" "wait_for_osd_deploy" {
  count = "${var.num_client}"
  provisioner "local-exec" {
    command = "echo 'Waited for OSD deployment ${var.osd_deploy} to complete'"
  }
}

resource "null_resource" "create_rbd" {
  depends_on = [ "null_resource.deploy", "null_resource.wait_for_osd_deploy" ]
  count = "${var.num_client}"
  provisioner "remote-exec" {
    connection {
      agent = false
      timeout = "30m"
      host = "${element(oci_core_instance.instance.*.public_ip, count.index)}"
      user = "${var.ssh_username}"
      private_key = "${file(var.ssh_private_key_file)}"
    }
    inline = [
      "~/ceph_client_setup.sh ${local.output_filename} ${var.datastore_name} ${var.datastore_value} ${var.rbd_name} ${var.rbd_size} ${var.filesystem_mount_point} ${var.user_directoy_name} ${var.ssh_username}"
    ]
  }
}
