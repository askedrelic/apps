#!/bin/bash -x
set -e
set -u

export USERNAME=$(curl --silent http://169.254.169.254/metadata/v1/user/username)
export DOMAIN=$(curl --silent http://169.254.169.254/metadata/v1/paths/public/0/domain)
export GATEWAY=$(curl --silent http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/gateway)
URI=$(curl --silent http://169.254.169.254/metadata/v1/paths/public/0/uri)
if [ "/" != "${URI: -1}" ] ; then
    URI="$URI/"
fi
export URI

# URI without an ending slash.
URI_NOSLASH="$URI"
if [ "/" == "${URI: -1}" ] ; then
    URI_NOSLASH="${URI:0:-1}"
fi
export URI_NOSLASH


# Permissions
chmod 1777 /data/ /opt/


# Swap space
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile


# Disable ipv6.
cat <<DISABLE_IPV6 >>/etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
DISABLE_IPV6
sysctl -p


# Packages
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
    nginx \
    git \
    build-essential \
    python-dev \
    python-virtualenv \
    python-pybabel \
    zlib1g-dev \
    libxml2-dev \
    libyaml-dev \
    libxslt1-dev \
    libffi-dev \
    libssl-dev \
    openssl \


# Nginx
cat <<NGINX >/etc/nginx/sites-available/default
server {
    listen 81;
    access_log /dev/null;
    error_log /dev/null;
    return 302 https://${DOMAIN}${URI};
}

server {
    listen 80;
    server_name $DOMAIN;
    access_log /dev/null;
    error_log /dev/null;

    location $URI_NOSLASH {
        proxy_pass http://127.0.0.1:8888;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Scheme \$scheme;
        proxy_set_header X-Script-Name $URI_NOSLASH;
        proxy_redirect https://127.0.0.1:8888/ https://$DOMAIN/;
    }
}
NGINX
service nginx restart


# Download
cd /opt/
git clone https://github.com/asciimoo/searx


# Build
cd searx/
perl -pi -e "s#ultrasecretkey#$(openssl rand -hex 16)#" searx/settings.yml
perl -pi -e "s#base_url : False#base_url : \"https://${DOMAIN}${URI_NOSLASH}\"#" searx/settings.yml


# Permissions
chown -R $USERNAME:$USERNAME /data/ /opt/


# Setup
cat <<SETUP >/tmp/setup
#!/bin/bash
cd /opt/searx/
virtualenv searx-ve
. ./searx-ve/bin/activate
pip install -r requirements.txt
python setup.py install
SETUP
chmod 755 /tmp/setup
su -s /bin/bash -l $USERNAME -c /tmp/setup

cat <<RUN >/tmp/run
#!/bin/bash
cd /opt/searx/
virtualenv searx-ve
. ./searx-ve/bin/activate
python searx/webapp.py
RUN
chmod 755 /tmp/run

# Service
cat <<UPSTART >/etc/init/searx.conf
description "searx"
start on runlevel [2345]
stop on runlevel [!2345]
respawn
script
    su -s /bin/bash -l $USERNAME -c /tmp/run
end script
UPSTART


start searx
