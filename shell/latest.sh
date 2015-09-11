#!/bin/bash -x
set -e
set -u

export USERNAME=$(curl http://169.254.169.254/metadata/v1/user/username)
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

# Disable ipv6.
cat <<DISABLE_IPV6 >>/etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
DISABLE_IPV6

sysctl -p

# Settings
export GOTTY_CMD="bash"
export GOTTY_SESSION="bash"

#
# Packages
#
export DEBIAN_FRONTEND=noninteractive

#
# Gotty
#
wget -O /usr/local/bin/gotty https://raw.githubusercontent.com/portalplatform/apps/master/gotty/gotty
chmod 755 /usr/local/bin/gotty
setcap cap_net_bind_service=+ep /usr/local/bin/gotty


#
# Bash
#
cat <<BASH_UPSTART >/etc/init/bash.conf
description "bash"
start on runlevel [2345]
stop on runlevel [!2345]
expect daemon
respawn
script
    su -l $USERNAME -c "tmux new-session -d -s '$GOTTY_SESSION $GOTTY_CMD'"
end script
BASH_UPSTART

start bash

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
    su -l $USERNAME -c "/usr/local/bin/gotty --title-format 'Shell - ({{ .Hostname }})' --root-url $URI_NOSLASH --port 81 --permit-write tmux attach-session -t $GOTTY_SESSION"
end script
GOTTY_UPSTART

start gotty

sleep 2