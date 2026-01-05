#!/bin/bash
set -e

# ===== CONFIG =====
VM_NAME="vps-wa"
RAM=8192
CPU=8
DISK_SIZE=80G
SSH_PORT=2222

USERNAME="jojo"
PASSWORD="jojo"

IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
IMG_FILE="$VM_NAME.img"
SEED_FILE="$VM_NAME-seed.iso"

# ==================

echo "[+] Download Ubuntu 24.04 image..."
if [ ! -f "$IMG_FILE" ]; then
  wget -O base.img "$IMG_URL"
  qemu-img create -f qcow2 -b base.img "$IMG_FILE" $DISK_SIZE
fi

echo "[+] Create cloud-init config..."
cat > user-data <<EOF
#cloud-config
hostname: $VM_NAME
ssh_pwauth: true
disable_root: false
users:
  - name: $USERNAME
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    password: $(openssl passwd -6 "$PASSWORD")
chpasswd:
  expire: false
packages:
  - curl
  - git
  - nodejs
  - npm
EOF

cat > meta-data <<EOF
instance-id: $VM_NAME
local-hostname: $VM_NAME
EOF

cloud-localds "$SEED_FILE" user-data meta-data

echo "[+] Starting VPS..."
qemu-system-x86_64 \
  -enable-kvm \
  -m $RAM \
  -smp $CPU \
  -cpu host \
  -drive file=$IMG_FILE,format=qcow2,if=virtio \
  -drive file=$SEED_FILE,format=raw,if=virtio \
  -netdev user,id=net0,hostfwd=tcp::$SSH_PORT-:22 \
  -device virtio-net-pci,netdev=net0 \
  -nographic