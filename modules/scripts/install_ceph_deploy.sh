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

sudo yum -y install ceph-deploy | tee -a $outfile
ceph-deploy install $(hostname)

ceph_version=`ceph -v | cut -d " " -f 3,3`
ceph_major_version=`echo $ceph_version | cut -d. -f 1,1`

echo  "Intalling Ceph version: $ceph_version" | tee -a $outfile
