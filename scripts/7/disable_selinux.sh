#!/bin/bash

# Disable selinux permanently
setenforce 0

/bin/cp -rf  /usr/local/hostbill/etc/selinux/config   /etc/selinux/config

