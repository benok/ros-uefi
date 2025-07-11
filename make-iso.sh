#!/bin/bash

set -eu
set -o pipefail

# Must be run as root
[[ $EUID > 0 ]] && echo "Error: must run as root/su" && exit 1

ISO_DIR_PATH=./tmp/iso

# Must run after make-uefi.sh
[[ ! -f $ISO_DIR_PATH/boot/grub/grub.cfg ]] && echo "Error must run after make-uefi.sh" && exit 1

echo "Installing tools"
apt-get install -y make mtools xorriso

echo "Building iso image with make"
make clean all
