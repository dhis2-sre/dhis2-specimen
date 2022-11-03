#!/usr/bin/bash
apt-get update -qq
apt-get install -yqq wget
wget -q "https://raw.githubusercontent.com/dhis2-sre/dhis2-specimen/main/bootstrap.sh" -O - | bash
