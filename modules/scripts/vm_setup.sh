#!/bin/bash

#------------------------------------------------------------------------
# This file allows for setting up newly created VMs to fuction properly 
# in custom environments
#------------------------------------------------------------------------

# Here are some examples:

#------------------------------------------------------------------------
# To setup the DNS via the /etc/resolv.conf file
#------------------------------------------------------------------------
#grep -v "^search" /etc/resolv.conf  | grep -v "^nameserver" > /tmp/etc.resolve.conf
#echo "search your.domain.com" >> /tmp/etc.resolve.conf
#echo "nameserver 11.111.11.1" >> /tmp/etc.resolve.conf
#sudo cp -f /tmp/etc.resolve.conf /etc/resolv.conf
#rm -f /tmp/etc.resolve.conf


#------------------------------------------------------------------------
# To setup the proxy servers
#------------------------------------------------------------------------
#echo "export http_proxy=http://www-proxy.your.domain.com:80" >> ~/.bashrc
#echo "export https_proxy=http://www-proxy.your.domain.com:80" >> ~/.bashrc
#echo "set -o vi" >> ~/.bashrc


#------------------------------------------------------------------------
# To maintain the proxy environments when doing a sudo
# Add a line to the /etc/sudoers file
#------------------------------------------------------------------------
#sudo cp /etc/sudoers /etc/sudoers.orig
#sudo sed '/Defaults    env_keep += "LC_TIME LC_ALL LANGUAGE LINGUAS _XKB_CHARSET XAUTHORITY"/a Defaults    env_keep += "ftp_proxy http_proxy https_proxy no_proxy"' /etc/sudoers > /tmp/etc.sudoers.modified
#sudo cp /tmp/etc.sudoers.modified /etc/sudoers

#------------------------------------------------------------------------
# To enter permissive mode for SELinux
#------------------------------------------------------------------------
#sudo setenforce 0
