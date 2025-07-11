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
    
    # Mount necessary filesystems for package installation
    mount -t proc /proc "$PERSISTENT_DIR/proc"
    mount -t sysfs /sys "$PERSISTENT_DIR/sys"
    mount -o bind /dev "$PERSISTENT_DIR/dev"
    mount -o bind /dev/pts "$PERSISTENT_DIR/dev/pts"
    mount -t tmpfs tmpfs "$PERSISTENT_DIR/tmp"
    
    # Install Docker in the chroot environment
    echo "[$(date)] Installing Docker in chroot environment..."
    chroot "$PERSISTENT_DIR" apt-get update
    chroot "$PERSISTENT_DIR" apt-get install -y docker.io
    chroot "$PERSISTENT_DIR" rm -rf /var/lib/apt/lists/*
    
    # Unmount filesystems after installation
    umount "$PERSISTENT_DIR/tmp"
    umount "$PERSISTENT_DIR/dev/pts"
    umount "$PERSISTENT_DIR/dev"
    umount "$PERSISTENT_DIR/sys"
    umount "$PERSISTENT_DIR/proc"
    
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

# Mount cgroup filesystems for Docker
echo "[$(date)] Mounting cgroup filesystems..."
mkdir -p "$PERSISTENT_DIR/sys/fs/cgroup"
mount -t cgroup2 cgroup2 "$PERSISTENT_DIR/sys/fs/cgroup" || mount -t cgroup cgroup "$PERSISTENT_DIR/sys/fs/cgroup"

mkdir -p "$PERSISTENT_DIR/persistent"
mount -o bind "$PERSISTENT_DIR" "$PERSISTENT_DIR/persistent"

echo "[$(date)] Setting up SSH configuration..."
sed -i 's/#Port 22/Port 2222/' "$PERSISTENT_DIR/etc/ssh/sshd_config"
mkdir -p "$PERSISTENT_DIR/run/sshd"

# Create a startup script that will run Docker inside the chroot
cat > "$PERSISTENT_DIR/usr/local/bin/start-docker.sh" << 'EOF'
#!/bin/bash
if [ ! -S /var/run/docker.sock ]; then
    echo "Starting Docker daemon..."
    dockerd > /var/log/docker.log 2>&1 &
    
    # Wait for Docker to start
    for i in {1..30}; do
        if [ -S /var/run/docker.sock ]; then
            echo "Docker daemon started successfully"
            break
        fi
        sleep 1
    done
fi
EOF
chmod +x "$PERSISTENT_DIR/usr/local/bin/start-docker.sh"

# Add Docker startup to profile
cat > "$PERSISTENT_DIR/etc/profile.d/docker-start.sh" << 'EOF'
# Start Docker if not running
if [ "$USER" = "root" ] && [ ! -S /var/run/docker.sock ]; then
    /usr/local/bin/start-docker.sh
fi
EOF
chmod +x "$PERSISTENT_DIR/etc/profile.d/docker-start.sh"

echo "[$(date)] Chrooting into persistent filesystem and starting SSH server..."
exec chroot "$PERSISTENT_DIR" /usr/sbin/sshd -D