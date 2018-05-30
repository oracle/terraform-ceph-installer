#!/bin/bash

outfile=/tmp/terraform_ceph_install.out

if [ -f ceph.config ]; then
  do_vm_setup=$(awk -F= '/^do_vm_setup/{print $2}' ceph.config)
  outfile=$(awk -F= '/^outputfile_name/{print $2}' ceph.config)
  if [ "$do_vm_setup" != "yes" ]; then
    echo Ceph VM Setup is not done | tee -a $outfile
    echo Skipping ... \[ At host: $(hostname) \] $0 $* | tee -a $outfile
    exit
  fi
fi

(
flock 200
  echo "Adding: $1 $2  to /etc/hosts"
  sudo sed -i "/$2/d" /etc/hosts
  sudo sh -c "echo $1 $2 >> /etc/hosts"
) 200>.tf_script_etchost_lock
