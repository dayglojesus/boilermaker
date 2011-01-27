#!/bin/bash
# Installs boilermaker

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# Install the code
cp -R . "/Library/Ruby/Site/1.8/boilermaker"
chown -R root:admin "/Library/Ruby/Site/1.8/boilermaker"

# Create some convenient symlinks for using Boilermaker
mkdir -p /usr/local/bin
cd /usr/local/bin
ln -s "/Library/Ruby/Site/1.8/boilermaker/boilermaker" boilermaker
ln -s "/Library/Ruby/Site/1.8/boilermaker/boilermaker" bm
ln -s "/Library/Ruby/Site/1.8/boilermaker/boilermakerdocs.rb" bmdocs

exit 0
