#!/bin/bash

(
flock 200

while [[ $# -gt 0 ]]
do
  echo "Adding: $1 to ~/.ssh/known_hosts"
  ssh-keygen -R $1 
  ssh-keyscan $1 | grep ecdsa-sha2 >> ~/.ssh/known_hosts
  shift
done
) 200>.tf_script_knownhost_lock
