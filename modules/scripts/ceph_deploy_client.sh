#!/bin/bash

outfile=/tmp/terraform_ceph_install.out

if [ -f ceph.config ]; then
  do_ceph_install=$(awk -F= '/do_ceph_install/{print $2}' ceph.config)
  outfile=$(awk -F= '/outputfile_name/{print $2}' ceph.config)
  if [ "$do_ceph_install" != "yes" ]; then
    echo Ceph installation is not done | tee -a $outfile
    echo Skipping ... \[ At host: $(hostname) \] $0 $* | tee -a $outfile
    exit
  fi
fi

print_usage()
{
  echo ""
  echo "Usage: $0 <client1_hostname> [ <client2_hostname> <....> ]"
  echo "       <output_file> - to contain the output of ceph deploy commands"
  echo "       <client1_hostname> - the first hostname for client(s)"
  echo ""
  exit
}

if [ $# -lt 1 ];then
  print_usage
fi

client1_hostname=$1
hostname_list=$*

cd ceph-deploy
ceph-deploy install $hostname_list | tee -a $outfile
ceph-deploy admin $hostname_list | tee -a $outfile

ceph_version=`ceph -v | cut -d " " -f 3,3` 
ceph_major_version=`echo $ceph_version | cut -d. -f 1,1`


for h in $hostname_list
do
  if [ $ceph_major_version -le 10 ]; then
    ssh -l opc $h sudo chmod +r /etc/ceph/ceph.client.admin.keyring | tee -a $outfile
  else 
    ssh -l opc $h sudo chmod +r /etc/ceph/ceph.client.admin.keyring | tee -a $outfile
  fi
done
