#!/bin/bash -ex
#
# Khoi tao bien
# TOKEN_PASS=a
# MYSQL_PASS=a
# ADMIN_PASS=a
source config.cfg

echo "##### Install keystone #####"
apt install keystone

#/* Back-up file nova.conf
filekeystone=/etc/keystone/keystone.conf
test -f $filekeystone.orig || cp $filekeystone $filekeystone.orig

#Config file /etc/keystone/keystone.conf
cat << EOF > $filekeystone
[DEFAULT]
verbose = True
log_dir=/var/log/keystone
admin_token = $TOKEN_PASS

[assignment]
[auth]
[cache]
[catalog]
[credential]

[database]

connection = mysql+pymysql://keystone:$KEYSTONE_DBPASS@controller/keystone

[ec2]
[endpoint_filter]
[endpoint_policy]
[federation]
[identity]
[identity_mapping]
[kvs]
[ldap]
[matchmaker_redis]
[matchmaker_ring]
[memcache]
[oauth1]
[os_inherit]
[paste_deploy]
[policy]
[revoke]
[saml]
[signing]
[ssl]
[stats]
[token]
provider = fernet

[trust]
[extra_headers]
Distribution = Ubuntu

EOF

#
su -s /bin/sh -c "keystone-manage db_sync" keystone
sleep 5
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
sleep 5
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
echo "##### Syncing keystone DB #####"
sleep 3
keystone-manage bootstrap --bootstrap-password $ADMIN_PASS \
  --bootstrap-admin-url http://controller:5000/v3/ \
  --bootstrap-internal-url http://controller:5000/v3/ \
  --bootstrap-public-url http://controller:5000/v3/ \
  --bootstrap-region-id RegionOne
  
sleep 5
service apache2 restart

. export.sh

openstack domain create --description "An Example Domain" example
sleep 5
echo "Create service project:"
openstack project create --domain default \
  --description "Service Project" service
sleep 5
echo "Create the myproject project:"
openstack project create --domain default \
  --description "Demo Project" myproject
sleep 5  
echo "Create the myuser user:"
openstack user create --domain default \
  --password-prompt myuser
sleep 5  
echo "Create the myrole role:"  
openstack role create myrole  
sleep 5  
openstack role add --project myproject --user myuser myrole