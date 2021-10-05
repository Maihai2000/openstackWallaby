#!/bin/bash -ex
#
# Khoi tao bien
# TOKEN_PASS=a
# MYSQL_PASS=a
# ADMIN_PASS=a
source config.cfg
. admin-openrc.sh

openstack user create --domain default --password-prompt placement
sleep 20

openstack role add --project service --user placement admin
sleep 5

openstack service create --name placement \
  --description "Placement API" placement
sleep 5

openstack endpoint create --region RegionOne \
  placement public http://controller:8778
sleep 5

openstack endpoint create --region RegionOne \
  placement internal http://controller:8778
sleep 5

openstack endpoint create --region RegionOne \
  placement admin http://controller:8778  
sleep 5
  
echo "##### Install keystone #####"
apt install placement-api

#/* Back-up file nova.conf
placement=/etc/placement/placement.conf
test -f $placement.orig || cp $placement $placement.orig

#Config file /etc/keystone/keystone.conf
cat << EOF > $placement
[DEFAULT]

[placement_database]
connection = mysql+pymysql://placement:$PLACEMENT_DBPASS@controller/placement

[api]
# ...
auth_strategy = keystone

[keystone_authtoken]
# ...
auth_url = http://controller:5000/v3
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = placement
password = $PLACEMENT_PASS

EOF

#
su -s /bin/sh -c "placement-manage db sync" placement
sleep 5
service apache2 restart
sleep 5
. admin-openrc.sh
echo "##### Update placement #####"
placement-status upgrade check 
sleep 5

pip3 install osc-placement
sleep 5

openstack --os-placement-api-version 1.2 resource class list --sort-column name
sleep 5

openstack --os-placement-api-version 1.6 trait list --sort-column name
