#!/bin/bash

MIRROR=http://install.hostbillapp.com/installv2/

LICENSE=$1

if [ -z $LICENSE ]; then
	echo -n "Please enter your license activation code: ";
	read LICENSE
	if [ -z $LICENSE ];	then
		echo "License code is required for install";
		exit 1;
	fi
fi

# Detect os, downlod valid installer
check_defaults()
{


	if [ "$(whoami)" != 'root' ]; then
		echo "Please run this script as a root"
		exit 1;
	fi
	
	if [ -e /usr/local/cpanel ]; then
		echo " cPanel found, installation is possible only on clean CentOS system."
		exit 1
	fi
	if [ -e /usr/local/directadmin ]; then
		echo " DirectAdmin found, installation is possible only on clean CentOS system."
		exit 1
	fi
}
detect_os()
{
    OS=$(uname)
    ID='unknown'
    CODENAME='unknown'
    RELEASE='unknown'
    ARCH='unknown'

    # detect centos
    grep 'centos' /etc/issue -i -q
    if [ $? = '0' ]; then
        ID='centos'
        RELEASE=$(cat /etc/redhat-release | grep -o 'release [0-9]' | cut -d " " -f2)
    elif [ -f '/etc/redhat-release' ]; then
        ID='centos'
        RELEASE=$(cat /etc/redhat-release | grep -o 'release [0-9]' | cut -d " " -f2)
    # could be debian or ubuntu
    elif [ $(which lsb_release) ]; then
        ID=$(lsb_release -i | cut -f2)
        CODENAME=$(lsb_release -c | cut -f2)
        RELEASE=$(lsb_release -r | cut -f2)
    elif [ -f '/etc/lsb-release' ]; then
        ID=$(cat /etc/lsb-release | grep DISTRIB_ID | cut -d "=" -f2)
        CODENAME=$(cat /etc/lsb-release | grep DISTRIB_CODENAME | cut -d "=" -f2)
        RELEASE=$(cat /etc/lsb-release | grep DISTRIB_RELEASE | cut -d "=" -f2)
    elif [ -f '/etc/issue' ]; then
        ID=$(head -1 /etc/issue | cut -d " " -f1)
        if [ -f '/etc/debian_version' ]; then
          RELEASE=$(</etc/debian_version)
        else
          RELEASE=$(head -1 /etc/issue | cut -d " " -f2)
        fi
    fi
}

check_defaults
detect_os

if [ "$ID" == 'centos' ]; then

        if [ "$RELEASE" -lt 7 ]; then
                echo "Sorry, your CentOS version is not supported by easy install"
                exit 1;
        fi

        if [ ! -e /usr/bin/yum ]; then
            echo " Yum not found. Please install yum first"
            exit 1
        fi



        echo " Installing wget / curl ..."
        yum -y install wget curl > /dev/null 2>&1


        echo " Getting Install script for your OS ..."
        wget "${MIRROR}install_${RELEASE}.sh" -O /root/hb_baseinstall.sh  > /dev/null 2>&1



else

        echo "Sorry, easy install scripts for HostBill requires CentOS or Debian"
        exit 1;

fi




/bin/bash /root/hb_baseinstall.sh $LICENSE