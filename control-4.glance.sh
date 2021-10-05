#!/bin/bash -ex
#
source config.cfg
. admin-openrc.sh

openstack user create --domain default --password-prompt glance
sleep 20
openstack role add --project service --user glance admin
sleep 5
openstack service create --name glance \
  --description "OpenStack Image" image
sleep 5

openstack endpoint create --region RegionOne \
  image public http://controller:9292  
sleep 5

openstack endpoint create --region RegionOne \
  image internal http://controller:9292
sleep 5

openstack endpoint create --region RegionOne \
  image admin http://controller:9292
sleep 5
  
echo "########## Install GLANCE ##########"
apt install glance
sleep 10
echo "########## Configuring GLANCE API ##########"
sleep 5 
#/* Back-up file nova.conf
fileglanceapicontrol=/etc/glance/glance-api.conf
test -f $fileglanceapicontrol.orig || cp $fileglanceapicontrol $fileglanceapicontrol.orig
rm $fileglanceapicontrol
touch $fileglanceapicontrol

#Configuring glance config file /etc/glance/glance-api.conf

cat << EOF > $fileglanceapicontrol
[DEFAULT]


[database]
connection = mysql+pymysql://glance:$GLANCE_DBPASS@controller/glance

[keystone_authtoken]
auth_uri = http://$CON_MGNT_IP:5000/v2.0
identity_uri = http://$CON_MGNT_IP:35357
admin_tenant_name = service
admin_user = glance
admin_password = $GLANCE_PASS
 
[paste_deploy]
flavor = keystone

[store_type_location_strategy]
[profiler]
[task]

[glance_store]
default_store = file
filesystem_store_datadir = /var/lib/glance/images/

EOF
su -s /bin/sh -c "glance-manage db_sync" glance

echo "########## Restarting GLANCE service ... ##########"
service glance-api restart
sleep 3
. admin-openrc.sh
wget http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img
sleep 10

glance image-create --name "cirros" \
  --file cirros-0.4.0-x86_64-disk.img \
  --disk-format qcow2 --container-format bare \
  --visibility=public
sleep 10

echo "########## Testing Glance ##########"
glance image-list  

#
