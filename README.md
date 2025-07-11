# ROS UEFI

### Scripts for installing and upgrading Burmilla OS on a UEFI system

`make-uefi.sh` and `make-iso.sh` was tested in Burmilla OS 2.0.3 w/default(debian) console

`install.sh` was tested with Burmilla OS 2.0.2 & 2.0.3 ISO

`upgrade.sh` was tested with Burmilla OS 2.0.2 default console

My tested target was an Proxmox VM.
<br />
<br />

#### About secure boot

Installer Image created by this script do not currently support secure boot.

So you must disable secure boot from your UEFI firmware settings menu before booting installer.

(If you use Proxmox, uncheck `Attempt Secure Boot` under `Device Manager`>`Secure Boot Configuration`)


### `> make-uefi.sh`

#### This script prepares the directories and files necessary to create a UEFI-bootable installer files for Burmilla OS.

**1. Set** (optional)

`ROS_ISO_URL` to the URL of the Burmilla OS ISO you'd like to install, or drop your own `Burmillaos.iso` file adjacent to the script.

If you set `ROS_VERSION`, the URL becomes download link of that version from github.

**2. Run** `./make-uefi.sh` and it will spit out a `tmp` directory adjacent to the script.

**3. Copy** the `./tmp/iso` subdirectory contents to a FAT32-formatted USB drive that you will boot to and install Burmilla OS from.
<br />
<br />
<br />

### `> make-iso.sh`

#### This script generates UEFI bootable iso image of Burmilla OS Installer.

**1. Run** `./make-iso.sh` and it generates `burmillaos-$(VERSION)-uefi.iso`

**2. Use** the iso image file and boot VM from the iso (or burn it to the optical media and mount & boot from it.)

**3. Mount** the ISO and copy installer script to your working directory

```bash
mkdir /mnt/src
sudo mount -o ro /dev/sr0 /mnt/src
cp /mnt/src/install.sh .
```

<br />
<br />
<br />

### `> install.sh`

#### This script installs Burmilla OS from the prepared USB or ISO image

**1. Copy** the `install.sh` script to your USB installer drive.

**2. Set**

`DEST_DEVICE` to the name of the device you'll be installing Burmilla OS to.

`SRC_DEVICE` to the name of the USB device you'll be booting from.

`CLOUD_CONFIG_FILE_PATH` to the path or URL where your cloud config is located, or leave it as is and drop a `cloud-config.yml` adjacent to the `install.sh` script.

**3. Run**

Once live inside the Burmilla OS install image, make sure the device you're installing to is free of any partitions and then mount it and run `sudo ./install.sh`.
<br />
<br />
<br />

### `> upgrade.sh`

#### This script will upgrade an existing Burmilla OS installation that was installed using this method to the latest version.

**1. Copy** the `upgrade.sh` script to your Burmilla OS installation. I just drop it in the home directory.

**2. Set**

`DEST_DEVICE` to the name of the device Burmilla OS is installed to.

**3. Run** `sudo DEST_DEVICE=/dev/sda ./upgrade.sh`
