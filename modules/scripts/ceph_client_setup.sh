#!/bin/bash

print_usage()
{
  echo ""
  echo "Usage: $0 <output_file> <.....>"
  echo "       <output_file> - to contain the output of ceph deploy commands"
  echo ""
  exit
}

if [ $# -lt 8 ];then
  print_usage
fi

output_filename=$1
datastore_name=$2
datastore_value=$3
rbd_name=$4
rbd_size=$5
filesystem_mount_point=$6
user_directoy_name=$7
ssh_user_name=$8

device_name="/dev/rbd/$datastore_name/$rbd_name"
user_directory="$filesystem_mount_point/$user_directoy_name"

ceph osd pool create $datastore_name $datastore_value $datastore_value >> $output_filename
rbd create --size $rbd_size --pool $datastore_name $rbd_name >> $output_filename
sudo rbd map $rbd_name --pool $datastore_name >> $output_filename
sudo mkfs.ext4 -m0 $device_name >> $output_filename
sudo mkdir $filesystem_mount_point
sudo mount $device_name $filesystem_mount_point
sudo mkdir $user_directory
sudo chown $ssh_user_name $user_directory
sudo chgrp $ssh_user_name $user_directory

