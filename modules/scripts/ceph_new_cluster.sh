#!/bin/bash

outfile=/tmp/terraform_ceph_install.out
num_object_replica=3
rbd_default_features=3
pool_page_num=128
pool_pgp_num=128

if [ -f ceph.config ]; then
  do_ceph_install=$(awk -F= '/do_ceph_install/{print $2}' ceph.config)
  outfile=$(awk -F= '/outputfile_name/{print $2}' ceph.config)
  num_object_replica=$(awk -F= '/num_object_replica/{print $2}' ceph.config)
  rbd_default_features=$(awk -F= '/rbd_default_features/{print $2}' ceph.config)
  pool_page_num=$(awk -F= '/pool_page_num/{print $2}' ceph.config)
  pool_pgp_num=$(awk -F= '/pool_pgp_num/{print $2}' ceph.config)
  if [ "$do_ceph_install" != "yes" ]; then
    echo Ceph installation is not done | tee -a $outfile
    echo Skipping ... \[ At host: $(hostname) \] $0 $* | tee -a $outfile
    exit
  fi
fi

print_usage()
{
  echo ""
  echo "Usage: $0 <monitor1_hostname> [ <monitor2_hostname> <....> ]"
  echo "       <output_file> - to contain the output of ceph deploy commands"
  echo "       <monitor1_hostname> - the first hostname for monitor(s)"
  echo ""
  exit
}

if [ $# -lt 1 ];then
  print_usage
fi

monitor1_hostname=$1
hostname_list=$*


mkdir ceph-deploy
cd ceph-deploy
ceph-deploy new $hostname_list | tee -a $outfile
ceph-deploy install $hostname_list | tee -a $outfile

ceph_version=`ceph -v | cut -d " " -f 3,3` 
ceph_major_version=`echo $ceph_version | cut -d. -f 1,1`

if [ $ceph_major_version -le 10 ]; then
  echo osd pool default size = $num_object_replica | tee -a ceph.conf
  echo rbd default features = $rbd_default_features | tee -a ceph.conf
  ceph-deploy mon create-initial | tee -a $outfile
  ceph-deploy mon create $hostname_list | tee -a $outfile
  ceph-deploy gatherkeys $monitor1_hostname | tee -a $outfile
  for h in $hostname_list
  do
    ssh -l opc $h sudo chmod +r /etc/ceph/ceph.client.admin.keyring | tee -a $outfile
  done
else
  echo osd pool default size = $num_object_replica | tee -a ceph.conf
  echo rbd default features = $rbd_default_features | tee -a ceph.conf
  echo mon_allow_pool_delete = true | tee -a ceph.conf
  echo osd pool default pg num = $pool_page_num  | tee -a ceph.conf
  echo osd pool default pgp num = $pool_pgp_num  | tee -a ceph.conf
  ceph-deploy --overwrite-conf mon create-initial | tee -a $outfile
  ceph-deploy --overwrite-conf admin $(hostname) | tee -a $outfile
  sudo chmod +r /etc/ceph/ceph.client.admin.keyring | tee -a $outfile
  ceph-deploy mgr create $(hostname) | tee -a $outfile
fi
