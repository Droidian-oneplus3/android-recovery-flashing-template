# Droidian installer Script

OUTFD=/proc/self/fd/$1;

# ui_print <text>
ui_print() { echo -e "ui_print $1\nui_print" > $OUTFD; }

## Droidian install
cat /data/manjaro/data/rootfs.part.* > /data/rootfs.img

# resize rootfs
# first get the remaining space on the partition
AVAILABLE_SPACE=$(df /data | awk '/dev\/block\/sda/ {print $4}')
PRETTY_SIZE=$(df -h /data | awk '/dev\/block\/sda/ {print $4}')
# then remove 0.5K from the size
IMG_SIZE=$(awk -v size="$AVAILABLE_SPACE" 'BEGIN { printf "%.1f", size - 0.5 }')
ui_print "Resizing rootfs to $PRETTY_SIZE";
e2fsck -fy /data/rootfs.img
resize2fs /data/rootfs.img "$IMG_SIZE"

mkdir /s;
mkdir /r;

# mount droidian rootfs
mount /data/rootfs.img /r;

# mount android rootfs
mount /r/var/lib/lxc/android/android-rootfs.img /s

# umount android rootfs
umount /s;

# If we should flash the kernel, do it
if [ -e "/r/boot/boot.img" ]; then
	ui_print "Kernel found, flashing"

	if [ -e "/r/boot/dtbo.img" ]; then
		has_dtbo="yes"
	else
		has_dtbo="no"
	fi

	if [ -e "/r/boot/vbmeta.img" ]; then
		has_vbmeta="yes"
	else
		has_vbmeta="no"
	fi

	current_slot=$(grep -o 'androidboot\.slot_suffix=_[a-b]' /proc/cmdline)
	case "${current_slot}" in
		"androidboot.slot_suffix=_a")
			target_partition="boot_a"
			target_dtbo_partition="dtbo_a"
			target_vbmeta_partition="vbmeta_a"
			;;
		"androidboot.slot_suffix=_b")
			target_partition="boot_b"
			target_dtbo_partition="dtbo_b"
			target_vbmeta_partition="vbmeta_b"
			;;
		"")
			# No A/B
			target_partition="boot"
			target_dtbo_partition="dtbo"
			target_vbmeta_partition="vbmeta"
			;;
		*)
			error "Unknown error while searching for a boot partition, exiting"
			;;
	esac

	partition=$(find /dev/block/platform -name ${target_partition} | head -n 1)
	if [ -n "${partition}" ]; then
		ui_print "Found boot partition for current slot ${partition}"

		dd if=/r/boot/boot.img of=${partition} || error "Unable to flash kernel"

		ui_print "Kernel flashed"
	fi

	if [ "${has_dtbo}" = "yes" ]; then
		ui_print "DTBO found, flashing"

		partition=$(find /dev/block/platform -name ${target_dtbo_partition} | head -n 1)
		if [ -n "${partition}" ]; then
			ui_print "Found DTBO partition for current slot ${partition}"

			dd if=/r/boot/dtbo.img of=${partition} || error "Unable to flash DTBO"

			ui_print "DTBO flashed"
		fi
	fi

	if [ "${has_vbmeta}" = "yes" ]; then
		ui_print "VBMETA found, flashing"

		partition=$(find /dev/block/platform -name ${target_vbmeta_partition} | head -n 1)
		if [ -n "${partition}" ]; then
			ui_print "Found VBMETA partition ${partition}"

			dd if=/r/boot/vbmeta.img of=${partition} || error "Unable to flash VBMETA"

			ui_print "VBMETA flashed"
		fi
	fi

fi

# umount droidian rootfs
umount /r;

# halium initramfs workaround,
# create symlink to android-rootfs inside /data
if [ ! -e /data/android-rootfs.img ]; then
	ln -s /halium-system/var/lib/lxc/android/android-rootfs.img /data/android-rootfs.img || true
fi

## end install
