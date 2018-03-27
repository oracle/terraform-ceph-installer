#!/bin/bash

print_usage()
{
  echo ""
  echo "Usage: $0 <output_file> <client1_hostname> [ <client2_hostname> <....> ]"
  echo "       <output_file> - to contain the output of ceph deploy commands"
  echo "       <client1_hostname> - the first hostname for client(s)"
  echo ""
  exit
}

if [ $# -lt 2 ];then
  print_usage
fi

output_filename=$1
client1_hostname=$2
shift
hostname_list=$*


cd ceph-deploy
ceph-deploy install $hostname_list >> $output_filename
ceph-deploy admin $hostname_list >> $output_filename


for h in $hostname_list
do
  ssh -l opc $h sudo chmod +r /etc/ceph/ceph.client.admin.keyring >> $output_filename
done
