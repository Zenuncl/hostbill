#!/bin/bash

USER=$1

if [ -z $USER ]; then
        echo "Username is required";
        exit 1;
fi

if [ -z $PORT ]; then
       PORT=9000
fi

/bin/cp -f /usr/local/hostbill/etc/nginx/template.conf "/etc/nginx/locations/${USER}.conf"


sed -i "s/--id--/${USER}/g" "/etc/nginx/locations/${USER}.conf"
sed -i "s/--port--/${PORT}/g" "/etc/nginx/locations/${USER}.conf"



