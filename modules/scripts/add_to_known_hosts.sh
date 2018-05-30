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

while [[ $# -gt 0 ]]
do
  echo "Adding: $1 to ~/.ssh/known_hosts"
  ssh-keygen -R $1
  ssh-keyscan $1 | grep ecdsa-sha2 >> ~/.ssh/known_hosts
  shift
done
) 200>.tf_script_knownhost_lock
