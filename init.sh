#!/bin/bash

set -e

PERSISTENT_DIR="/persistent"
MARKER_FILE="$PERSISTENT_DIR/.root_fs_copied"

echo "[$(date)] Starting initialization script..."

if [ ! -f "$MARKER_FILE" ]; then
    echo "[$(date)] First boot detected. Copying root filesystem to persistent volume..."
    
    mkdir -p "$PERSISTENT_DIR"
    
    rsync -avx --exclude=/persistent --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/run --exclude=/tmp / "$PERSISTENT_DIR/"
    
    mkdir -p "$PERSISTENT_DIR/proc" "$PERSISTENT_DIR/sys" "$PERSISTENT_DIR/dev" "$PERSISTENT_DIR/run" "$PERSISTENT_DIR/tmp" "$PERSISTENT_DIR/persistent"
    
    touch "$MARKER_FILE"
    echo "[$(date)] Root filesystem successfully copied to persistent volume"
else
    echo "[$(date)] Persistent root filesystem already exists, skipping copy"
fi

echo "[$(date)] Mounting essential filesystems for chroot..."
mount -t proc /proc "$PERSISTENT_DIR/proc"
mount -t sysfs /sys "$PERSISTENT_DIR/sys"
mount -o bind /dev "$PERSISTENT_DIR/dev"
mount -o bind /dev/pts "$PERSISTENT_DIR/dev/pts"
mount -t tmpfs tmpfs "$PERSISTENT_DIR/run"
mount -t tmpfs tmpfs "$PERSISTENT_DIR/tmp"

mkdir -p "$PERSISTENT_DIR/persistent"
mount -o bind "$PERSISTENT_DIR" "$PERSISTENT_DIR/persistent"

echo "[$(date)] Setting up SSH configuration..."
sed -i 's/#Port 22/Port 2222/' "$PERSISTENT_DIR/etc/ssh/sshd_config"
mkdir -p "$PERSISTENT_DIR/run/sshd"

echo "[$(date)] Chrooting into persistent filesystem and starting SSH server..."
exec chroot "$PERSISTENT_DIR" /usr/sbin/sshd -D
