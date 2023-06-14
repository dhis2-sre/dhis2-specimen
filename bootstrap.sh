#!/usr/bin/bash

# Common variables
DHIS2_EMAIL="security@dhis2.org"
DHIS2_HOME="/opt/dhis2"
DHIS2_USER="dhis2"
DHIS2_GROUP=$DHIS2_USER
DHIS2_DB="empty"
DHIS2_DBUSER=$DHIS2_USER
DHIS2_DBPASS=$DHIS2_USER
DHIS2_TOMCAT="$DHIS2_HOME/tomcat"
DHIS2_PORT=18080

# The script runs in the non-interactive mode
DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND

# Install minimally necessary tools
apt-get install -yqq coreutils curl gettext-base git jq sudo

# Set additional variables
DHIS2_TMP=$(mktemp -d)
DHIS2_SRC=$DHIS2_TMP/dhis2-specimen

# Clone the directory with templates
# TODO: check that the repository is not empty
git clone https://github.com/dhis2-sre/dhis2-specimen.git "$DHIS2_SRC"

# Fetch hostname and FQDN
# TODO: check that the left part of the FQDN matches the hostname
DHIS2_HOST=$(hostname)
DHIS2_FQDN=$(curl -s --connect-timeout 10 http://169.254.169.254/openstack/latest/meta_data.json | jq -j .name)

# Export variables for templating
export DHIS2_HOME DHIS2_USER DHIS2_GROUP DHIS2_HOST DHIS2_FQDN DHIS2_PORT DHIS2_DB DHIS2_DBUSER DHIS2_DBPASS DHIS2_TOMCAT

# Set the FQDN
# TODO: handle missing FQDN after "if"
if [ -n "$DHIS2_FQDN" ]; then
    echo "Setting hostname to '$DHIS2_FQDN'"
    cat "$DHIS2_SRC"/templates/etc/hosts | envsubst "$(printf '${%s} ' ${!DHIS2_*})" > /etc/hosts
fi

# We install and configure a default OS environment and tools
apt-get install -yqq net-tools software-properties-common testinfra

# Disable password authentication
mkdir -p /etc/ssh/sshd_config.d
echo "PasswordAuthentication no" > /etc/ssh/sshd_config.d/no_password.conf
systemctl reload ssh

# We install and configure default services
apt-get install -yqq certbot nginx
mkdir -p /var/www/html/.well-known /var/www/"$DHIS2_FQDN"

# Generate a SSL certificate
certbot certonly --quiet --noninteractive --agree-tos -m "$DHIS2_EMAIL" --webroot -w /var/www/html --post-hook "systemctl reload nginx" -d "$DHIS2_FQDN"

# Apply system-wide Nginx setup
cp "$DHIS2_SRC"/templates/etc/nginx/conf.d/*.conf /etc/nginx/conf.d

# Configure virtual host
cat "$DHIS2_SRC"/templates/etc/nginx/sites-available/specimen | envsubst "$(printf '${%s} ' ${!DHIS2_*})" > /etc/nginx/sites-available/"$DHIS2_FQDN"
ln -s /etc/nginx/sites-available/"$DHIS2_FQDN" /etc/nginx/sites-enabled/"$DHIS2_FQDN"

# Apply Nginx configuration
systemctl reload nginx

# Create the DHIS2 database
apt-get install -yqq postgresql postgresql-client postgresql-*-postgis-3
sudo -u postgres createuser -SDR $DHIS2_DBUSER
sudo -u postgres createdb -O $DHIS2_DBUSER $DHIS2_DB
sudo -u postgres psql -c "ALTER USER $DHIS2_DBUSER PASSWORD '$DHIS2_DBPASS';"
sudo -u postgres psql -c "create extension postgis;" $DHIS2_DB
sudo -u postgres psql -c "create extension btree_gin;" $DHIS2_DB
sudo -u postgres psql -c "create extension pg_trgm;" $DHIS2_DB

# Import data into the database
# TODO

# Create an unprivileged user for DHIS2
useradd -d $DHIS2_HOME -k /dev/null -m -r -s /usr/sbin/nologin $DHIS2_USER

# Configure DHIS2 directories
mkdir -p "$DHIS2_TOMCAT"/conf "$DHIS2_TOMCAT"/webapp
chown -R $DHIS2_USER:$DHIS2_GROUP $DHIS2_TOMCAT

# Install and configure Tomcat
apt-get install -yqq default-jdk-headless default-jre-headless 
apt-get install -yqq tomcat9

# Disable the default Tomcat instance
systemctl stop tomcat9
systemctl disable tomcat9

# Create DHIS2 configuration
cat "$DHIS2_SRC"/templates/opt/dhis2/dhis.conf | envsubst "$(printf '${%s} ' ${!DHIS2_*})" > "$DHIS2_HOME"/dhis.conf
cat "$DHIS2_SRC"/templates/etc/systemd/system/dhis2.service | envsubst "$(printf '${%s} ' ${!DHIS2_*})" > /etc/systemd/system/dhis2.service
systemctl daemon-reload
cat "$DHIS2_SRC"/templates/opt/dhis2/tomcat/conf/server.xml | envsubst "$(printf '${%s} ' ${!DHIS2_*})" > "$DHIS2_TOMCAT"/conf/server.xml
cp /usr/share/tomcat9/etc/web.xml "$DHIS2_TOMCAT"/conf/web.xml

# Perform a final upgrade
apt-get install -yqq unattended-upgrades
apt-get dist-upgrade -yqq

# Launch DHIS2
systemctl enable dhis2
systemctl start dhis2

# Perform a final cleanup
rm -rf "$DHIS2_TMP"
