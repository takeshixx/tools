#!/bin/bash
# Extract kernel and initrd image
# files from a Linux image e.g.
# for using it for booting a QEMU
# VM. If there are .dtb files they
# will also be copied.
set -e
set -x
image=$1
outdir=$2

if [ $# -ne 2 -o ! -s "$image" -o ! -d "$outdir" ];then
    echo "Usage: ${0} <image> <outdir>" >&2
    exit 2
fi

# Create working directory
tmpdir=$(mktemp -dt bootfiles.XXXXXX)
mount="${tmpdir}/mount"
mkdir $mount
trap "sudo umount -f $mount && rm -rf $tmpdir" EXIT TERM

# Get boot partition offset and mount partition
offset=$(($(fdisk -l $image |awk '$2=="*" {print $3}')*512))
sudo mount -o ro,offset=$offset $image $mount

# Copy initrd.img and vmlinuz to target directory
sudo cp "${mount}/initrd.img" "${mount}/vmlinuz" $outdir

# If there are any .dtb files copy them as well
for dtb in $(find $mount -name \*.dtb);do
    sudo cp $dtb $outdir
done

sudo chown "${USER}" $outdir/*.dtb $outdir/initrd.img $outdir/vmlinuz
