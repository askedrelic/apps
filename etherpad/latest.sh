#!/bin/bash

# Bash settings
set -e
set -u

# Set the sticky bit.
chmod 1777 /data/

export USERNAME=$(curl --silent http://169.254.169.254/metadata/v1/user/username)
export DOMAIN=$(curl --silent http://169.254.169.254/metadata/v1/domains/public/0/name)

URI=$(curl --silent http://169.254.169.254/metadata/v1/paths/private/0/uri)
if [ "/" != "${URI: -1}" ] ; then
    URI="$URI/"
fi
export URI


#
# Packages
#
export DEBIAN_FRONTEND=noninteractive
apt-get install -y python-software-properties 
apt-add-repository -y ppa:chris-lea/node.js 
apt-get update
apt-get install -y nodejs unzip nginx gzip git curl python libssl-dev pkg-config build-essential


#
# Nginx proxy.
#
cat <<NGINX > /etc/nginx/sites-available/default
server {
    listen 81 default_server;
    location $URI {
        proxy_pass http://127.0.0.1:9001/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Authorization "Basic YWRtaW46c3Nv"; # base64("admin:sso")
    }
}
NGINX

service nginx restart

#
# Download and setup Etherpad
#

npm install -g sqlite3

cd /opt/

git clone https://github.com/ether/etherpad-lite.git

cd etherpad-lite/

cat <<CONFIG >settings.json
{
    "title": "Etherpad",
    "favicon": "favicon.ico",
    "ip": "127.0.0.1",
    "port" : 9001,
    "dbType" : "sqlite",
    "dbSettings" : { "filename" : "/data/etherpad.db" },
    "defaultPadText" : "Welcome to Etherpad!\n\nThis pad text is synchronized as you type, so that everyone viewing this page sees the same text. This allows you to collaborate seamlessly on documents!\n\nGet involved with Etherpad at http:\/\/etherpad.org\n",
    "padOptions": {
        "noColors": false,
        "showControls": true,
        "showChat": true,
        "showLineNumbers": true,
        "useMonospaceFont": false,
        "userName": false,
        "userColor": false,
        "rtl": false,
        "alwaysShowChat": false,
        "chatAndUsers": false,
        "lang": "en-gb"
    },
    "users": {
        "admin": {
            "password": "sso",
            "is_admin": true
        }
    },
    "suppressErrorsInPadText" : false,
    "requireSession" : false,
    "editOnly" : false,
    "sessionNoPassword" : false,
    "minify" : true,
    "maxAge" : 21600, // 60 * 60 * 6 = 6 hours
    "abiword" : null,
    "tidyHtml" : null,
    "allowUnknownFileEnds" : true,
    "requireAuthentication" : false,
    "requireAuthorization" : false,
    "trustProxy" : true,
    "disableIPlogging" : false,
    "socketTransportProtocols" : ["xhr-polling", "jsonp-polling", "htmlfile"],
    "loadTest": false,
    "loglevel": "INFO",
    "logconfig" : { "appenders": [ { "type": "console" } ] }
}
CONFIG

chown -R $USERNAME:$USERNAME ./


#
# Create and start the Ghost daemon.
#
cat <<UPSTART > /etc/init/etherpad.conf
description "Etherpad"
start on runlevel [2345]
stop on runlevel [!2345]
respawn
script
    su -s /bin/sh -l $USERNAME -c 'cd /opt/etherpad-lite/ && export NODE_ENV=production && bin/run.sh'
end script
UPSTART

start etherpad

#
# Sync files in memory to disk.
#
sync


# Wait until it's up
until curl --output /dev/null --silent --fail "http://127.0.0.1:9001/"; do
    sleep 2
done

