#!/bin/bash

print_usage()
{
  echo ""
  echo "Usage: $0 <output_file> <device_name> <osd1_hostname> [ <osd2_hostname> <....> ]"
  echo "       <output_file> - to contain the output of ceph deploy commands"
  echo "       <osd1_hostname> - the first hostname for osd(s)"
  echo ""
  exit
}

if [ $# -lt 3 ];then
  print_usage
fi

output_filename=$1
device_name=$2
shift
shift
hostname_list=$*


cd ceph-deploy
ceph-deploy install $hostname_list >> $output_filename

for h in $hostname_list
do
  ceph-deploy osd create --zap-disk --fs-type xfs $h:$device_name >> $output_filename
done

