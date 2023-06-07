#!/usr/bin/bash

# Common variables
DHIS2_EMAIL="security@dhis2.org"
DHIS2_HOME="/opt/dhis2"
DHIS2_USER="dhis2"
DHIS2_GROUP=$DHIS2_USER
DHIS2_DB="empty"
DHIS2_DBUSER=$DHIS2_USER
DHIS2_DBPASS=$DHIS2_USER

# Set additional variables
TMP_DIR="/tmp"
DEBIAN_FRONTEND=noninteractive

# Try to fetch the FQDN
apt-get install -yqq curl jq
DHIS2_HOSTNAME=$(curl -s --connect-timeout 10 http://169.254.169.254/openstack/latest/meta_data.json | jq -j .name)

# Set the FQDN
if [ -n "$DHIS2_HOSTNAME" ]; then
    echo "Setting hostname to '$DHIS2_HOSTNAME'"
    echo -e "127.0.0.1\tlocalhost\n127.0.1.1\t$DHIS2_HOSTNAME $(hostname)\n\n::1\tlocalhost ip6-localhost ip6-loopback\nff02::1\tip6-allnodes\nff02::2\tip6-allrouters" > /etc/hosts
fi

# We install and configure a default OS environment
apt-get install -yqq gettext-base git sed software-properties-common sudo

# We install and configure default services
apt-get install -yqq certbot default-jdk-headless default-jre-headless nginx postgresql postgresql-client postgresql-*-postgis-3 tomcat9 tomcat9-admin tomcat9-user

# Install other useful packages
apt-get install -yqq mc net-tools reptyr testinfra unattended-upgrades

# Disable password authentication
mkdir -p /etc/ssh/sshd_config.d
echo "PasswordAuthentication no" > /etc/ssh/sshd_config.d/no_password.conf
systemctl reload ssh

# Create an unprivileged user for DHIS2
useradd -d $DHIS2_HOME -k /dev/null -m -r -s /usr/sbin/nologin $DHIS2_USER

# Create the DHIS2 database
sudo -D $TMP_DIR -u postgres createuser -SDR $DHIS2_DBUSER
sudo -D $TMP_DIR -u postgres createdb -O $DHIS2_DBUSER $DHIS2_DB
sudo -D $TMP_DIR -u postgres psql -c "ALTER USER $DHIS2_DBUSER PASSWORD '$DHIS2_DBPASS';"
sudo -D $TMP_DIR -u postgres psql -c "create extension postgis;" $DHIS2_DB
sudo -D $TMP_DIR -u postgres psql -c "create extension btree_gin;" $DHIS2_DB
sudo -D $TMP_DIR -u postgres psql -c "create extension pg_trgm;" $DHIS2_DB

# Perform a final upgrade
apt-get dist-upgrade -yqq
