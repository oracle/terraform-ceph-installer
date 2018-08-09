#!/bin/bash

#-------------------------------------------------------------------------------
# Adds the necessary delays before or after a VM setup
# It could be necessary, for example, if the VM is rebooted as part of the setup
#-------------------------------------------------------------------------------

outfile=/tmp/terraform-setup.out

if [ -f ceph.config ]; then
  do_vm_setup=$(awk -F= '/^do_vm_setup/{print $2}' ceph.config)
  outfile=$(awk -F= '/^outputfile_name/{print $2}' ceph.config)
  delay_sec_before_vm_setup=$(awk -F= '/^delay_sec_before_vm_setup/{print $2}' ceph.config)
  delay_sec_after_vm_setup=$(awk -F= '/^delay_sec_after_vm_setup/{print $2}' ceph.config)
  if [ "$do_vm_setup" != "yes" ]; then
    echo Skipping the execution of delay.sh \[ At host: $(hostname) \] $0 $* | tee -a $outfile
    exit
  fi
fi

print_usage()
{
  echo ""
  echo "Usage: $0 <when>"
  echo "       <when> - before_setup | after_setup"
  echo ""
  exit
}

if [ $# -lt 1 ];then
  print_usage
fi

when=$1

if [ "$when" = "before_setup" ]; then
  echo "Sleeping for $delay_sec_before_vm_setup seconds"
  sleep $delay_sec_before_vm_setup
fi

if [ "$when" = "after_setup" ]; then
  echo "Sleeping for $delay_sec_after_vm_setup seconds"
  sleep $delay_sec_after_vm_setup
fi
