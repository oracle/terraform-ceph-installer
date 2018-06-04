#!/bin/bash

outfile=/tmp/terraform_ceph_install.out
pool_name=rbd
pool_page_num=128
pool_pgp_num=128
rbd_name=vol01
rbd_size=4096
filesystem_mount_point=/var/vol01
# Ceph FS related
fs_data_pool_name=cephfs_data
fs_data_pool_size=16
fs_metadata_pool_name=cephfs_metadata
fs_metadata_pool_size=16
ceph_fs_mount_point=/mnt/mycephfs

print_usage()
{
  echo ""
  echo "Usage: $0 <monitor_ip>"
  echo "       <monitor_ip> - the IP address of one of the monitors"
  echo ""
  exit
}

if [ $# -lt 1 ];then
  print_usage
fi

echo Executing $0 $* | tee -a $outfile

if [ -f ceph.config ]; then
  do_client_rbd_setup=$(awk -F= '/^do_client_rbd_setup/{print $2}' ceph.config)
  do_client_cephfs_setup=$(awk -F= '/^do_client_cephfs_setup/{print $2}' ceph.config)
  outfile=$(awk -F= '/^outputfile_name/{print $2}' ceph.config)
  pool_name=$(awk -F= '/^pool_name/{print $2}' ceph.config)
  pool_page_num=$(awk -F= '/^pool_page_num/{print $2}' ceph.config)
  pool_pgp_num=$(awk -F= '/^pool_pgp_num/{print $2}' ceph.config)
  rbd_name=$(awk -F= '/^rbd_name/{print $2}' ceph.config)
  rbd_size=$(awk -F= '/^rbd_size/{print $2}' ceph.config)
  filesystem_mount_point=$(awk -F= '/^filesystem_mount_point/{print $2}' ceph.config)
  fs_data_pool_name=$(awk -F= '/^fs_data_pool_name/{print $2}' ceph.config)
  fs_data_pool_size=$(awk -F= '/^fs_data_pool_size/{print $2}' ceph.config)
  fs_metadata_pool_name=$(awk -F= '/^fs_metadata_pool_name/{print $2}' ceph.config)
  fs_metadata_pool_size=$(awk -F= '/^fs_metadata_pool_size/{print $2}' ceph.config)
  ceph_fs_mount_point=$(awk -F= '/^ceph_fs_mount_point/{print $2}' ceph.config)
fi

echo Executing $0 | tee -a $outfile

ceph_version=`ceph -v | cut -d " " -f 3,3`
ceph_major_version=`echo $ceph_version | cut -d. -f 1,1`
kernel_version=`uname -r | cut -d "-" -f 1,1 | cut -d "." -f 3-3`

if [ "$do_client_rbd_setup" == "yes" ]; then
  device_name="/dev/rbd/$pool_name/$rbd_name"
  if [ $ceph_major_version -le 10 ]; then
    ceph osd pool create $pool_name $pool_page_num $pool_pgp_num | tee -a $outfile
    rbd create --size $rbd_size --pool $pool_name $rbd_name | tee -a $outfile
    sudo rbd map $rbd_name --pool $pool_name | tee -a $outfile
    sudo mkfs.ext4 -m0 $device_name | tee -a $outfile
    sudo mkdir $filesystem_mount_point
    sudo mount $device_name $filesystem_mount_point
  else
    ceph osd crush tunables legacy
    ceph osd pool create $pool_name $pool_page_num $pool_pgp_num | tee -a $outfile
    ceph osd pool application enable $pool_name rbd
    rbd pool init $pool_name
    rbd create $rbd_name --size $rbd_size --pool $pool_name --image-feature layering | tee -a $outfile
    rbd feature disable $pool_name/$rbd_name object-map fast-diff deep-flatten
    sudo rbd map $rbd_name --pool $pool_name | tee -a $outfile
    sudo mkfs.ext4 -m0 $device_name | tee -a $outfile
    sudo mkdir $filesystem_mount_point
    sudo mount $device_name $filesystem_mount_point
  fi
else
    echo Skipping RBD Setup \[ At host: $(hostname) \] $0 | tee -a $outfile
fi


if [ "$do_client_cephfs_setup" == "yes" ]; then
  ceph osd pool create $fs_data_pool_name $fs_data_pool_size
  ceph osd pool create $fs_metadata_pool_name $fs_metadata_pool_size
  ceph fs new cephfs $fs_data_pool_name $fs_metadata_pool_name
  awk  '/key/{print $3}' /etc/ceph/ceph.client.admin.keyring | sudo tee  /etc/ceph/admin.secret
  sudo mkdir $ceph_fs_mount_point
  monitor_ip=`grep mon_host /etc/ceph/ceph.conf  | awk '{print $NF}' | awk -F, '{print $1}'`
  sudo mount -t ceph $monitor_ip:6789:/ $ceph_fs_mount_point -o name=admin,secretfile=/etc/ceph/admin.secret
fi
