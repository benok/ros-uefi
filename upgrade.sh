#!/bin/bash

set -eu

# Must be run as root
[[ $EUID > 0 ]] && echo "Error: must run as root/su" && exit 1

DEST_DEVICE=${DEST_DEVICE:-/dev/sda}

# get partition device name
# (/dev/sda 1 -> /dev/sda1, /dev/nvme0n1 1 -> /dev/nvme0n1p1)
get_part_dev() {
    dev=$1
    pn=$2
    d=/dev/disk/by-id
    devbyid=
    for i in $(ls $d); do
      resolved=$(readlink -f $d/$i)
      if [ "$resolved" = "$dev" ]; then
        devbyid=$d/$i
      fi
    done
    if [ "$devbyid" = "" ]; then
      echo "failed to get part #$i device of $dev"
      exit 1
    fi
    echo $(readlink -f $devbyid-part$pn)
}

DEST_DEVICE_P1=$(get_part_dev $DEST_DEVICE 1)
DEST_DEVICE_P2=$(get_part_dev $DEST_DEVICE 2)
P1_DIR="/mnt/p1"
P2_DIR="/mnt/p2"

# Mount partitions
echo
echo "Mounting partitions"
mkdir -p "${P1_DIR}"
mkdir -p "${P2_DIR}"
mount "${DEST_DEVICE_P1}" "${P1_DIR}"
mount "${DEST_DEVICE_P2}" "${P2_DIR}"

# Run the upgrade
echo
echo "Upgrading BurmillaOS"
ros os upgrade --force --no-reboot

# Copy kernels and initrds
echo
echo "Copying OS files"
find "${P2_DIR}/boot" | grep -i -E "initrd|linuz" | xargs -I '{}' cp '{}' "${P1_DIR}/boot"

# Get file names and versions
echo
echo "Gathering current and previous files and versions"
CURRENT_KERNEL_FILE="$(grep -i -E "vmlinuz" ${P2_DIR}/boot/linux-current.cfg | cut -d'/' -f2 | sed -e 's/\r//g')"
CURRENT_INITRD_FILE="$(grep -i -E "initrd" ${P2_DIR}/boot/linux-current.cfg | cut -d'/' -f2 | sed -e 's/\r//g')"
CURRENT_VERSION="$(echo ${CURRENT_INITRD_FILE} | cut -d'-' -f2)"

PREVIOUS_KERNEL_FILE="$(grep -i -E "vmlinuz" ${P2_DIR}/boot/linux-previous.cfg | cut -d'/' -f2 | sed -e 's/\r//g')"
PREVIOUS_INITRD_FILE="$(grep -i -E "initrd" ${P2_DIR}/boot/linux-previous.cfg | cut -d'/' -f2 | sed -e 's/\r//g')"
PREVIOUS_VERSION="$(echo ${PREVIOUS_INITRD_FILE} | cut -d'-' -f2)"

# Update grub
GRUB_CFG_PATH="${P1_DIR}/boot/grub/grub.cfg"
echo
echo "Modifying grub config"

if [ -f "${GRUB_CFG_PATH}" ]; then
    mv "${GRUB_CFG_PATH}" "${GRUB_CFG_PATH}.bak"
fi
cat >> "${GRUB_CFG_PATH}" <<EOF
set timeout=5

menuentry "BurmillaOS $CURRENT_VERSION" {
        search --no-floppy --set=root --label RANCHER_STATE
    linux    /boot/$CURRENT_KERNEL_FILE printk.devkmsg=on rancher.state.dev=LABEL=RANCHER_STATE rancher.state.wait panic=10 console=tty0
    initrd   /boot/$CURRENT_INITRD_FILE
}

menuentry "Previous BurmillaOS ($PREVIOUS_VERSION)" {
        search --no-floppy --set=root --label RANCHER_STATE
    linux    /boot/$PREVIOUS_KERNEL_FILE printk.devkmsg=on rancher.state.dev=LABEL=RANCHER_STATE rancher.state.wait panic=10 console=tty0
    initrd   /boot/$PREVIOUS_INITRD_FILE
}

menuentry "Install BurmillaOS" {
    linux    /boot/$CURRENT_KERNEL_FILE rancher.autologin=tty1 rancher.autologin=ttyS0 rancher.autologin=ttyS1 console=tty1 console=ttyS0 console=ttyS1 printk.devkmsg=on panic=10 ---
    initrd   /boot/$CURRENT_INITRD_FILE
}

menuentry "UEFI Firmware Settings" {
    fwsetup
}
EOF

echo
echo "Upgrade (should be) complete, reboot."
