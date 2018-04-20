#!/bin/bash

# This file allows one to setup a newly created VM
# Add lines to this script to ensure proper functioning of the VM in your environment

# Here are some examples:

# Setup the DNS via the /etc/resolv.conf file
grep -v "^search" /etc/resolv.conf  | grep -v "^nameserver" > /tmp/etc.resolve.conf
echo "search us.oracle.com" >> /tmp/etc.resolve.conf
echo "nameserver 10.211.11.1" >> /tmp/etc.resolve.conf
sudo cp -f /tmp/etc.resolve.conf /etc/resolv.conf
rm -f /tmp/etc.resolve.conf


# Setup the proxy server 
echo "export http_proxy=http://www-proxy.us.oracle.com:80" >> ~/.bashrc
echo "export https_proxy=http://www-proxy.us.oracle.com:80" >> ~/.bashrc
echo "set -o vi" >> ~/.bashrc


# Proxy environments are maintained when doing a sudo
# Add a line to the /etc/sudoers file
sudo cp /etc/sudoers /etc/sudoers.orig
sudo sed '/Defaults    env_keep += "LC_TIME LC_ALL LANGUAGE LINGUAS _XKB_CHARSET XAUTHORITY"/a Defaults    env_keep += "ftp_proxy http_proxy https_proxy no_proxy"' /etc/sudoers > /tmp/etc.sudoers.modified
sudo cp /tmp/etc.sudoers.modified /etc/sudoers

sudo setenforce 0
