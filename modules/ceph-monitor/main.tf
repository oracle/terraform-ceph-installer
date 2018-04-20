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
# Create Ceph Monitor Server Instances
#------------------------------------------------------------------------------------
resource "oci_core_instance" "ceph_monitors" {
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
  provisioner "file" {
    source = "${var.scripts_directory}/ceph.config"
    destination = "~/ceph.config"
  }
  provisioner "file" {
    source = "${var.scripts_directory}/vm_setup.sh"
    destination = "~/vm_setup.sh"
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
    source = "${var.scripts_directory}/ceph_firewall_setup.sh"
    destination = "~/ceph_firewall_setup.sh"
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
# Setup the VM 
#------------------------------------------------------------------------------------
resource "null_resource" "vm_setup" {
  depends_on = ["oci_core_instance.ceph_monitors"]
  count = "${var.instance_count}"
  provisioner "remote-exec" {
    connection {
      agent = false
      timeout = "30m"
      host = "${element(oci_core_instance.ceph_monitors.*.public_ip, count.index)}"
      user = "${var.ssh_username}"
      private_key = "${file(var.ssh_private_key_file)}"
    }
    inline = [
      "chmod +x ~/vm_setup.sh",
      "chmod +x ~/yum_repo_setup.sh",
      "chmod +x ~/ceph_firewall_setup.sh",
      "~/vm_setup.sh",
    ]
  }
}

#------------------------------------------------------------------------------------
# Setup Ceph Monitor Instances
#------------------------------------------------------------------------------------
resource "null_resource" "setup" {
  depends_on = ["null_resource.vm_setup"]
  count = "${var.instance_count}"
  provisioner "remote-exec" {
    connection {
      agent = false
      timeout = "30m"
      host = "${element(oci_core_instance.ceph_monitors.*.public_ip, count.index)}"
      user = "${var.ssh_username}"
      private_key = "${file(var.ssh_private_key_file)}"
    }
    inline = [
      "~/yum_repo_setup.sh",
      "~/ceph_firewall_setup.sh monitor",
    ]
  }
}

#------------------------------------------------------------------------------------
# Passwordless SSH Setup
# - Get the ssh key from the Ceph Deployer Instance and install on the Monitors
#------------------------------------------------------------------------------------
resource "null_resource" "wait_for_deployer_deploy" {
  provisioner "local-exec" {
    command = "echo 'Waited for Deployer Ceph Deployment (${var.deployer_deploy}) to complete'"
  }
}

resource "null_resource" "copy_key" {
  depends_on = ["null_resource.setup", "null_resource.wait_for_deployer_deploy"]
  count = "${var.instance_count}"
  provisioner "local-exec" {
    command = "${var.scripts_directory}/install_ssh_key.sh ${var.ceph_deployer_ip} ${element(oci_core_instance.ceph_monitors.*.public_ip, count.index)}"
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
      "~/add_to_etc_hosts.sh ${element(oci_core_instance.ceph_monitors.*.private_ip, count.index)} ${element(oci_core_instance.ceph_monitors.*.hostname_label, count.index)}",
      "~/add_to_known_hosts.sh ${element(oci_core_instance.ceph_monitors.*.private_ip, count.index)} ${element(oci_core_instance.ceph_monitors.*.hostname_label, count.index)}",
    ]
  }
}

#------------------------------------------------------------------------------------
# Create a new cluster
#------------------------------------------------------------------------------------
resource "null_resource" "create_new_cluster" {
  depends_on = ["null_resource.add_to_deployer_known_hosts", "null_resource.wait_for_deployer_deploy"]
  provisioner "remote-exec" {
    connection {
      agent = false
      timeout = "30m"
      host = "${var.ceph_deployer_ip}"
      user = "${var.ssh_username}"
      private_key = "${file(var.ssh_private_key_file)}"
    }
    inline = [
       "~/ceph_new_cluster.sh ${join(" ", oci_core_instance.ceph_monitors.*.hostname_label)}"
    ]
  }
}
