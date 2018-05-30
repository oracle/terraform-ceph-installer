#!/bin/bash

#------------------------------------------------------------------------
# This file allows for setting up newly created VMs to fuction properly
# in custom environments
#------------------------------------------------------------------------

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
  echo "Usage: $0 <type>"
  echo "       <type> - type of node (deployer|osd|monitor|mds|client)"
  echo ""
  exit
}

if [ $# -lt 1 ];then
  print_usage
fi

type=$1
echo "Setting up VM for $type:" $(hostname) | tee -a $outfile

ceph_version=`ceph -v | cut -d " " -f 3,3`
ceph_major_version=`echo $ceph_version | cut -d. -f 1,1`


# Here are some examples:

#------------------------------------------------------------------------
# To setup the DNS via the /etc/resolv.conf file
#------------------------------------------------------------------------
grep -v "^search" /etc/resolv.conf  | grep -v "^nameserver" > /tmp/etc.resolve.conf
echo "search us.oracle.com" >> /tmp/etc.resolve.conf
echo "nameserver 10.211.11.1" >> /tmp/etc.resolve.conf
sudo cp -f /tmp/etc.resolve.conf /etc/resolv.conf
rm -f /tmp/etc.resolve.conf


#------------------------------------------------------------------------
# To setup the proxy servers
#------------------------------------------------------------------------
echo "export http_proxy=http://www-proxy.us.oracle.com:80" >> ~/.bashrc
echo "export https_proxy=http://www-proxy.us.oracle.com:80" >> ~/.bashrc
echo "set -o vi" >> ~/.bashrc


#------------------------------------------------------------------------
# To maintain the proxy environments when doing a sudo
# Add a line to the /etc/sudoers file
#------------------------------------------------------------------------
sudo cp /etc/sudoers /etc/sudoers.orig
sudo sed '/Defaults    env_keep += "LC_TIME LC_ALL LANGUAGE LINGUAS _XKB_CHARSET XAUTHORITY"/a Defaults    env_keep += "ftp_proxy http_proxy https_proxy no_proxy"' /etc/sudoers > /tmp/etc.sudoers.modified
sudo cp /tmp/etc.sudoers.modified /etc/sudoers

#------------------------------------------------------------------------
# To enter permissive mode for SELinux
#------------------------------------------------------------------------
sudo setenforce 0

#------------------------------------------------------------------------
# To reboot
#------------------------------------------------------------------------
#sudo shutdown -r +1 &

