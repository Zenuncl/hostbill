#!/bin/bash

# Clear and save iptables rules
set +e
firewall-cmd --permanent --zone=public --add-service=https
firewall-cmd --permanent --zone=public --add-service=http
systemctl reload firewalld
set -e
