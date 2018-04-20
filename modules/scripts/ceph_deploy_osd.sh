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

print_usage()
{
  echo ""
  echo "Usage: $0 <device_name> <osd1_hostname> [ <osd2_hostname> <....> ]"
  echo "       <osd1_hostname> - the first hostname for osd(s)"
  echo ""
  exit
}

if [ $# -lt 2 ];then
  print_usage
fi

device_name=$1
shift
hostname_list=$*


cd ceph-deploy
ceph-deploy install $hostname_list | tee -a $outfile

ceph_version=`ceph -v | cut -d " " -f 3,3`
ceph_major_version=`echo $ceph_version | cut -d. -f 1,1`

for h in $hostname_list
do
  if [ $ceph_major_version -le 10 ]; then
    ceph-deploy osd create --zap-disk --fs-type xfs $h:$device_name | tee -a $outfile
  else
    ceph-deploy osd create --data /dev/$device_name $h | tee -a $outfile
  fi
done
