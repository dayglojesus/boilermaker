#!/bin/bash
# Installs boilermaker

echo
echo "???  Uninstall Boilermaker  ???"
echo 
echo "WARNING: This script will remove the entire contents of /Library/Ruby/Site/1.8/boilermaker"
echo "If you have made any customizations of the code or resources, these changes will be lost."
echo
# echo "If you wish to continue, please type YES: "
read -p "If you wish to continue, please type YES: "

if [ "${REPLY}" != "YES" ];then
	echo "Your reply was other than 'YES'. Exiting..."
	exit 2
else
	echo "Removing Boilermaker..."
	if [[ $EUID -ne 0 ]]; then
	  echo "This script must be run as root" 1>&2
	  exit 1
	fi

	# Remove the code
	rm -rf . "/Library/Ruby/Site/1.8/boilermaker"

	# Remove some convenient symlinks for using Boilermaker
	cd /usr/local/bin
	rm boilermaker
	rm bm
	rm bmdocs
fi

echo "Done."
exit 0
