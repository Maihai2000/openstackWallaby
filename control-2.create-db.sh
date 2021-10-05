#!/bin/bash -ex

#Khai bao bien
source config.cfg
 
echo "##### Install MYSQL #####"
#ubuntu18.04
#apt install mariadb-server python-pymysql
#ubuntu20.04
apt install mariadb-server python3-pymysql
sleep 3

echo mysql-server mysql-server/root_password password $MYSQL_PASS | debconf-set-selections
echo mysql-server mysql-server/root_password_again password $MYSQL_PASS | debconf-set-selections
apt-get -y install mariadb-server python-mysqldb curl 

echo "##### Configuring MYSQL #####"
sleep 3


echo "########## CONFIGURING FOR MYSQL ##########"
sleep 5
sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/my.cnf
#
sed -i "/bind-address/a\default-storage-engine = innodb\n\
innodb_file_per_table\n\
collation-server = utf8_general_ci\n\
init-connect = 'SET NAMES utf8'\n\
character-set-server = utf8" /etc/mysql/my.cnf

#
service mysql restart


echo "##### Create OPS DATABASE #####"
sleep 3

cat << EOF | mysql -uroot -p$MYSQL_PASS
DROP DATABASE IF EXISTS keystone;
DROP DATABASE IF EXISTS glance;
DROP DATABASE IF EXISTS nova_api;
DROP DATABASE IF EXISTS nova;
DROP DATABASE IF EXISTS nova_cell0;
DROP DATABASE IF EXISTS cinder;
DROP DATABASE IF EXISTS neutron;
#
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' \
IDENTIFIED BY '$KEYSTONE_DBPASS';

GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' \
IDENTIFIED BY '$KEYSTONE_DBPASS';
#
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' \
  IDENTIFIED BY '$GLANCE_DBPASS';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' \
  IDENTIFIED BY '$GLANCE_DBPASS';
  
#
CREATE DATABASE placement;
GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'localhost' \
  IDENTIFIED BY '$PLACEMENT_DBPASS';
GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' \
  IDENTIFIED BY '$PLACEMENT_DBPASS';
  
#
CREATE DATABASE nova_api;
CREATE DATABASE nova;
CREATE DATABASE nova_cell0;

GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' \
  IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' \
  IDENTIFIED BY '$NOVA_DBPASS';

GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' \
  IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' \
  IDENTIFIED BY '$NOVA_DBPASS';

GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' \
  IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' \
  IDENTIFIED BY '$NOVA_DBPASS';  
#
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' \
  IDENTIFIED BY '$NEUTRON_DBPASS';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' \
  IDENTIFIED BY '$NEUTRON_DBPASS';


#
FLUSH PRIVILEGES;
EOF
#
echo "##### Finish setup and config OPS DB !! #####"
exit;