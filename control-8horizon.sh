#!/bin/bash -ex

source config.cfg

###################
echo "########## START INSTALLING OPS DASHBOARD ##########"
###################
sleep 5

echo "########## Installing Dashboard package ##########"
apt install openstack-dashboard

echo "########## Fix bug in apache2 ##########"
sleep 5


echo "########## Creating redirect page ##########"

localsettings=/etc/openstack-dashboard/local_settings.py
test -f $localsettings.orig || cp $localsettings $localsettings.orig
rm $localsettings
touch $localsettings
cat << EOF >> $localsettings
OPENSTACK_HOST = "controller"
ALLOWED_HOSTS = ['one.example.com', 'two.example.com']
SESSION_ENGINE = 'django.contrib.sessions.backends.cache'

CACHES = {
    'default': {
         'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
         'LOCATION': 'controller:11211',
    }
}
#OPENSTACK_KEYSTONE_URL = "http://%s/identity/v3" % OPENSTACK_HOST
OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True
OPENSTACK_API_VERSIONS = {
    "identity": 3,
    "image": 2,
    "volume": 3,
}
OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = "Default"
OPENSTACK_KEYSTONE_DEFAULT_ROLE = "user"
OPENSTACK_NEUTRON_NETWORK = {
    'enable_router': False,
    'enable_quotas': False,
    'enable_ipv6': False,
    'enable_distributed_router': False,
    'enable_ha_router': False,
    'enable_fip_topology_check': False,
}
EOF

## /* Restarting apache2 and memcached
systemctl reload apache2.service
service memcached restart
echo "########## Finish setting up Horizon ##########"

echo "########## LOGIN INFORMATION IN HORIZON ##########"
echo "URL: http://$CON_PRV_IP:80/horizon"
echo "User: admin or demo"
echo "Password:" $ADMIN_PASS