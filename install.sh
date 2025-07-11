#!/bin/bash

#set -x
set -u
set -o pipefail

# Must be run as root
[[ $EUID > 0 ]] && echo "Error: must run as root/su" && exit 1

SRC_DEVICE=${SRC_DEVICE:-/dev/sr0}
DEST_DEVICE=${DEST_DEVICE:-/dev/sda}
EFI_PARTITION_SIZE=${EFI_PARTITION_SIZE:-384M} # current boot files & two versions of kernels & initrds requires "265M"
CLOUD_CONFIG_FILE_PATH=${CLOUD_CONFIG_FILE_PATH:-./cloud-config.yml}
SRC_DEVICE_MOUNT_DIR=${SRC_DEVICE_MOUNT_DIR:-/mnt/src}

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
P1_DIR="/tmp/d"

# Install dosfstools if not exists
if ! dpkg -s dosfstools >/dev/null 2>&1; then
    echo "Installing dosfstools"
    apt update
    apt install -y dosfstools
fi

echo
echo "Formatting device ${DEST_DEVICE}"
echo "  (ignore any warnings about 'y' command)"
fdisk ${DEST_DEVICE}<<EOF
g
n
1

+${EFI_PARTITION_SIZE}
y
t
1
n
2


y
p
w
EOF

set -e

echo
echo "Formatting EFI partition"
mkfs -t fat -n RANCHER -F 32 ${DEST_DEVICE_P1} || true
echo "Mounting EFI partition"
mkdir -p "${P1_DIR}"
mount -t vfat ${DEST_DEVICE_P1} "${P1_DIR}" || true

echo
echo "Mounting SRC device"
mkdir -p "${SRC_DEVICE_MOUNT_DIR}"
mount ${SRC_DEVICE} "${SRC_DEVICE_MOUNT_DIR}" || true

echo
echo "Copying EFI boot files"
cp "${SRC_DEVICE_MOUNT_DIR}/boot" "${P1_DIR}" -r
cp "${SRC_DEVICE_MOUNT_DIR}/EFI" "${P1_DIR}" -r

echo
echo "Creating ext4 filesystem on p2"
mkfs.ext4 -F -i 4096 -O 64bit -L RANCHER_STATE ${DEST_DEVICE_P2}
if [ "${SRC_DEVICE}" != "/dev/sr0" ]; then
  mkdir -p /dev/sr0
fi

echo
echo "Installing BurmillaOS"
ros install \
    -t gptsyslinux \
    -c "${CLOUD_CONFIG_FILE_PATH}" \
    -d ${DEST_DEVICE} \
    -p ${DEST_DEVICE_P2} \
    --force \
    --no-reboot

echo
echo "Modifying grub config"

CURRENT_KERNEL_FILE="$(grep -i -E "vmlinuz" ${P1_DIR}/boot/linux-current.cfg | cut -d'/' -f2 | sed -e 's/\r//g')"
CURRENT_INITRD_FILE="$(grep -i -E "initrd" ${P1_DIR}/boot/linux-current.cfg | cut -d'/' -f2 | sed -e 's/\r//g')"
CURRENT_VERSION="$(echo ${CURRENT_INITRD_FILE} | cut -d'-' -f2)"

GRUB_CFG_PATH="${P1_DIR}/boot/grub/grub.cfg"

rm ${GRUB_CFG_PATH}
cat >> ${GRUB_CFG_PATH} <<EOF
set timeout=5

menuentry "BurmillaOS $CURRENT_VERSION from GPT" {
        search --no-floppy --set=root --label RANCHER_STATE
    linux    /boot/$CURRENT_KERNEL_FILE printk.devkmsg=on rancher.state.dev=LABEL=RANCHER_STATE rancher.state.wait panic=10 console=tty0
    initrd   /boot/$CURRENT_INITRD_FILE
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
echo "Installation (should be) complete, remove SRC installation device and reboot."
