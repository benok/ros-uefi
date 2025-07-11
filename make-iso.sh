#!/bin/bash

set -eu
set -o pipefail

[[ -r .env ]] && . ./.env
ISO_DIR_PATH=${ISO_DIR_PATH:-./tmp/iso}

# Must run after make-uefi.sh
[[ ! -f $ISO_DIR_PATH/boot/grub/grub.cfg ]] && echo "Error must run after make-uefi.sh" && exit 1

echo "Installing tools"
sudo apt-get install -y make mtools xorriso

echo "Building iso image with make"
make clean all
