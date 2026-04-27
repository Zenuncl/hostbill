#!/bin/bash

HST=$1

if [ -z $HST ]; then
       HST="_"
fi

rm -rf /etc/nginx/conf.d/*
rm -rf /etc/nginx/default.d/*
mkdir -p /etc/nginx/upstreams
mkdir -p /etc/nginx/locations


cp -rf /usr/local/hostbill/etc/nginx/nginx.conf /etc/nginx/
cp -rf /usr/local/hostbill/etc/nginx/main.conf /etc/nginx/conf.d/
cp -rf /usr/local/hostbill/etc/nginx/ssl.conf /etc/nginx/

sed -i "s/user nginx/user www-data/g" "/etc/nginx/nginx.conf"

sed -i "s/--hostname--/${HST}/g" "/etc/nginx/conf.d/main.conf"
