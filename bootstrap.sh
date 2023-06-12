#!/usr/bin/bash

# Common variables
DHIS2_EMAIL="security@dhis2.org"
DHIS2_HOME="/opt/dhis2"
DHIS2_USER="dhis2"
DHIS2_GROUP=$DHIS2_USER
DHIS2_DB="empty"
DHIS2_DBUSER=$DHIS2_USER
DHIS2_DBPASS=$DHIS2_USER

# The script runs in the non-interactive mode
DEBIAN_FRONTEND=noninteractive

# Install minimally necessary tools
apt-get install -yqq coreutis curl gettext-base git jq sudo

# Set additional variables
DHIS2_TMP=$(mktemp -d)
DHIS2_SRC=$DHIS_TMP/dhis2-specimen

# Clone the directory with templates
git clone https://github.com/dhis2-sre/dhis2-specimen.git $DHIS_SRC

# Fetch hostname and FQDN
# TODO: check that the left part matches
export DHIS2_HOST=$(hostname)
export DHIS2_FQDN=$(curl -s --connect-timeout 10 http://169.254.169.254/openstack/latest/meta_data.json | jq -j .name)

# Set the FQDN
# TODO: handle missing FQDN after "if"
if [ -n "$DHIS2_FQDN" ]; then
    echo "Setting hostname to '$DHIS2_FQDN'"
    cat $DHIS2_SRC/templates/etc/hosts | envsubst "$(printf '${%s} ' ${!DHIS2_*})" > /etc/hosts
fi

# We install and configure a default OS environment and tools
apt-get install -yqq net-tools software-properties-common testinfra

# We install and configure default services
apt-get install -yqq certbot nginx
mkdir -p /var/www/$DHIS2_FQDN
certbot certonly --quiet --noninteractive --agree-tos -d $DHIS_FQDN -m $DHIS2_EMAIL --webroot -w /var/www/html --post-hook "systemctl reload nginx"
cat $DHIS2_SRC/templates/etc/nginx/sites-available/specimen | envsubst "$(printf '${%s} ' ${!DHIS2_*})" > etc/nginx/sites-available/$DHIS2_FQDN
ln -s /etc/nginx/sites-available/$DHIS_FQDN /etc/nginx/sites-enabled/$DHIS_FQDN
systemctl reload nginx

# Create the DHIS2 database
apt-get install -yqq postgresql postgresql-client postgresql-*-postgis-3
sudo -D $DHIS2_TMP -u postgres createuser -SDR $DHIS2_DBUSER
sudo -D $DHIS2_TMP -u postgres createdb -O $DHIS2_DBUSER $DHIS2_DB
sudo -D $DHIS2_TMP -u postgres psql -c "ALTER USER $DHIS2_DBUSER PASSWORD '$DHIS2_DBPASS';"
sudo -D $DHIS2_TMP -u postgres psql -c "create extension postgis;" $DHIS2_DB
sudo -D $DHIS2_TMP -u postgres psql -c "create extension btree_gin;" $DHIS2_DB
sudo -D $DHIS2_TMP -u postgres psql -c "create extension pg_trgm;" $DHIS2_DB

apt-get install -yqq default-jdk-headless default-jre-headless 
apt-get install -yqq tomcat9 tomcat9-user

# Disable password authentication
mkdir -p /etc/ssh/sshd_config.d
echo "PasswordAuthentication no" > /etc/ssh/sshd_config.d/no_password.conf
systemctl reload ssh

# Create an unprivileged user for DHIS2
useradd -d $DHIS2_HOME -k /dev/null -m -r -s /usr/sbin/nologin $DHIS2_USER


# Perform a final upgrade
apt-get install -yqq unattended-upgrades
apt-get dist-upgrade -yqq

# Perform a final cleanup
# rm -rf $DHIS2_TMP