#!/bin/bash

#------------------------------------------------------------------------
# This is part of three setup files that allow for setting up newly
# created VMs after the VM is create and initialized.
# The three files are:
# 1. vm_pre_setup (this file)
# 2. vm_setup, and
# 3. vm_post_setup
# These files can be used, for example, to install packages, update the
# OS or change the kernel etc.
#------------------------------------------------------------------------

outfile=/tmp/terraform_ceph_install.out

if [ -f ceph.config ]; then
  do_vm_setup=$(awk -F= '/^do_vm_setup/{print $2}' ceph.config)
  outfile=$(awk -F= '/^outputfile_name/{print $2}' ceph.config)
  if [ "$do_vm_setup" != "yes" ]; then
    echo VM Setup is not done | tee -a $outfile
    echo Skipping vm pre setup ... \[ At host: $(hostname) \] $0 $* | tee -a $outfile
    exit
  fi
fi

print_usage()
{
  echo ""
  echo "Usage: $0 <type>"
  echo "       <type> - type of node (deployer|osd|monitor|mds|client)"
  echo ""
  exit
}

if [ $# -lt 1 ];then
  print_usage
fi

type=$1
echo "Executing vm_pre_setup for $type:" $(hostname) | tee -a $outfile
