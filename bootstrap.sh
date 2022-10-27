#!/usr/bin/bash

DHIS2_TOOLS_DIR="/opt/dhis2-server-tools"

# Update the environment
apt-get -qq update
apt-get -yqq dist-upgrade

# We install and configure a default OS environment for the DHIS2 instance
apt-get install -y curl dialog git jq sed software-properties-common unattended-upgrades

# Install newer Ansible
apt-add-repository --yes --update ppa:ansible/ansible
apt-get install -y ansible python3-netaddr

# Install Ansible collection
ansible-galaxy collection install community.general -f

# Clone the tools
git clone https://github.com/dhis2/dhis2-server-tools $DHIS2_TOOLS_DIR

# Edit config

# Deploy DHIS2
#ansible-playbook $DHIS2_TOOLS_DIR/deploy/lxd-init.yml # needed to setup lxd environment.
#ansible-playbook $DHIS2_TOOLS_DIR/deploy/dhis2.yaml -i $DHIS2_TOOLS_DIR/deploy/inventory/hosts

