#!/bin/bash

HST=$1


if [ -z $HST ]; then
       HST=`hostname`
fi


mkdir -p /etc/ssl/private/
mkdir -p /etc/ssl/certs/
chmod 700 /etc/ssl/private


openssl req \
    -new \
    -newkey rsa:2048 \
    -days 365 \
    -nodes \
    -x509 \
    -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=${HST}" \
    -keyout /etc/ssl/private/nginx-selfsigned.key \
    -out /etc/ssl/certs/nginx-selfsigned.crt

#openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048