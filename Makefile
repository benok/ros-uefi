# taken from https://github.com/syzdek/efibootiso/blob/master/Makefile

CD=./tmp/iso

.PHONY: all clean

all: burmillaos-uefi.iso

$(CD)/EFI/boot/efiboot.img: $(CD)/EFI/boot/bootx64.efi $(CD)/EFI/boot/grubx64.efi $(CD)/EFI/boot/mmx64.efi
	@rm -f "$(@)"
	dd \
	   if=/dev/zero \
	   of="$(@)" \
	   bs=512 \
	   count=8192 \
	   || { rm -f "$(@)"; exit 1; }
	mkfs.msdos \
	   -F 12 \
	   -n 'EFIBOOTISO' \
	   "$(@)" \
	   || { rm -f "$(@)"; exit 1; }
	mmd \
	   -i "$(@)" \
	   ::EFI \
	   || { rm -f "$(@)"; exit 1; }
	mmd \
	   -i "$(@)" \
	   ::EFI/boot \
	   || { rm -f "$(@)"; exit 1; }
	mcopy \
	   -i "$(@)" \
	   $(CD)/EFI/boot/bootx64.efi \
	   ::EFI/boot/bootx64.efi \
	   || { rm -f "$(@)"; exit 1; }
	mcopy \
	   -i "$(@)" \
	   $(CD)/EFI/boot/grubx64.efi \
	   ::EFI/boot/grubx64.efi \
	   || { rm -f "$(@)"; exit 1; }
	mcopy \
	   -i "$(@)" \
	   $(CD)/EFI/boot/mmx64.efi \
	   ::EFI/boot/mmx64.efi \
	   || { rm -f "$(@)"; exit 1; }
	@touch "$(@)"

$(CD)/install.sh: install.sh
	sudo cp "$<" "$@"

$(CD)/upgrade.sh: upgrade.sh
	sudo cp "$<" "$@"

burmillaos-uefi.iso: $(CD)/EFI/boot/efiboot.img $(CD)/boot/isolinux/isolinux.bin $(CD)/install.sh $(CD)/upgrade.sh
	cd $(CD) && \
	xorriso -as mkisofs \
	   -o "../../$(@)" \
	   -R -J -v -d -N \
	   -x efiboot.iso \
	   -hide-rr-moved \
	   -no-emul-boot \
	   -boot-load-size 4 \
	   -boot-info-table \
	   -b boot/isolinux/isolinux.bin \
	   -c boot/isolinux/isolinux.boot \
	   -eltorito-alt-boot \
	   -no-emul-boot \
	   -eltorito-platform efi \
	   -eltorito-boot EFI/boot/efiboot.img \
	   -V "BurmillaOS" \
	   -A "BurmillaOS UEFI Boot ISO"  \
	   ./ \
	   || { rm -f "$(@)"; exit 1; }
	@touch "$(@)"

clean:
	rm -f burmillaos-uefi.iso $(CD)/EFI/boot/efiboot.img:
