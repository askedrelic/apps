#!/bin/bash -x
set -e
set -u

export USERNAME="tor-debian"
export DOMAIN=$(curl http://169.254.169.254/metadata/v1/paths/public/0/domain)
export GATEWAY=$(curl --silent http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/gateway)
URI=$(curl http://169.254.169.254/metadata/v1/paths/private/0/uri)
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

# Tor settings.
export TOR_PORT="9001"

# Disable ipv6.
cat <<DISABLE_IPV6 >>/etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
DISABLE_IPV6

#
# Packages
#
export DEBIAN_FRONTEND=noninteractive

cat <<TOR_REPO >/etc/apt/sources.list.d/torproject.list
deb http://deb.torproject.org/torproject.org trusty main
deb-src http://deb.torproject.org/torproject.org trusty main
TOR_REPO

gpg --keyserver keys.gnupg.net --recv 886DDD89
gpg --export A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89 | sudo apt-key add -

apt-get update
apt-get install -y tor tor-arm deb.torproject.org-keyring


cat <<TOR >/etc/tor/torrc
ORPort $TOR_PORT
ExitPolicy reject *:*

RelayBandwidthRate 128 KB
RelayBandwidthBurst 256 KB

AccountingStart month 1 00:00
AccountingMax 128 GB

DisableDebuggerAttachment 0
TOR
service tor restart

#
# gotty
#
wget -O /usr/local/bin/gotty https://raw.githubusercontent.com/portalplatform/apps/master/gotty/gotty
chmod 755 /usr/local/bin/gotty
setcap cap_net_bind_service=+ep /usr/local/bin/gotty

cat <<UPSTART >/etc/init/gotty.conf
description "gotty"
start on runlevel [2345]
stop on runlevel [!2345]
respawn
script
    su -s /bin/sh -l debian-tor -c "/usr/local/bin/gotty --title-format '{{ .Command }} ({{ .Hostname }})' --root-url $URI_NOSLASH --port 81 --permit-write screen arm"
end script
UPSTART
start gotty


