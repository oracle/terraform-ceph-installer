#!/bin/bash

if [ -f ceph.config ]; then
  do_vm_setup=$(awk -F= '/do_vm_setup/{print $2}' ceph.config)
  outfile=$(awk -F= '/outputfile_name/{print $2}' ceph.config)
  if [ "$do_vm_setup" != "yes" ]; then
    echo Ceph VM Setup is not done | tee -a $outfile
    echo Skipping ... \[ At host: $(hostname) \] $0 $* | tee -a $outfile
    exit
  fi
fi

ssh $1 -o "StrictHostKeyChecking no" -l opc 'cat ~/.ssh/id_rsa.pub' | ssh $2 -o "StrictHostKeyChecking no" -l opc 'cat >> .ssh/authorized_keys'
sleep 5
