#!/bin/bash -ex
#
source config.cfg
. admin-openrc
echo "########## Install NOVA in controller ##########"
openstack user create --domain default --password-prompt nova
sleep 20

openstack role add --project service --user nova adminapt-get install libguestfs-tools -y
sleep 5

openstack service create --name nova \
  --description "OpenStack Compute" compute
sleep 5

openstack endpoint create --region RegionOne \
  compute public http://controller:8774/v2.1  
sleep 5

openstack endpoint create --region RegionOne \
  compute internal http://controller:8774/v2.1  
sleep 5  

openstack endpoint create --region RegionOne \
  compute admin http://controller:8774/v2.1
sleep 5
echo "Install the packages:"
apt install nova-api nova-conductor nova-novncproxy nova-scheduler  
sleep 7
 
######## Backup configurations for NOVA ##########"

#
controlnova=/etc/nova/nova.conf
test -f $controlnova.orig || cp $controlnova $controlnova.orig
rm $controlnova
touch $controlnova
cat << EOF >> $controlnova
[DEFAULT]
transport_url = rabbit://openstack:$RABBIT_PASS@controller:5672/

[neutron]
url = http://$CON_MGNT_IP:9696
auth_strategy = keystone
admin_auth_url = http://$CON_MGNT_IP:35357/v2.0
admin_tenant_name = service
admin_username = neutron
admin_password = $NEUTRON_PASS
service_metadata_proxy = True
metadata_proxy_shared_secret = $METADATA_SECRET


[glance]
host = $CON_MGNT_IP

[api_database]
# ...
connection = mysql+pymysql://nova:$NOVA_DBPASS@controller/nova_api

[database]
# ...
connection = mysql+pymysql://nova:NOVA_DBPASS@controller/nova

[api]
# ...
auth_strategy = keystone

[keystone_authtoken]
# ...
www_authenticate_uri = http://controller:5000/
auth_url = http://controller:5000/
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = nova
password = $NOVA_PASS

[vnc]
enabled = true

[glance]
# ...
api_servers = http://controller:9292

[oslo_concurrency]
# ...
lock_path = /var/lib/nova/tmp

[placement]
# ...
region_name = RegionOne
project_domain_name = Default
project_name = service
auth_type = password
user_domain_name = Default
auth_url = http://controller:5000/v3
username = placement
password = $PLACEMENT_PASS

[neutron]
# ...
auth_url = http://controller:5000
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = neutron
password = $NEUTRON_PASS
service_metadata_proxy = true
metadata_proxy_shared_secret = $METADATA_SECRET

EOF


sleep 7
su -s /bin/sh -c "nova-manage api_db sync" nova
su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
su -s /bin/sh -c "nova-manage db sync" nova

echo "########## Syncing Nova DB ##########"
sleep 7 
su -s /bin/sh -c "nova-manage cell_v2 list_cells" nova



echo "########## Restarting NOVA ... ##########"
sleep 7 
service nova-api restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart
sleep 7 
apt install nova-compute
sleep 10
egrep -c '(vmx|svm)' /proc/cpuinfo
computernova=/etc/nova/nova-compute.conf
test -f $computernova.orig || cp $computernova $computernova.orig
rm $computernova
touch $computernova
cat << EOF >> $computernova
[libvirt]
# ...
virt_type = qemu
EOF
service nova-compute restart
. admin-openrc.sh
openstack compute service list --service nova-compute
sleep 5

su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova
echo "########## Testing NOVA service ##########"
openstack compute service list

