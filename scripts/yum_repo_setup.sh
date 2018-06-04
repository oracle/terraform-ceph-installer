#!/bin/bash

outfile=/tmp/terraform_ceph_install.out

if [ -f ceph.config ]; then
  do_ceph_install=$(awk -F= '/^do_ceph_install/{print $2}' ceph.config)
  outfile=$(awk -F= '/^outputfile_name/{print $2}' ceph.config)
  if [ "$do_ceph_install" != "yes" ]; then
    echo Ceph Yum Repo Setup is not done | tee -a $outfile
    echo Skipping ... \[ At host: $(hostname) \] $0 $* | tee -a $outfile
    exit
  fi
fi

# ---------------------------------------------------------------
# Check to see if "ceph_yum_repo" has an entry that is enabled
# If enabled, copy it to /etc/yum.repo.d/, disable ol7_ceph repository, and then yum install
# If not enaalbed, enable ol7_reposotory and then yum install
# ---------------------------------------------------------------
if [ -f ceph_yum_repo ]; then
  is_enabled=`grep enabled ceph_yum_repo | grep 1`
  if [ "X$is_enabled" != "X" ]; then
    echo "Custom repo is enabled" | tee -a $outfile
    sudo yum-config-manager --disable ol7_ceph ol7_software_collections ol7_developer_EPEL | tee -a $outfile
    sudo yum-config-manager --enable ol7_latest ol7_optional_latest ol7_addons | tee -a $outfile
    sudo cp ceph_yum_repo /etc/yum.repos.d/ceph.repo
  else
    echo "Custom repo is disabled" | tee -a $outfile
    sudo yum-config-manager --disable ol7_software_collections ol7_developer_EPEL | tee -a $outfile
    sudo yum-config-manager --enable ol7_ceph ol7_latest ol7_optional_latest ol7_addons | tee -a $outfile
  fi
else
  echo "Custom repo doesn't exist" | tee -a $outfile
  sudo yum-config-manager --disable ol7_software_collections ol7_developer_EPEL | tee -a $outfile
  sudo yum-config-manager --enable ol7_ceph ol7_latest ol7_optional_latest ol7_addons | tee -a $outfile
fi

