#!/bin/bash
(
flock 200
  echo "Adding: $1 $2  to /etc/hosts"
  sudo sed -i "/$2/d" /etc/hosts
  sudo sh -c "echo $1 $2 >> /etc/hosts"
) 200>.tf_script_etchost_lock
