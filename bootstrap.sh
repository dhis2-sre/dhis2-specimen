#!/usr/bin/bash

# Common variables
DHIS2_EMAIL="security@dhis2.org"

# Update the environment
apt-get -qq update
apt-get -yqq dist-upgrade

# Fetch the FQDN
apt-get install -yqq curl jq
DHIS2_SPECIMEN_HOST=`curl -s http://169.254.169.254/openstack/latest/meta_data.json | jq -j .name`

# Set the FQDN
echo -e "127.0.0.1\tlocalhost\n127.0.1.1\t$DHIS2_SPECIMEN_HOST `hostname`\n\n::1\tlocalhost ip6-localhost ip6-loopback\nff02::1\tip6-allnodes\nff02::2\tip6-allrouters" > /etc/hosts
 
# We install and configure a default OS environment
apt-get install -yqq git sed software-properties-common unattended-upgrades

# We install and configure default services
apt-get install -yqq certbot default-jdk-headless default-jre-headless nginx postgresql postgresql-client tomcat9 tomcat9-admin tomcat9-user

# Install other useful packages
apt-get install net-tools testinfra

# Disable password authentication
mkdir -p /etc/ssh/sshd_config.d
echo "PasswordAuthentication no" > /etc/ssh/sshd_config.d/no_password.conf
systemctl reload ssh
