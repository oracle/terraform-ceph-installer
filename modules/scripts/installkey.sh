#!/bin/bash

ssh $1 -o "StrictHostKeyChecking no" -l opc 'cat ~/.ssh/id_rsa.pub' | ssh $2 -o "StrictHostKeyChecking no" -l opc 'cat >> .ssh/authorized_keys'
sleep 5
