# Droidian installer Script

OUTFD=/proc/self/fd/$1;

# ui_print <text>
ui_print() { echo -e "ui_print $1\nui_print" > $OUTFD; }

mv /data/droidian/data/rootfs.img /data/;

# resize rootfs
# first get the remaining space on the partition
AVAILABLE_SPACE=$(df /data | awk '/dev\/block\/sda/ {print $4}')
PRETTY_SIZE=$(df -h /data | awk '/dev\/block\/sda/ {print $4}')

# then remove 100MB (102400KB) from the size
# later on in case of kernel updates this story might come in handy.
# about the same amount is preserved for LVM images in the droidian--persistent and droidian--reserved partitions.
IMG_SIZE=$(awk -v size="$AVAILABLE_SPACE" 'BEGIN { printf "%.1f", size - 102400 }')
ui_print "Resizing rootfs to $PRETTY_SIZE";
e2fsck -fy /data/rootfs.img
resize2fs /data/rootfs.img "$IMG_SIZE"K

mkdir /r;

# mount droidian rootfs
mount /data/rootfs.img /r;

# If we should flash the kernel, do it
if [ -e "/r/boot/boot.img" ]; then
	ui_print "Kernel found, flashing"

	target_partition="boot"

	partition=$(find /dev/block/platform -name ${target_partition} | head -n 1)
	if [ -n "${partition}" ]; then
		ui_print "Found boot partition for current slot ${partition}"

		dd if=/r/boot/boot.img of=${partition} || error "Unable to flash kernel"

		ui_print "Kernel flashed"
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
