#!/bin/bash -ex
#
source config.cfg

echo "Configuring for file /etc/hosts"
sleep 3
iphost=/etc/hosts
test -f $iphost.orig || cp $iphost $iphost.orig
rm $iphost
touch $iphost
cat << EOF >> $iphost
127.0.0.1       localhost

$CON_PRV_IP    controller
$CON_MGNT_IP   computer1
EOF

# nstall and configure components
apt install chrony
sleep 5
filechrony=/etc/chrony/chrony.conf
test -f $filechrony.orig || cp $filechrony $filechrony.orig
echo "UPDATE PACKAGE FOR JUNO"
apt-get -y update && apt-get -y dist-upgrade

echo "Install and config NTP"
sleep 3 
apt install chrony

cat  << EOF > $filechrony
server controller iburst
EOF
service chrony restart
sleep 3 
#OpenStack Wallaby for Ubuntu 20.04 LTS:
add-apt-repository cloud-archive:wallaby


sleep 5
#Sample Installation
apt install nova-compute

sleep 5
#Client Installation
apt install python3-openstackclient


# sed -i 's/server/#server/' /etc/ntp.conf
# echo "server $CON_MGNT_IP" >> /etc/ntp.conf

##############################################
echo "Install and Config RabbitMQ"
sleep 3
apt install rabbitmq-server
rabbitmqctl add_user openstack $RABBIT_PASS
rabbitmqctl set_permissions openstack ".*" ".*" ".*"
sleep 3
echo "Install and configure components"
#ubuntu18.04-20.04
apt install memcached python3-memcache
service memcached restart
echo "Finish setup pre-install package !!!"
