#!/bin/bash

# Clear and save iptables rules
set +e

systemctl stop  firewalld
systemctl disable firewalld

set -e
