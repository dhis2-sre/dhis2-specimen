#!/usr/bin/bash

DHIS2_TOOLS_DIR="/opt/dhis2-server-tools"
DHIS2_EMAIL="security@dhis2.org"

# Update the environment
apt-get -qq update
apt-get -yqq dist-upgrade

# Fetch the FQDN
apt-get install -yqq curl jq
DHIS2_SPECIMEN_HOST=`curl -s http://169.254.169.254/openstack/latest/meta_data.json | jq -j .name`

# Set the FQDN
echo -e "127.0.0.1\tlocalhost\n127.0.1.1\t$DHIS2_SPECIMEN_HOST `hostname`\n\n::1\tlocalhost ip6-localhost ip6-loopback\nff02::1\tip6-allnodes\nff02::2\tip6-allrouters" > /etc/hosts

# We install and configure a default OS environment for the DHIS2 instance
apt-get install -yqq dialog git sed software-properties-common unattended-upgrades

# Install newer Ansible
apt-add-repository --yes --update ppa:ansible/ansible
apt-get install -yqq ansible python3-netaddr

# Install Ansible collection
ansible-galaxy collection install community.general -f

# Clone the tools
git clone https://github.com/dhis2/dhis2-server-tools $DHIS2_TOOLS_DIR

# Edit config
sed -i '/^training/s//#&/' $DHIS2_TOOLS_DIR/deploy/inventory/hosts
sed -i '/^timezone="Africa\/Nairobi"/s//timezone="UTC"/' $DHIS2_TOOLS_DIR/deploy/inventory/hosts
sed -i "/^email=\"\"/s//email=\""$DHIS2_EMAIL"\"/" $DHIS2_TOOLS_DIR/deploy/inventory/hosts
sed -i "/^fqdn=\"\"/s//fqdn=\""$DHIS2_SPECIMEN_HOST"\"/" $DHIS2_TOOLS_DIR/deploy/inventory/hosts
sed -i "/^guest_os=22.04/s//guest_os=`lsb_release -rs`/" $DHIS2_TOOLS_DIR/deploy/inventory/hosts

# Deploy DHIS2
ansible-playbook $DHIS2_TOOLS_DIR/deploy/lxd_setup.yml
ansible-playbook $DHIS2_TOOLS_DIR/deploy/dhis2.yml -i $DHIS2_TOOLS_DIR/deploy/inventory/hosts

