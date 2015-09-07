#!/bin/bash

# Bash settings
set -e
set -u

# Set the sticky bit on /data.
chmod 1777 /data/

export USERNAME=$(curl --silent http://169.254.169.254/metadata/v1/user/username)
export DOMAIN=$(curl --silent http://169.254.169.254/metadata/v1/domains/public/0/name)
export URI=$(curl --silent http://169.254.169.254/metadata/v1/paths/private/0/uri)

export USER_UID=$(id -u $USERNAME)

# TODO: Make ipv6 work!
cat <<DISABLE_IPV6 >>/etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
DISABLE_IPV6
sysctl -p

#
# Packages
#
export DEBIAN_FRONTEND=noninteractive
curl --silent https://syncthing.net/release-key.txt | sudo apt-key add -
echo 'deb http://apt.syncthing.net/ syncthing release' > /etc/apt/sources.list.d/syncthing-release.list
sudo apt-get update
sudo apt-get install -y syncthing nginx

cat <<NGINX > /etc/nginx/sites-available/default
server {
    listen 81;
    location $URI {
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_pass http://localhost:8384/;
    }
}
NGINX
service nginx restart


if [ ! -e /data/config.xml ] ; then
    su -s /bin/sh -l $USERNAME -c 'syncthing -generate="/data"'
    perl -pi -e "s#/home/$USERNAME/#/data/#" /data/config.xml
fi

# Create the Upstart job.
cat <<UPSTART >/etc/init/syncthing.conf
description "syncthing"
start on runlevel [2345]
stop on runlevel [!2345]
respawn
script
    su -s /bin/sh -l $USERNAME -c 'syncthing -home=/data -no-browser -no-restart'
end script
UPSTART

start syncthing


#
# Sync files in memory to disk.
#
sync
