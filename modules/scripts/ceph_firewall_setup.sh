#!/bin/bash

outfile=/tmp/terraform_ceph_install.out

if [ -f ceph.config ]; then
  do_vm_setup=$(awk -F= '/do_vm_setup/{print $2}' ceph.config)
  outfile=$(awk -F= '/outputfile_name/{print $2}' ceph.config)
  if [ "$do_vm_setup" != "yes" ]; then
    echo VM Setup is not done | tee -a $outfile
    echo Skipping ... \[ At host: $(hostname) \] $0 $* | tee -a $outfile
    exit
  fi
fi

print_usage()
{
  echo ""
  echo "Usage: $0 <osd|monitor>"
  echo "       <osd|monitor> - whether for osd or monitor"
  echo ""
  exit
}

if [ $# -lt 1 ];then
  print_usage
fi

type=$1

if [ "$type" == "osd" ]; then
  echo "Setting up firewall for osd:" $(hostname) | tee -a $outfile
  sudo firewall-cmd --zone=public --add-port=6800-7300/tcp --permanent | tee -a $outfile
  sudo systemctl restart firewalld.service | tee -a $outfile
fi

if [ "$type" == "monitor" ]; then
  echo "Setting up firewall for monitor:" $(hostname) | tee -a $outfile
  sudo firewall-cmd --zone=public --add-port=6789/tcp --permanent | tee -a $outfile
  sudo systemctl restart firewalld.service | tee -a $outfile
fi
