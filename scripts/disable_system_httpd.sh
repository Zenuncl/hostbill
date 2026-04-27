#!/bin/bash

# Stop and disable httpd
set +e
/etc/init.d/httpd stop
chkconfig httpd off

set -e

