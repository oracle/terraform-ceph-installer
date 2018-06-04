#!/bin/bash

outfile=/tmp/terraform_ceph_install.out

if [ -f ceph.config ]; then
  do_vm_setup=$(awk -F= '/^do_vm_setup/{print $2}' ceph.config)
  outfile=$(awk -F= '/^outputfile_name/{print $2}' ceph.config)
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

echo Executing $0 $* | tee -a $outfile

type=$1
echo "Setting up firewall for $type:" $(hostname) | tee -a $outfile

#ceph_version=`ceph -v | cut -d " " -f 3,3`
#ceph_major_version=`echo $ceph_version | cut -d. -f 1,1`
#ceph_major_version=10

if [ "$type" == "osd" ]; then
  sudo systemctl stop firewalld | tee -a $outfile
  sudo systemctl disable firewalld | tee -a $outfile

#  echo sudo firewall-cmd --zone=public --add-service=ceph --permanent | tee -a $outfile
#  sudo firewall-cmd --zone=public --add-service=ceph --permanent
#  if [ $ceph_major_version -le 10 ]; then
#    echo sudo firewall-cmd --zone=public --add-port=6800-7300/tcp --permanent | tee -a $outfile
#    sudo firewall-cmd --zone=public --add-port=6800-7300/tcp --permanent
#  else
#    echo sudo firewall-cmd --zone=public --add-service=ceph --permanent | tee -a $outfile
#    sudo firewall-cmd --zone=public --add-service=ceph --permanent
#    sudo firewall-cmd --zone=public --add-service=ceph-mon --permanent
#  fi
fi

if [ "$type" == "monitor" ]; then
  sudo systemctl stop firewalld | tee -a $outfile
  sudo systemctl disable firewalld | tee -a $outfile
#  echo sudo firewall-cmd --zone=public --add-service=ceph-mon --permanent | tee -a $outfile
#  sudo firewall-cmd --zone=public --add-service=ceph-mon --permanent
#  if [ $ceph_major_version -le 10 ]; then
#    echo sudo firewall-cmd --zone=public --add-port=6789/tcp --permanent | tee -a $outfile
#    sudo firewall-cmd --zone=public --add-port=6789/tcp --permanent | tee -a $outfile
#  else
#    echo sudo firewall-cmd --zone=public --add-service=ceph-mon --permanent | tee -a $outfile
#    sudo firewall-cmd --zone=public --add-service=ceph --permanent
#    sudo firewall-cmd --zone=public --add-service=ceph-mon --permanent
#  fi
fi

if [ "$type" == "mds" ]; then
  sudo systemctl stop firewalld | tee -a $outfile
  sudo systemctl disable firewalld | tee -a $outfile
#  echo sudo firewall-cmd --zone=public --add-service=ceph --permanent | tee -a $outfile
#  sudo firewall-cmd --zone=public --add-service=ceph --permanent
fi

if [ "$type" == "client" ]; then
  sudo systemctl stop firewalld | tee -a $outfile
  sudo systemctl disable firewalld | tee -a $outfile
#  echo sudo firewall-cmd --zone=public --add-service=ceph --permanent | tee -a $outfile
#  sudo firewall-cmd --zone=public --add-service=ceph --permanent
fi

if [ "$type" == "deployer" ]; then
  sudo systemctl stop firewalld | tee -a $outfile
  sudo systemctl disable firewalld | tee -a $outfile
#  echo sudo firewall-cmd --zone=public --add-service=ceph --permanent | tee -a $outfile
#  sudo firewall-cmd --zone=public --add-service=ceph --permanent
fi


#echo sudo firewall-cmd --reload | tee -a $outfile
#sudo firewall-cmd --reload
#echo sudo systemctl restart firewalld.service
#sudo systemctl restart firewalld.service

echo "Done ....  $0" | tee -a $outfile

