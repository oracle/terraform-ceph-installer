#!/bin/bash

outfile=/tmp/terraform_ceph_install.out

if [ -f ceph.config ]; then
  do_ceph_install=$(awk -F= '/^do_ceph_install/{print $2}' ceph.config)
  outfile=$(awk -F= '/^outputfile_name/{print $2}' ceph.config)
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

echo Executing $0 $* | tee -a $outfile

hostname_list=$*

cd ceph-deploy
ceph-deploy install $hostname_list | tee -a $outfile
ceph-deploy config push $hostname_list | tee -a $outfile
ceph-deploy --overwrite-conf mds create $hostname_list | tee -a $outfile
