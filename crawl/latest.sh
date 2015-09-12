#!/bin/bash -x
set -e
set -u

export USERNAME=$(curl --silent http://169.254.169.254/metadata/v1/user/username)
export DOMAIN=$(curl --silent http://169.254.169.254/metadata/v1/paths/public/0/domain)
export GATEWAY=$(curl --silent http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/gateway)
URI=$(curl --silent http://169.254.169.254/metadata/v1/paths/private/0/uri)
if [ "/" != "${URI: -1}" ] ; then
    URI="$URI/"
fi
export URI

# Remove trailing slash.
URI_NOSLASH="$URI"
if [ "/" == "${URI: -1}" ] ; then
    URI_NOSLASH="${URI:0:-1}"
fi
export URI_NOSLASH

# Disable ipv6.
cat <<DISABLE_IPV6 >>/etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
DISABLE_IPV6
sysctl -p

#
# Permissions
#
chmod 1777 /data/

#
# Settings
#
export GOTTY_TITLE="Crawl"
export GOTTY_SESSION="crawl"
export GOTTY_CMD="/usr/games/crawl -dir /data"

# Repos
echo 'deb https://crawl.develz.org/debian crawl 0.16' >/etc/apt/sources.list.d/crawl.list
curl --silent https://crawl.develz.org/debian/pubkey | apt-key add -

#
# Packages
#
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y crawl


#
# Crawl
#
cat <<CRAWL_UPSTART >/etc/init/crawl.conf
description "crawl"
start on runlevel [2345]
stop on runlevel [!2345]
expect daemon
respawn
script
    su -l $USERNAME -c "tmux new-session -d -s $GOTTY_SESSION '$GOTTY_CMD'"
end script
CRAWL_UPSTART

start crawl

#
# Gotty
#
wget -O /usr/local/bin/gotty https://raw.githubusercontent.com/portalplatform/apps/master/gotty/gotty
chmod 755 /usr/local/bin/gotty
setcap cap_net_bind_service=+ep /usr/local/bin/gotty

cat <<GOTTY_UPSTART >/etc/init/gotty.conf
description "gotty"
start on runlevel [2345]
stop on runlevel [!2345]
respawn
script
    su -l $USERNAME -c "/usr/local/bin/gotty --title-format '$GOTTY_TITLE - ({{ .Hostname }})' --root-url $URI_NOSLASH --port 81 --permit-write tmux new-session -A -s $GOTTY_SESSION '$GOTTY_CMD'"
end script
GOTTY_UPSTART

start gotty

sleep 2
