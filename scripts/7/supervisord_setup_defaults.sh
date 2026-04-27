#!/bin/bash


mkdir -p /etc/supervisor.d/
mkdir -p /var/log/supervisor/
rm -rf /etc/supervisor.d/*
chmod 755 /etc/supervisor.d/


cp -rf /usr/local/hostbill/etc/supervisord/supervisord.conf /etc/
cp -rf /usr/local/hostbill/etc/supervisord/supervisord.service /usr/lib/systemd/system/

chmod 755 /etc/supervisord.conf
chmod +x /etc/init.d/supervisord

systemctl enable supervisord