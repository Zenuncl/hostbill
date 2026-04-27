#!/bin/bash

# Stop and disable httpd
set +e
/usr/bin/systemctl disable httpd
/usr/bin/systemctl stop httpd

set -e

