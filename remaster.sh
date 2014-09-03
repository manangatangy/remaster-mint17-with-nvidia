#!/bin/bash

WORK=`pwd -P`
ISOPATH=$2
ISOMNT=$WORK/isomnt
UNPACKED=$WORK/unpacked
FSROOT=$WORK/fsroot
NVIDVERS=$2
NEWISOPATH=$2
ISOLABEL=$3
PROGNAME=`basename $0`

case "$1" in
"unpack" )
	if [ $# -ne 2 ] ; then
		echo "error: no iso-path specified" && exit 1
	fi
	if [ -e $ISOMNT ] ; then
		echo "error: mount point $ISOMNT already exists, try clean step" && exit 1
	fi
	if [ -e $UNPACKED ] ; then
		echo "error: unpacked iso $UNPACKED already exists, try clean step" && exit 1
	fi
	if [ -e $FSROOT ] ; then
		echo "error: squashfs root $FSROOT already exists, try clean step" && exit 1
	fi
	if [ ! -e $ISOPATH ] ; then
		echo "error: source iso $ISOPATH doesn't exist" && exit 1
	fi

	mkdir $ISOMNT 
	sudo mount -o loop $ISOPATH $ISOMNT
	mkdir $UNPACKED
	echo "$PROGNAME: copying from $ISOMNT/ to $UNPACKED ... please wait"
	sudo rsync -a $ISOMNT/ $UNPACKED
	sudo unsquashfs -dest $FSROOT $UNPACKED/casper/filesystem.squashfs
	sudo umount $ISOMNT
	rmdir $ISOMNT
	sudo cp /etc/resolv.conf $FSROOT/etc/

	echo "$PROGNAME: unpack completed, next step is modify, or pack"
	exit 0
;;
"modify" )
	sudo mount --bind /dev/ $FSROOT/dev
	sudo chroot $FSROOT mount -t proc none /proc
	sudo chroot $FSROOT mount -t sysfs none /sys
	sudo chroot $FSROOT mount -t devpts none /dev/pts

	if [ $# -gt 1 ] ; then
		echo "$PROGNAME: installing nvidia driver version $NVIDVERS ..."
		sudo chroot $FSROOT add-apt-repository ppa:xorg-edgers/ppa -y
		sudo chroot $FSROOT apt-get update

		sudo chroot $FSROOT apt-get install --assume-yes nvidia-$NVIDVERS
		# the above will output that it recommends packages: nvidia-settings nvidia-prime 
		# bumblebee libcuda1-340 nvidia-libopencl1-340 nvidia-opencl-icd-340
		# we dont want bumblebee (its for laptops)
		sudo chroot $FSROOT apt-get install --assume-yes nvidia-settings
		sudo chroot $FSROOT apt-get install --assume-yes nvidia-prime 
		sudo chroot $FSROOT apt-get install --assume-yes libcuda1-$NVIDVERS 
		sudo chroot $FSROOT apt-get install --assume-yes nvidia-libopencl1-$NVIDVERS 
		sudo chroot $FSROOT apt-get install --assume-yes nvidia-opencl-icd-$NVIDVERS
	fi

	echo "*** make your mods in the chroot shell, and then"
	echo "*** history -c (if you wish to be tidy) before exiting"
	sudo chroot $FSROOT
	
	sudo chroot $FSROOT umount /dev/pts
	sudo chroot $FSROOT umount /sys
	sudo chroot $FSROOT umount /proc
	sudo umount $FSROOT/dev

	echo "$PROGNAME: next step is pack (or more modify)"
	exit 0
;;
"pack" )
	if [ $# -lt 2 ] ; then
		echo "error: no new-iso-path specified" && exit 1
	fi
	if [ -e $NEWISOPATH ] ; then
		echo "error: new iso path $NEWISOPATH already exists, I won't overwrite it" && exit 1
	fi
	if [ $# -lt 3 ] ; then
		ISOLABEL="Linux_Mint_Remaster"
	fi

	echo "$PROGNAME: cleaning $FSROOT a little ..."
	sudo chroot $FSROOT aptitude purge ~c
	sudo chroot $FSROOT aptitude unmarkauto ~M
	sudo chroot $FSROOT apt-get clean
	sudo chroot $FSROOT apt-get autoremove
	sudo chroot $FSROOT rm -rf var/cache/debconf/*.dat-old var/lib/aptitude/*.old 
	sudo chroot $FSROOT rm -rf var/lib/dpkg/*-old var/cache/apt/*.bin
	sudo chroot $FSROOT updatedb
	sudo chroot $FSROOT rm root/.bash_history
	sudo chroot $FSROOT rm root/.nano_history

	echo "$PROGNAME: squashing $FSROOT ..."
	sudo rm $UNPACKED/casper/filesystem.squashfs
	sudo mksquashfs $FSROOT $UNPACKED/casper/filesystem.squashfs

	echo "$PROGNAME: checksumming ..."
	cd $FSROOT
	sudo rm md5sum.txt
	find -type f -print0 | sudo xargs -0 md5sum | grep -v isolinux/boot.cat | sudo tee md5sum.txt
	cd ..

	echo "$PROGNAME: making new iso $NEWISOPATH with label $ISOLABEL ..."
	sudo mkisofs -r -V "$ISOLABEL" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o $NEWISOPATH $UNPACKED

	echo "$PROGNAME: pack completed, next step is clean (or repeat modify, and pack cycle)"
	exit 0
;;
"clean" )
	sudo chroot $FSROOT umount /dev/pts
	sudo chroot $FSROOT umount /sys
	sudo chroot $FSROOT umount /proc
	sudo umount $FSROOT/dev

	echo "$PROGNAME: removing $FSROOT and $UNPACKED ..."
	sudo rm -rf $FSROOT
	sudo rm -rf $UNPACKED
	sudo umount $ISOMNT
	rmdir $ISOMNT

	echo "$PROGNAME: clean completed"
	exit 0
;;
esac

cat <<EOF
usage `basename $0` unpack|modify|pack|clean

This is a simple script that creates a remastered Linux Mint live iso.
My need was to have a mint install that supports the Nvidia GT750 but 
not to have to go throught all the difficulty of installing the driver, 
after installing mint. This is not straightforward due to;  clashes with 
nouveau, and not being able to load drivers while X is running, etc.

You should use this script in several steps;

`basename $0` unpack <iso-path>
	The specified iso file (the source linux mint distribution file) is 
	mounted read-only into ./isomnt, copied into ./unpacked, with the
	root filesystem then unsquashed into ./fsroot.  Note that if
	any of these paths already exist, then the script will abort.
	It then copies over the host's resolv.conf (for network access).
	Note that the ./isomnt point is only used for this step and is
	removed automatically at the end of this step.

`basename $0` modify <optional-nvidia-driver-version>
	This sets up the ./fsroot path (from the previous step) as a
	chroot environment by binding to the host OS's dev directory and 
	mounting the chroot's proc, sysfs, and devpts devices. It then starts
	a chrooted interactive shell.  The user may now modify the file
	system, using non X-gui tools, and then exit.  If the optional 
	argument such as "340" is provided, then the specified nvidia version
	package will be installed from the ppa:xorg-edgers repository.
	This step maybe repeated multiple times.

`basename $0` pack <new-iso-path> <optional-iso-label>
	This step requires the existence of the ./fsroot path, which it
	cleans up and then squashes back into the ./unpacked path (which must
	also exist). It then does the checksum and uses ./unpacked to create a
	new iso file, ready for installing.

`basename $0` clean

	Removes the ./isomnt, ./unpacked and ./fsroot paths
	
EOF
exit 0


