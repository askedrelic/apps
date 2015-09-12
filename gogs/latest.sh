#!/bin/bash -x
set -e
set -u


export USERNAME=$(curl http://169.254.169.254/metadata/v1/user/username)
export DOMAIN=$(curl http://169.254.169.254/metadata/v1/paths/public/0/domain)
URI=$(curl http://169.254.169.254/metadata/v1/paths/public/0/uri)
if [ "/" != "${URI: -1}" ] ; then
    URI="$URI/"
fi
export URI

#
# Settings
#
export GOGS_VERSION="v0.6.9"
export GOGS_REPO="/data/git/gogs-repositories"

#
# Packages
#
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y unzip git nginx


#
# nginx
#
cat <<NGINX > /etc/nginx/sites-available/default
server {
    listen 80;
    server_name $DOMAIN;
    location $URI {
        proxy_pass http://127.0.0.1:8888/;
    }
}
NGINX
service nginx restart

#
# Download
#
cd /opt/
wget https://github.com/gogits/gogs/releases/download/${GOGS_VERSION}/linux_amd64.zip
unzip linux_amd64.zip
cd gogs/

#
# Setup
#
mkdir -p custom/conf/
cat <<GOGS >custom/conf/app.ini
[server]
DOMAIN = $DOMAIN
ROOT_URL = http://${DOMAIN}${URI}
HTTP_ADDR = 127.0.0.1
HTTP_PORT = 3000
OFFLINE_MODE = true
RUN_USER = $USERNAME
RUN_MODE = prod

[database]
DB_TYPE = sqlite3
PATH = /data/gogs.db

[service]
DISABLE_REGISTRATION = true
REQUIRE_SIGNIN_VIEW = true
ENABLE_REVERSE_PROXY_AUTHENTICATION = true
ENABLE_REVERSE_PROXY_AUTO_REGISTRATION = true

[picture]
DISABLE_GRAVATAR = true

[repository]
ROOT = $GOGS_REPO

[security]
REVERSE_PROXY_AUTHENTICATION_USER = X-Authenticated-User
GOGS


#
# Repo dir
#
[ -d $GOGS_REPO ] || mkdir -p $GOGS_REPO

# Set permissions
chown -R $USERNAME:$USERNAME /opt/
chown -R $USERNAME:$USERNAME /data/

# Create gogs upstart config.
cat <<UPSTART >/etc/init/gogs.conf
description "gogs"
start on runlevel [2345]
stop on runlevel [!2345]
respawn
exec su -s /bin/sh -l $USERNAME -c 'cd /opt/gogs/ && ./gogs web'
UPSTART

#
# Start services
#
service gogs start

#
# Submit installer form
#
wget -O /opt/submit-gogs-install-form "https://raw.githubusercontent.com/portalplatform/apps/master/gogs/submit-gogs-install-form"
chmod 755 /opt/submit-gogs-install-form

# Wait until it's up
until curl --output /dev/null --silent --fail "https://${DOMAIN}${URI}"; do sleep 1 ; done

sleep 1

/opt/submit-gogs-install-form $USERNAME "https://${DOMAIN}${URI}/install"

