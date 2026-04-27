#!/bin/bash
clear

# HostBill Platform Installation Script, Enterprise Edition
# Debian 8
# Rev: 2018-03-16


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


	ID=$(lsb_release -i | cut -f2)
    CODENAME=$(lsb_release -c | cut -f2)
    RELEASE=$(lsb_release -r | cut -f2)
	
	ARCH=`uname -m`;

	if [ "$ID" != 'Debian' ] || [ $ARCH != "x86_64" ]; then
		echo "HostBill Enterprise requires Debian 8.x x86_64"
		exit 1
	fi
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


echo "-----------------------------------------------"
echo " Welcome to HostBill Installer: Installing Platform"
echo "-----------------------------------------------"
echo " "

check_os



set -e

echo " Log File: $LOG"
echo " "

echo " [1/10] Installing base dependencies ...."

export DEBIAN_FRONTEND=noninteractive

echo 'deb http://packages.dotdeb.org jessie all' >> /etc/apt/sources.list
echo 'deb-src http://packages.dotdeb.org jessie all' >> /etc/apt/sources.list

wget https://www.dotdeb.org/dotdeb.gpg -O  /tmp/dotdeb.gpg  >> $LOG 2>&1
apt-key add /tmp/dotdeb.gpg  >> $LOG 2>&1

apt-get update -y >> $LOG 2>&1
x="$(dpkg --list | grep php | awk '/^ii/{ print $2}')"
apt-get --purge remove $x  -y >> $LOG 2>&1

apt-get install unzip cron snmp -y >> $LOG 2>&1

apt-get install mariadb-server mariadb-client -y >> $LOG 2>&1


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

echo " Flushing iptables" >> $LOG 2>&1

set +e

iptables --flush
service iptables save

set -e

#------------------------------------------------------------------------------------------------------------------------------------

echo " [4/10] Setting up /home/${USER} directory ...."

echo " Setting up /home/${USER} directory " >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/7/setup_user.sh $USER >> $LOG 2>&1

#------------------------------------------------------------------------------------------------------------------------------------

echo " [5/10] Installing webserver (nginx) ...."

apt-get install nginx -y >> $LOG 2>&1
echo " Setting up nginx defaults " >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/debian8/nginx_setup_defaults.sh $HST >> $LOG 2>&1

echo " Setting up nginx host configuration " >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/debian8/nginx_add.sh $USER 9000 $HST >> $LOG 2>&1

#------------------------------------------------------------------------------------------------------------------------------------


echo " [6/10] Installing php  ...."
apt-get install -y php7.0 php7.0-fpm php7.0-cli php7.0-mcrypt php7.0-gd  php7.0-snmp php7.0-json php7.0-imap php7.0-memcached php7.0-soap php7.0-xml php7.0-xmlrpc php7.0-mbstring php7.0-mysqlnd php7.0-curl	 >> $LOG 2>&1



#todo!
echo " Setting up php-fpm defaults " >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/debian8/php-fpm_setup_defaults.sh >> $LOG 2>&1

echo " Setting up php-fpm configuration " >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/debian8/php-fpm_add.sh $USER 9000 >> $LOG 2>&1




echo " Installing ioncube" >> $LOG 2>&1
cd /root
wget http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.zip -O /root/ioncube.zip  >> $LOG 2>&1
unzip -o ioncube.zip >> $LOG 2>&1
cp /root/ioncube/ioncube_loader_lin_7.0.so /usr/lib/php/
chmod +x /usr/lib/php/ioncube_loader_lin_7.0.so
echo "zend_extension=/usr/lib/php/ioncube_loader_lin_7.0.so" > /etc/php/7.0/mods-available/ioncube.ini
#todo - ln -s !
cd /etc/php/7.0/cli/conf.d/
ln -s /etc/php/7.0/mods-available/ioncube.ini 10-ioncube.ini
cd /etc/php/7.0/fpm/conf.d/
ln -s /etc/php/7.0/mods-available/ioncube.ini 10-ioncube.ini

/bin/rm -rf /root/ioncube* >> $LOG 2>&1

cd /root



echo " [7/10] Installing memcached  ...."
apt-get install -y   memcached >> $LOG 2>&1





echo " [9/10] Installing supervisord  ...."
echo " ... skip ..."
#yum -y  install python-setuptools >> $LOG 2>&1
#/usr/bin/easy_install pip >> $LOG 2>&1
#/usr/bin/easy_install supervisor >> $LOG 2>&1
#pip install supervisor >> $LOG 2>&1

#echo " Setting up supervisord defaults " >> $LOG 2>&1
#/bin/bash /usr/local/hostbill/scripts/7/supervisord_setup_defaults.sh >> $LOG 2>&1



#------------------------------------------------------------------------------------------------------------------------------------




echo " Getting IP address ..."  >> $LOG 2>&1
IP=`wget -qO- http://install.hostbillapp.com/ip.php`
echo " Got: $IP"  >> $LOG 2>&1



systemctl enable mysql
systemctl enable nginx
systemctl enable php7.0-fpm
systemctl enable memcached




echo " [10/10] Restarting services ... "
systemctl restart mysql >> $LOG 2>&1
systemctl restart php7.0-fpm >> $LOG 2>&1
systemctl restart nginx >> $LOG 2>&1
systemctl restart memcached >> $LOG 2>&1
#------------------------------------------------------------------------------------------------------------------------------------

echo " "
echo " Done! "

echo "-----------------------------------------------"
echo "  Installing application"
echo "-----------------------------------------------"
echo " "

set -o verbose
/usr/bin/php /usr/local/hostbill/installtools/main.php -l $LICENSE -i $IP -c memcached  -h $HST