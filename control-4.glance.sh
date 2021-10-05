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
verbose = True
default_store = file
bind_host = 0.0.0.0
bind_port = 9292
log_file = /var/log/glance/api.log
backlog = 4096
registry_host = 0.0.0.0
registry_port = 9191
registry_client_protocol = http
rabbit_host = $CON_MGNT_IP
rabbit_port = 5672
rabbit_use_ssl = false
rabbit_userid = guest
rabbit_password = guest
rabbit_virtual_host = /
rabbit_notification_exchange = glance
rabbit_notification_topic = notifications
rabbit_durable_queues = False
qpid_notification_exchange = glance
qpid_notification_topic = notifications
qpid_hostname = localhost
qpid_port = 5672
qpid_username =
qpid_password =
qpid_sasl_mechanisms =
qpid_reconnect_timeout = 0
qpid_reconnect_limit = 0
qpid_reconnect_interval_min = 0
qpid_reconnect_interval_max = 0
qpid_reconnect_interval = 0
qpid_heartbeat = 5
qpid_protocol = tcp
qpid_tcp_nodelay = True
delayed_delete = False
scrub_time = 43200
scrubber_datadir = /var/lib/glance/scrubber
image_cache_dir = /var/lib/glance/image-cache/

[database]
connection = mysql+pymysql://glance:G$GLANCE_DBPASS@controller/glance

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

swift_store_auth_version = 2
swift_store_auth_address = 127.0.0.1:5000/v2.0/
swift_store_user = jdoe:jdoe
swift_store_key = a86850deb2742ec3cb41518e26aa2d89
swift_store_container = glance
swift_store_create_container_on_put = False
swift_store_large_object_size = 5120
swift_store_large_object_chunk_size = 200
swift_enable_snet = False
s3_store_host = 127.0.0.1:8080/v1.0/
s3_store_access_key = <20-char AWS access key>
s3_store_secret_key = <40-char AWS secret key>
s3_store_bucket = <lowercased 20-char aws access key>glance
s3_store_create_bucket_on_put = False
sheepdog_store_address = localhost
sheepdog_store_port = 7000
sheepdog_store_chunk_size = 64

EOF

#
sleep 10
echo "########## Configuring GLANCE REGISTER ##########"
#/* Backup file file glance-registry.conf
fileglanceregcontrol=/etc/glance/glance-registry.conf
test -f $fileglanceregcontrol.orig || cp $fileglanceregcontrol $fileglanceregcontrol.orig
rm $fileglanceregcontrol
touch $fileglanceregcontrol
#Config file /etc/glance/glance-registry.conf

cat << EOF > $fileglanceregcontrol

[database]
connection = mysql://glance:$GLANCE_DBPASS@$CON_MGNT_IP/glance
backend = sqlalchemy

[keystone_authtoken]
www_authenticate_uri = http://controller:5000
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = glance
password = $GLANCE_PASS

[paste_deploy]
flavor = keystone

[glance_store]
stores = file,http
default_store = file
filesystem_store_datadir = /var/lib/glance/images/

[profiler]
EOF

sleep 7
echo "########## Remove Glance default DB ##########"
# rm /var/lib/glance/glance.sqlite
su -s /bin/sh -c "glance-manage db_sync" glance
sleep 7


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
