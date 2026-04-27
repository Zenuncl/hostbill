#!/bin/bash
clear

# HostBill Platform Installation Script, Enterprise Edition
# CentOS 7, php 7.4
# Rev: 2023-02-23


MIRROR=http://install.hostbillapp.com/installv2/
LOG=/root/hostbillinstall.log
USER="hostbill"

LICENSE=$1

if [ -z $LICENSE ]; then
	echo -n "Please enter your license activation code: ";
	read LICENSE
	if [ -z $LICENSE ];	then
		echo "License code is required for install";
		exit 1;
	fi
fi

HST=$2

if [ -z $HST ]; then
       HST=`hostname`
fi

check_os()
{

	grep "CentOS Linux release 7." /etc/redhat-release -i -q;
	OS=`echo $?`;
	ARCH=`uname -m`;

	if [ $OS -ne 0 ] || [ $ARCH != "x86_64" ]; then
		echo "HostBill Enterprise requires Centos 7.x x86_64"
		exit 1
	fi
	if [ "$(whoami)" != 'root' ]; then
		echo "Please run this script as a root"
		exit 1;
	fi
	if [ ! -e /usr/bin/yum ]; then
		echo " Yum not found. Please install yum first"
		exit 1
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


echo "-----------------------------------------------"
echo " Welcome to HostBill Installer: Installing Platform"
echo "-----------------------------------------------"
echo " "

check_os
setenforce 0 >> $LOG 2>&1


set -e

echo " Log File: $LOG"
echo " "

echo " [1/10] Installing base dependencies ...."
yum remove -y php-cli mod_php php-common >> $LOG 2>&1
yum -y install wget unzip curl crontabs >> $LOG 2>&1
rpm -Uvh --force https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm >> $LOG 2>&1
rpm -Uvh --force https://rpms.remirepo.net/enterprise/remi-release-7.rpm >> $LOG 2>&1
yum -y install mariadb-server mariadb-devel mariadb >> $LOG 2>&1

#------------------------------------------------------------------------------------------------------------------------------------

echo " [2/10] Downloading platform installation files ...."
mkdir -p /usr/local/hostbill >> $LOG 2>&1
cd /root
wget "${MIRROR}installtools.zip" -O /root/installtools.zip   >> $LOG 2>&1
unzip -o /root/installtools.zip -d /usr/local/hostbill/  >> $LOG 2>&1
/bin/rm -f /root/installtools.zip   >> $LOG 2>&1
# tar/unzip

#------------------------------------------------------------------------------------------------------------------------------------

echo " [3/10] Platform Pre-installation checks ...."

echo " Disabling selinux " >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/7/disable_selinux.sh >> $LOG 2>&1

echo " Disabling system-wide default httpd " >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/7/disable_system_httpd.sh >> $LOG 2>&1

echo " Disabling firewalld " >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/7/flush_iptables.sh >> $LOG 2>&1

#------------------------------------------------------------------------------------------------------------------------------------

echo " [4/10] Setting up /home/${USER} directory ...."

echo " Setting up /home/${USER} directory " >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/7/setup_user.sh $USER >> $LOG 2>&1

#------------------------------------------------------------------------------------------------------------------------------------

echo " [5/10] Installing webserver (nginx) ...."

yum -y install nginx  >> $LOG 2>&1
echo " Setting up nginx defaults " >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/7/nginx_setup_defaults.sh $HST >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/nginx_self_signedssl.sh $HST >> $LOG 2>&1

echo " Setting up nginx host configuration " >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/7/nginx_add.sh $USER 9000 $HST >> $LOG 2>&1

#------------------------------------------------------------------------------------------------------------------------------------


echo " [6/10] Installing php  ...."
yum -y install yum-utils >> $LOG 2>&1
yum-config-manager --enable remi-php74 >> $LOG 2>&1
yum -y install php-fpm php-cli php-mcrypt php-gd php-json php-imap php-snmp php-soap php-sodium php-xml php-process php-mbstring php-pdo php-mysqlnd php-ldap	php-pecl-memcached  >> $LOG 2>&1

echo " Setting up php-fpm defaults " >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/7/php-fpm_setup_defaults.sh >> $LOG 2>&1

echo " Setting up php-fpm configuration " >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/7/php-fpm_add.sh $USER 9000 >> $LOG 2>&1




echo " Installing ioncube" >> $LOG 2>&1
cd /root
wget http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.zip -O /root/ioncube.zip  >> $LOG 2>&1
unzip -o ioncube.zip >> $LOG 2>&1
cp /root/ioncube/ioncube_loader_lin_7.4.so /usr/lib64/php/modules/
chmod +x /usr/lib64/php/modules/ioncube_loader_lin_7.4.so
echo "zend_extension=ioncube_loader_lin_7.4.so" > /etc/php.d/10-ioncube.ini
/bin/rm -rf /root/ioncube* >> $LOG 2>&1


echo " [7/10] Installing memcached  ...."
yum -y  install memcached >> $LOG 2>&1



echo " [8/10] Installing redis  ...."
echo " ...skip"
#yum -y  install redis php-pecl-redis >> $LOG 2>&1


echo " [9/10] Installing certbot  ...."


#yum -y  install snapd >> $LOG 2>&1
#systemctl enable --now snapd.socket
#ln -s /var/lib/snapd/snap /snap
#snap wait system seed.loaded
#snap install core  >> $LOG 2>&1
#snap refresh core  >> $LOG 2>&1
#
#snap install --classic certbot  >> $LOG 2>&1
#ln -s /snap/bin/certbot /usr/bin/certbot

yum -y install  certbot python2-certbot-nginx  >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/logrotate.sh >> $LOG 2>&1

#------------------------------------------------------------------------------------------------------------------------------------




echo " Getting IP address ..."  >> $LOG 2>&1
IP=`wget -qO- http://install.hostbillapp.com/ip.php`
echo " Got: $IP"  >> $LOG 2>&1



systemctl enable mariadb
systemctl enable nginx
systemctl enable php-fpm
systemctl enable memcached
#systemctl enable redis


echo 'OPTIONS="-U 0 -l 127.0.0.1"' >> /etc/sysconfig/memcached

echo " [10/10] Restarting services ... "
systemctl restart mariadb >> $LOG 2>&1
systemctl restart php-fpm >> $LOG 2>&1
systemctl restart nginx >> $LOG 2>&1
systemctl restart memcached >> $LOG 2>&1
#systemctl restart redis >> $LOG 2>&1
#systemctl restart supervisord >> $LOG 2>&1
#------------------------------------------------------------------------------------------------------------------------------------

echo " "
echo " Done! "

echo "-----------------------------------------------"
echo "  Installing application"
echo "-----------------------------------------------"
echo " "

set -o verbose
/usr/bin/php /usr/local/hostbill/installtools/main.php -l $LICENSE -i $IP -c memcached -h $HST


