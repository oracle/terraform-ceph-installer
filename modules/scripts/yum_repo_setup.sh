#!/bin/bash

output_filename=$1

# ---------------------------------------------------------------
# Check to see if "ceph_yum_repo" has an entry that is enabled
# If enabled, copy it to /etc/yum.repo.d/, disable ol7_ceph repository, and then yum install
# If not enaalbed, enable ol7_reposotory and then yum install
# ---------------------------------------------------------------
if [ -f ceph_yum_repo ]; then
  is_enabled=`grep enabled ceph_yum_repo | grep 1`
  if [ "X$is_enabled" != "X" ]; then
    echo "Custon repo is enabled"
    sudo yum-config-manager --disable ol7_ceph >> $output_filename
    sudo yum-config-manager --enable ol7_latest ol7_optional_latest ol7_addons >> $output_filename
    sudo cp ceph_yum_repo /etc/yum.repos.d/ceph.repo
  else
    echo "Custon repo is disabled"
    sudo yum-config-manager --enable ol7_ceph ol7_latest ol7_optional_latest ol7_addons >> $output_filename
  fi
else
  echo "Custon repo doesn't exist"
  sudo yum-config-manager --enable ol7_ceph ol7_latest ol7_optional_latest ol7_addons >> $output_filename
fi

