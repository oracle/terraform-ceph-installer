#!/bin/bash

outfile=/tmp/terraform_ceph_install.out
pool_name=rbd
pool_page_num=128
pool_pgp_num=128
rbd_name=vol01
rbd_size=4096
filesystem_mount_point=/var/vol01

if [ -f ceph.config ]; then
  do_client_setup=$(awk -F= '/do_client_setup/{print $2}' ceph.config)
  outfile=$(awk -F= '/outputfile_name/{print $2}' ceph.config)
  pool_name=$(awk -F= '/pool_name/{print $2}' ceph.config)
  pool_page_num=$(awk -F= '/pool_page_num/{print $2}' ceph.config)
  pool_pgp_num=$(awk -F= '/pool_pgp_num/{print $2}' ceph.config)
  rbd_name=$(awk -F= '/rbd_name/{print $2}' ceph.config)
  rbd_size=$(awk -F= '/rbd_size/{print $2}' ceph.config)
  filesystem_mount_point=$(awk -F= '/filesystem_mount_point/{print $2}' ceph.config)
  if [ "$do_client_setup" != "yes" ]; then
    echo Ceph Client Setup is not done | tee -a $outfile
    echo Skipping ... \[ At host: $(hostname) \] $0 $* | tee -a $outfile
    exit
  fi
fi

print_usage()
{
  echo ""
  echo "Usage: $0 <ssh_user_name>"
  echo "       <ssh_user_name> - the user name for ssh to the client"
  echo ""
  exit
}

if [ $# -lt 1 ];then
  print_usage
fi

# Not used
ssh_user_name=$1

device_name="/dev/rbd/$pool_name/$rbd_name"

sudo systemctl stop firewalld | tee -a $outfile
sudo systemctl disable firewalld | tee -a $outfile

ceph_version=`ceph -v | cut -d " " -f 3,3`
ceph_major_version=`echo $ceph_version | cut -d. -f 1,1`

if [ $ceph_major_version -le 10 ]; then
  ceph osd pool create $pool_name $pool_page_num $pool_pgp_num | tee -a $outfile
  rbd create --size $rbd_size --pool $pool_name $rbd_name | tee -a $outfile
  sudo rbd map $rbd_name --pool $pool_name | tee -a $outfile
  sudo mkfs.ext4 -m0 $device_name | tee -a $outfile
  sudo mkdir $filesystem_mount_point
  sudo mount $device_name $filesystem_mount_point
else
  ceph osd pool create $pool_name $pool_page_num $pool_pgp_num | tee -a $outfile
  ceph osd pool application enable $pool_name rbd
  rbd pool init $pool_name
  rbd create $rbd_name --size $rbd_size --pool $pool_name --image-feature layering | tee -a $outfile
  ceph osd crush tunables legacy
  rbd feature disable $pool_name/$rbd_name object-map fast-diff deep-flatten
  sudo rbd map $rbd_name --pool $pool_name | tee -a $outfile
  sudo mkfs.ext4 $device_name | tee -a $outfile
  sudo mkdir $filesystem_mount_point
  sudo mount $device_name $filesystem_mount_point
fi

