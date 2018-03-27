#!/bin/bash

print_usage()
{
  echo ""
  echo "Usage: $0 <output_file> <num_object_replica> <rbd_default_features> <monitor1_hostname> [ <monitor2_hostname> <....> ]"
  echo "       <output_file> - to contain the output of ceph deploy commands"
  echo "       <num_object_replica> - to contain the output of ceph deploy commands"
  echo "       <rbd_default_features> - to contain the output of ceph deploy commands"
  echo "       <monitor1_hostname> - the first hostname for monitor(s)"
  echo ""
  exit
}

if [ $# -lt 4 ];then
  print_usage
fi

output_filename=$1
num_object_replica=$2
rbd_default_features=$3
monitor1_hostname=$4
shift
shift
shift
hostname_list=$*


mkdir ceph-deploy
cd ceph-deploy
ceph-deploy new $hostname_list >> $output_filename
echo osd pool default size = $num_object_replica >> ceph.conf
echo rbd default features = $rbd_default_features >> ceph.conf
ceph-deploy install $hostname_list >> $output_filename
ceph-deploy mon create-initial >> $output_filename
ceph-deploy mon create $hostname_list >> $output_filename
ceph-deploy gatherkeys $monitor1_hostname >> $output_filename


for h in $hostname_list
do
  ssh -l opc $h sudo chmod +r /etc/ceph/ceph.client.admin.keyring >> $output_filename
done
