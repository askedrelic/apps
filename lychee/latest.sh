#!/bin/bash

# Bash settings
set -e
set -u

# Set the sticky bit.
chmod 1777 /data/

export USERNAME=$(curl --silent http://169.254.169.254/metadata/v1/user/username)
export DOMAIN=$(curl --silent http://169.254.169.254/metadata/v1/domains/public/0/name)
export DAEMON_URL="https://ghost.org/zip/ghost-0.6.4.zip"

URI=$(curl --silent http://169.254.169.254/metadata/v1/paths/public/0/uri)
if [ "/" != "${URI: -1}" ] ; then
    URI="$URI/"
fi
export URI


#
# Packages
#
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y install git
apt-get -y install apache2 mysql-server libapache2-mod-php5 imagemagick php5-mysql php5-gd php5-curl php5-imagick

# configure apache/php settings
sed -i -e "s/^max_execution_time\s*=.*/max_execution_time = 200/" \
-e "s/^post_max_size\s*=.*/post_max_size = 100M/" \
-e "s/^upload_max_filesize\s*=.*/upload_max_filesize = 20M\nupload_max_size = 100M/" \
-e "s/^memory_limit\s*=.*/memory_limit = 256M/" /etc/php5/apache2/php.ini

mkdir -p /app && rm -fr /var/www/html && ln -s /app /var/www/html

cd /app

git clone https://github.com/electerious/Lychee.git .

chown -R www-data:www-data /app
chmod -R 777 uploads/ data/

src/commands/start
