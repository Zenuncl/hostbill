#!/bin/bash
clear

# HostBill Platform Installation Script, Enterprise Edition
# Debian 13 (Trixie) + php-8.1
# Rev: 2024-01-01


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

	if [ "$ID" != 'Debian' ] || [ "$CODENAME" != 'trixie' ]; then
		echo "This install script requires Debian 13 (Trixie) x86_64"
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
	if [ ! -e /usr/bin/apt-get ]; then
		echo " apt-get not found. Please install apt-get first"
		exit 1
	fi
	if [ -e /usr/local/cpanel ]; then
		echo " cPanel found, installation is possible only on clean Debian system."
		exit 1
	fi
	if [ -e /usr/local/directadmin ]; then
		echo " DirectAdmin found, installation is possible only on clean Debian system."
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

apt-get update -y >> $LOG 2>&1

# Remove any existing PHP packages
x="$(dpkg --list | grep php | awk '/^ii/{ print $2}')"
if [ -n "$x" ]; then
	apt-get --purge remove $x -y >> $LOG 2>&1
fi

# Install prerequisites for adding sury PHP repository
apt-get install -y apt-transport-https lsb-release ca-certificates curl wget gnupg2 >> $LOG 2>&1

# Add Ondrej Sury PHP repository (sury.org) for PHP 8.1
wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg >> $LOG 2>&1
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list

apt-get update -y >> $LOG 2>&1

apt-get install -y unzip cron snmp >> $LOG 2>&1
apt-get install -y mariadb-server mariadb-client >> $LOG 2>&1

#------------------------------------------------------------------------------------------------------------------------------------

echo " [2/10] Downloading platform installation files ...."
mkdir -p /usr/local/hostbill >> $LOG 2>&1
#cd /root
#wget "${MIRROR}installtools.zip" -O /root/installtools.zip   >> $LOG 2>&1
#unzip -o /root/installtools.zip -d /usr/local/hostbill/  >> $LOG 2>&1
#/bin/rm -f /root/installtools.zip   >> $LOG 2>&1

cp -rf ./etc /usr/local/hostbill/ >> $LOG 2>&1
cp -rf ./installtools /usr/local/hostbill/ >> $LOG 2>&1
cp -rf ./scripts /usr/local/hostbill/ >> $LOG 2>&1

#------------------------------------------------------------------------------------------------------------------------------------

echo " [3/10] Platform Pre-installation checks ...."

echo " Disabling system-wide default apache2 " >> $LOG 2>&1
set +e
/usr/bin/systemctl disable apache2 >> $LOG 2>&1
/usr/bin/systemctl stop apache2 >> $LOG 2>&1
set -e

echo " Setting up firewall rules " >> $LOG 2>&1
set +e
apt-get install -y ufw >> $LOG 2>&1
ufw allow http >> $LOG 2>&1
ufw allow https >> $LOG 2>&1
ufw --force enable >> $LOG 2>&1
set -e

#------------------------------------------------------------------------------------------------------------------------------------

echo " [4/10] Setting up /home/${USER} directory ...."

echo " Setting up /home/${USER} directory " >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/8/setup_user.sh $USER >> $LOG 2>&1

#------------------------------------------------------------------------------------------------------------------------------------

echo " [5/10] Installing webserver (nginx) ...."

apt-get install -y nginx >> $LOG 2>&1

echo " Setting up nginx defaults " >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/debian13/nginx_setup_defaults.sh $HST >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/nginx_self_signedssl.sh $HST >> $LOG 2>&1

echo " Setting up nginx host configuration " >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/debian13/nginx_add.sh $USER 9000 $HST >> $LOG 2>&1

#------------------------------------------------------------------------------------------------------------------------------------

echo " [6/10] Installing php  ...."

apt-get install -y php8.1 php8.1-fpm php8.1-cli php8.1-json php8.1-sodium php8.1-xml php8.1-bcmath php8.1-gd php8.1-imap php8.1-snmp php8.1-soap php8.1-mbstring php8.1-mysql php8.1-ldap php8.1-curl php8.1-memcached >> $LOG 2>&1

echo " Setting up php-fpm defaults " >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/debian13/php-fpm_setup_defaults.sh >> $LOG 2>&1

echo " Setting up php-fpm configuration " >> $LOG 2>&1
/bin/bash /usr/local/hostbill/scripts/debian13/php-fpm_add.sh $USER 9000 >> $LOG 2>&1


echo " Installing ioncube" >> $LOG 2>&1
cd /root
wget http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.zip -O /root/ioncube.zip  >> $LOG 2>&1
unzip -o ioncube.zip >> $LOG 2>&1
cp /root/ioncube/ioncube_loader_lin_8.1.so /usr/lib/php/20210902/
chmod +x /usr/lib/php/20210902/ioncube_loader_lin_8.1.so
echo "zend_extension=/usr/lib/php/20210902/ioncube_loader_lin_8.1.so" > /etc/php/8.1/mods-available/ioncube.ini
ln -sf /etc/php/8.1/mods-available/ioncube.ini /etc/php/8.1/cli/conf.d/10-ioncube.ini
ln -sf /etc/php/8.1/mods-available/ioncube.ini /etc/php/8.1/fpm/conf.d/10-ioncube.ini
/bin/rm -rf /root/ioncube* >> $LOG 2>&1

cd /root


echo " [7/10] Installing memcached  ...."
apt-get install -y memcached >> $LOG 2>&1


echo " [8/10] Installing certbot  ...."

apt-get install -y certbot python3-certbot-nginx >> $LOG 2>&1

/bin/bash /usr/local/hostbill/scripts/logrotate.sh >> $LOG 2>&1

#------------------------------------------------------------------------------------------------------------------------------------


echo " [9/10] Getting IP address ..."  >> $LOG 2>&1
IP=`wget -qO- http://install.hostbillapp.com/ip.php`
echo " Got: $IP"  >> $LOG 2>&1


# disable sql strict mode
echo ' ' >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo '[mysqld]' >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo 'sql_mode=' >> /etc/mysql/mariadb.conf.d/50-server.cnf


echo " [10/10] Enabling & restarting services ... "

systemctl enable mariadb
systemctl enable nginx
systemctl enable php8.1-fpm
systemctl enable memcached

systemctl restart mariadb >> $LOG 2>&1
systemctl restart php8.1-fpm >> $LOG 2>&1
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
