#!/bin/bash

USER=$1

if [ -z $USER ]; then
        echo "User to add is missing";
        exit 1;
fi

useradd -m $USER


mkdir -p "/home/${USER}/public_html"
mkdir -p "/home/${USER}/var/log"
mkdir -p "/home/${USER}/var/run"

chmod o+x "/home/$USER/"
chown -R $USER:$USER "/home/$USER/"
chmod -R 0777 "/home/${USER}/var"