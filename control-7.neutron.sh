#!/bin/bash -ex
#
# RABBIT_PASS=a
# ADMIN_PASS=a

source config.cfg
. admin-openrc

openstack user create --domain default --password-prompt neutron
sleep 20

openstack role add --project service --user neutron admin
sleep 5

openstack service create --name neutron \
  --description "OpenStack Networking" network
sleep 5

openstack endpoint create --region RegionOne \
  network public http://controller:9696
sleep 5

openstack endpoint create --region RegionOne \
  network internal http://controller:9696
sleep 5

openstack endpoint create --region RegionOne \
  network admin http://controller:9696  
sleep 5
echo "Networking Option 2: Self-service networks"

apt install neutron-server neutron-plugin-ml2 \
  neutron-linuxbridge-agent neutron-l3-agent neutron-dhcp-agent \
  neutron-metadata-agent
sleep 10

#
controlneutron=/etc/neutron/neutron.conf
test -f $controlneutron.orig || cp $controlneutron $controlneutron.orig
rm $controlneutron
touch $controlneutron
cat << EOF >> $controlneutron
[DEFAULT]
core_plugin = ml2
service_plugins = router
allow_overlapping_ips = true
transport_url = rabbit://openstack:$RABBIT_PASS@controller

auth_strategy = keystone

notify_nova_on_port_status_changes = true
notify_nova_on_port_data_changes = true

[matchmaker_redis]
[matchmaker_ring]

[quotas]
[agent]
root_helper = sudo /usr/bin/neutron-rootwrap /etc/neutron/rootwrap.conf

[keystone_authtoken]
# ...
www_authenticate_uri = http://controller:5000
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = neutron
password = $NEUTRON_PASS

[database]
connection = mysql+pymysql://neutron:$NEUTRON_DBPASS@controller/neutron

[service_providers]
service_provider=LOADBALANCER:Haproxy:neutron.services.loadbalancer.drivers.haproxy.plugin_driver.HaproxyOnHostPluginDriver:default
service_provider=VPN:openswan:neutron.services.vpn.service_drivers.ipsec.IPsecVPNDriver:default

[nova]
# ...
auth_url = http://controller:5000
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = nova
password = $NOVA_PASS

[oslo_concurrency]
# ...
lock_path = /var/lib/neutron/tmp

EOF


######## Backup configuration of ML2 in $CON_MGNT_IP##################"
echo "########## Configuring ML2 in $CON_MGNT_IP/NETWORK node ##########"
sleep 7

controlML2=/etc/neutron/plugins/ml2/ml2_conf.ini
test -f $controlML2.orig || cp $controlML2 $controlML2.orig
rm $controlML2
touch $controlML2

cat << EOF >> $controlML2
[ml2]
type_drivers = flat,vlan,vxlan
tenant_network_types = vxlan
mechanism_drivers = linuxbridge,l2population
extension_drivers = port_security

[ml2_type_flat]
flat_networks = provider

[ml2_type_vlan]
vni_ranges = 1:1000

[ml2_type_gre]
tunnel_id_ranges = 1:1000

[ml2_type_vxlan]

[securitygroup]
# ...
enable_ipset = true

EOF

echo "########## Configure the Linux bridge agent ##########"
sleep 7

linuxbridgeagent=/etc/neutron/plugins/ml2/linuxbridge_agent.ini 
test -f $linuxbridgeagent.orig || cp $linuxbridgeagent $linuxbridgeagent.orig
rm $linuxbridgeagent
touch $linuxbridgeagent

cat << EOF >> $linuxbridgeagent
[linux_bridge]
physical_interface_mappings = provider:eth0

[vxlan]
enable_vxlan = true
local_ip = $CON_PRV_IP
l2_population = true

[securitygroup]
# ...
enable_security_group = true
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

EOF

echo "########## Configure the layer-3 agent ##########"
sleep 7

l3agent=/etc/neutron/l3_agent.ini
test -f $l3agent.orig || cp $l3agent $l3agent.orig
rm $l3agent
touch $l3agent

cat << EOF >> $l3agent
[DEFAULT]
# ...
interface_driver = linuxbridge

EOF

echo "########## Configure the DHCP agent ##########"
sleep 7

dhcpagent=/etc/neutron/dhcp_agent.ini
test -f $dhcpagent.orig || cp $dhcpagent $dhcpagent.orig
rm $dhcpagent
touch $dhcpagent

cat << EOF >> $dhcpagent
[DEFAULT]
# ...
interface_driver = linuxbridge
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
enable_isolated_metadata = true

EOF

echo "######install neutron-linuxbridge-agent####### "
apt install neutron-linuxbridge-agent
service neutron-linuxbridge-agent restart  

echo "########## Restarting NOVA service ##########"
sleep 7 
service nova-compute restart
service neutron-linuxbridge-agent restart
echo "#####Configure the metadata agent###"
metadataagent=/etc/neutron/metadata_agent.ini
test -f $metadataagent.orig || cp $metadataagent $metadataagent.orig
rm $metadataagent
touch $metadataagent

cat << EOF >> $metadataagent
[DEFAULT]
# ...
nova_metadata_host = controller
metadata_proxy_shared_secret = METADATA_SECRET

EOF

echo "########## Restarting NEUTRON service ##########"
sleep 7 
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
service nova-api restart 
service neutron-server restart
service neutron-linuxbridge-agent restart
service neutron-dhcp-agent restart
service neutron-metadata-agent restart 
service neutron-l3-agent restart