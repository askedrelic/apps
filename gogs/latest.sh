#!/bin/bash -x

source <(curl -s https://raw.githubusercontent.com/portalplatform/apps/master/portal.sh)

# Settings
export GOGS_VERSION="v0.6.9"
export GOGS_REPO="/data/git/gogs-repositories"

# Packages
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y unzip git nginx

# Nginx
cat <<NGINX >/etc/nginx/sites-available/default
server {
    listen 81;
    server_name $DOMAIN;
    return 302 https://${DOMAIN}${PUBLIC_URI};
}
server {
    listen 80;
    server_name $DOMAIN;
    location $PUBLIC_URI {
        proxy_set_header Host            \$host;
        proxy_set_header X-Real-IP       \$remote_addr;
        proxy_set_header X-Forwarded-for \$remote_addr;
        proxy_pass http://127.0.0.1:3000/;
    }
}
NGINX
service nginx restart

# Download
cd /opt/
wget https://github.com/gogits/gogs/releases/download/${GOGS_VERSION}/linux_amd64.zip
unzip linux_amd64.zip
cd gogs/

# Setup
mkdir -p custom/conf/
cat <<GOGS >custom/conf/app.ini
APP_NAME = $DOMAIN
RUN_USER = $USERNAME
RUN_MODE = prod

[server]
DOMAIN = $DOMAIN
ROOT_URL = http://${DOMAIN}${PUBLIC_URI}
HTTP_ADDR = 127.0.0.1
HTTP_PORT = 3000
OFFLINE_MODE = true
LANDING_PAGE = home

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

[mailer]
ENABLED = true
HOST = $DOMAIN

GOGS


# Repo dir
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
exec su -s /bin/sh -l $USERNAME -c '/opt/gogs/gogs web --config /opt/gogs/custom/conf/app.ini'
UPSTART

# Start services
service gogs start

# Submit installer form
wget -O /opt/submit-gogs-install-form "https://raw.githubusercontent.com/portalplatform/apps/master/gogs/submit-gogs-install-form"
chmod 755 /opt/submit-gogs-install-form

# Wait until it's up
until curl --output /dev/null --silent --fail "https://${DOMAIN}${PUBLIC_URI}"; do sleep 1 ; done

sleep 1

/opt/submit-gogs-install-form $USERNAME "https://${DOMAIN}${PUBLIC_URI_WITHSLASH}install"

