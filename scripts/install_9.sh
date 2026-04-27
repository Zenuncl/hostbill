#!/bin/bash
clear

# HostBill Platform Installation Script, Enterprise Edition
# CentOS Linux/Stream 9 +  php-8.1
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

	grep "CentOS Linux release 9." /etc/redhat-release -i -q;
	OS=`echo $?`;
	grep "Rocky Linux release 9." /etc/redhat-release -i -q;
	ROCK=`echo $?`;
	grep "CentOS Stream release 9"  /etc/redhat-release -i -q;
	STREAM=`echo $?`;
	grep "AlmaLinux release 9."  /etc/redhat-release -i -q;
	ALMA=`echo $?`;


	ARCH=`uname -m`;

	if [ $OS -ne 0 ] && [ $ROCK -ne 0 ] && [ $STREAM -ne 0 ]  && [ $ALMA -ne 0 ]; then
		echo "This install script requires Centos Linux or Stream 9.x or Rocky Linux 9.x or AlmaLinux 9.x"
		exit 1
	fi
	if [ $ARCH != "x86_64" ]; then
		echo "This install script requires x86_64"
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

dnf -y update >> $LOG 2>&1
dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm >> $LOG 2>&1
dnf -y install https://rpms.remirepo.net/enterprise/remi-release-9.rpm >> $LOG 2>&1
dnf -y install dnf-plugins-core >> $LOG 2>&1
yum remove -y php-cli mod_php php-common >> $LOG 2>&1
yum -y install wget unzip curl crontabs >> $LOG 2>&1
yum -y install mariadb-server mariadb >> $LOG 2>&1

#------------------------------------------------------------------------------------------------------------------------------------

echo " [2/10] Downloading platform installation files ...."
mkdir -p /usr/local/hostbill >> $LOG 2>&1
cd /root
wget "${MIRROR}installtools.zip" -O /root/installtools.zip   >> $LOG 2>&1
unzip -o /root/installtools.zip -d /usr/local/hostbill/  >> $LOG 2>&1
/bin/rm -f /root/installtools.zip   >> $LOG 2>&1

#------------------------------------------------------------------------------------------------------------------------------------

echo " [3/10] Platform Pre-installation checks ...."

echo " Disabling system-wide default httpd " >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/8/disable_system_httpd.sh >> $LOG 2>&1

echo " Adding firewall rules " >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/8/setup_firewalld.sh >> $LOG 2>&1

#------------------------------------------------------------------------------------------------------------------------------------

echo " [4/10] Setting up /home/${USER} directory ...."

echo " Setting up /home/${USER} directory " >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/8/setup_user.sh $USER >> $LOG 2>&1

#------------------------------------------------------------------------------------------------------------------------------------

echo " [5/10] Installing webserver (nginx) ...."

dnf -y install nginx  >> $LOG 2>&1

echo " Setting up nginx defaults " >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/8/nginx_setup_defaults.sh $HST >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/nginx_self_signedssl.sh $HST >> $LOG 2>&1

echo " Setting up nginx host configuration " >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/8/nginx_add.sh $USER 9000 $HST >> $LOG 2>&1

#------------------------------------------------------------------------------------------------------------------------------------


echo " [6/10] Installing php  ...."

dnf -y module install php:remi-8.1  >> $LOG 2>&1
dnf -y install php-fpm php-cli php-json php-sodium php-xml php-bcmath php-gd php-imap php-snmp php-soap php-xml php-process php-mbstring php-pdo php-mysqlnd php-ldap	php-pecl-memcached >> $LOG 2>&1

echo " Setting up php-fpm defaults " >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/8/php-fpm_setup_defaults.sh >> $LOG 2>&1

echo " Setting up php-fpm configuration " >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/8/php-fpm_add.sh $USER 9000 >> $LOG 2>&1




echo " Installing ioncube" >> $LOG 2>&1
cd /root
wget http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.zip -O /root/ioncube.zip  >> $LOG 2>&1
unzip -o ioncube.zip >> $LOG 2>&1
cp /root/ioncube/ioncube_loader_lin_8.1.so /usr/lib64/php/modules/
chmod +x /usr/lib64/php/modules/ioncube_loader_lin_8.1.so
echo "zend_extension=ioncube_loader_lin_8.1.so" > /etc/php.d/10-ioncube.ini
/bin/rm -rf /root/ioncube* >> $LOG 2>&1


echo " [7/10] Installing memcached  ...."
yum -y  install memcached >> $LOG 2>&1




echo " [8/10] Installing certbot  ...."

#
#yum -y  install snapd >> $LOG 2>&1
#systemctl enable --now snapd.socket
#ln -s /var/lib/snapd/snap /snap
#snap wait system seed.loaded
#snap install core  >> $LOG 2>&1
#snap refresh core  >> $LOG 2>&1
#
#snap install --classic certbot  >> $LOG 2>&1
#ln -s /snap/bin/certbot /usr/bin/certbot

dnf install certbot python3-certbot-nginx -y  >> $LOG 2>&1

/bin/bash /usr/local/hostbill/scripts/logrotate.sh >> $LOG 2>&1

#------------------------------------------------------------------------------------------------------------------------------------




echo " [9/10] Getting IP address ..."  >> $LOG 2>&1
IP=`wget -qO- http://install.hostbillapp.com/ip.php`
echo " Got: $IP"  >> $LOG 2>&1



# disable sql strict mode

echo ' ' >>  /etc/my.cnf
echo '[mysqld]' >>  /etc/my.cnf
echo 'sql_mode=' >>  /etc/my.cnf


echo " [10/10] Enabling & restarting services ... "

systemctl enable mariadb
systemctl enable nginx
systemctl enable php-fpm
systemctl enable memcached

systemctl restart mariadb >> $LOG 2>&1
systemctl restart php-fpm >> $LOG 2>&1
systemctl restart nginx >> $LOG 2>&1
systemctl restart memcached >> $LOG 2>&1
#------------------------------------------------------------------------------------------------------------------------------------

echo " "
echo " Done! "

echo "-----------------------------------------------"
echo "  Installing HostBill application"
echo "-----------------------------------------------"
echo " "

set -o verbose
/usr/bin/php /usr/local/hostbill/installtools/main.php -l $LICENSE -i $IP -c memcached -h $HST


