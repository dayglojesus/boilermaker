#!/bin/bash
# Installs boilermaker

echo "?????????????????????????????"
echo "???  Install Boilermaker  ???"
echo "?????????????????????????????"
echo 
echo "WARNING: This script will overwrite the entire contents of /Library/Ruby/Site/1.8/boilermaker"
echo "If you have made any customizations of the code or resources, these changes will be lost."
echo

read -p "If you wish to continue, please type YES: "

if [ "${REPLY}" != "YES" ];then
	echo "Your reply was other than 'YES'. Exiting..."
	exit 2
else
	if [[ $EUID -ne 0 ]]; then
	  echo "This script must be run as root" 1>&2
	  exit 1
	fi
	
	# Install the code
	echo "Installing..."
	cp -R . "/Library/Ruby/Site/1.8/boilermaker"
	chown -R root:admin "/Library/Ruby/Site/1.8/boilermaker"

	# Create some convenient symlinks for using Boilermaker
	echo "Creating symlinks..."
	mkdir -p /usr/local/bin
	cd /usr/local/bin
	ln -s "/Library/Ruby/Site/1.8/boilermaker/boilermaker" boilermaker
	ln -s "/Library/Ruby/Site/1.8/boilermaker/boilermaker" bm
	ln -s "/Library/Ruby/Site/1.8/boilermaker/boilermakerdocs.rb" bmdocs
	
fi

echo "Done."
exit 0
