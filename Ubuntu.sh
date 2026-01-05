#!/bin/bash
# ==========================================
# UBUNTU VM CREATOR - 8 CORE OPTIMIZED
# ==========================================
# Features:
# - Auto-config Ubuntu 24.04 LTS
# - 8 vCPU / 4GB RAM / 20GB Disk
# - Interactive Login Sequence
# - No Expiration (Persistent User)
# ==========================================

set -euo pipefail

# ----------------- CONFIG -----------------
IMG_NAME="ubuntu-24.04-server-cloudimg-amd64.img"
IMG_URL="https://cloud-images.ubuntu.com/noble/current/${IMG_NAME}"
VM_DIR="${HOME}/ubuntu-vm"
VM_NAME="ubuntu-8core"
IMG_PATH="${VM_DIR}/${IMG_NAME}"
DISK_PATH="${VM_DIR}/${VM_NAME}.qcow2"
SSH_PORT="2222"
USERNAME="ubuntu"
PASSWORD="root" # Default password

# Resource Specs
VCPUS="8"
MEMORY="4096" # 4GB
DISK_SIZE="20G"

# ----------------- COLORS -----------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ----------------- FUNCTIONS -----------------

print_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   ${GREEN}UBUNTU VM - 8 CORE MANAGER${NC}         ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo
}

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Fungsi Login VPS Interaktif
interactive_ssh_login() {
    local port=$1
    local user=$2
    local host="127.0.0.1"

    echo
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo -e "${GREEN}🚀 VM IS READY!${NC}"
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo -e " Host: ${host}"
    echo -e " Port: ${port}"
    echo -e " User: ${user}"
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo

    # Loop login jika gagal atau user logout
    while true; do
        echo -ne "${YELLOW}🔑 Masukan Password untuk ${user}: ${NC}"
        read -s password_input
        echo # Newline
        
        # Validasi input kosong
        if [[ -z "$password_input" ]]; then
            log_warn "Password tidak boleh kosong! Coba lagi."
            continue
        fi

        # Coba koneksi SSH dengan expect/sshpass jika ada, atau manual
        # Di sini kita menggunakan ssh client standar dengan opsi -o untuk menghandle stty
        if sshpass -p "$password_input" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$port" "${user}@${host}" "echo 'Login Berhasil!'; exit" 2>/dev/null; then
            # Login sukses, jalankan shell interaktif
            log_success "Koneksi diterima. Membuka session..."
            sshpass -p "$password_input" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$port" "${user}@${host}"
            
            echo
            read -p "$(log_info "Tekan Enter untuk connect ulang atau 'q' untuk keluar: ")" reconnect
            if [[ "$reconnect" =~ ^[Qq]$ ]]; then
                break
            fi
        else
            log_error "Login Gagal! Password salah atau VM belum siap sepenuhnya."
            read -p "$(log_info "Tekan Enter untuk coba password lagi...")"
        fi
    done
}

# Setup Directories & Dependencies
setup_env() {
    mkdir -p "$VM_DIR"
    
    # Cek dependensi
    local deps=("qemu-system-x86_64" "qemu-img" "wget" "sshpass")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Dependency '$dep' tidak ditemukan."
            log_info "Install dengan: sudo apt install qemu-system qemu-utils wget sshpass"
            exit 1
        fi
    done

    # Cek dan download image base
    if [[ ! -f "$IMG_PATH" ]]; then
        log_info "Downloading Ubuntu Cloud Image (this may take a while)..."
        wget --progress=bar:force "$IMG_URL" -O "$IMG_PATH"
    fi

    # Copy image ke disk VM baru jika belum ada
    if [[ ! -f "$DISK_PATH" ]]; then
        log_info "Creating VM Disk (${DISK_SIZE})..."
        qemu-img create -f qcow2 -F qcow2 -b "$IMG_PATH" "$DISK_PATH" "$DISK_SIZE"
    fi
}

# Create Cloud-Init Configuration (No Expired)
create_cloud_init() {
    local seed_file="${VM_DIR}/seed.iso"
    
    # Buat user-data
    cat > "${VM_DIR}/user-data" <<EOF
#cloud-config
hostname: ubuntu-8core
manage_etc_hosts: true
timezone: Asia/Jakarta
users:
  - name: ${USERNAME}
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    # Hash password 'root'
    passwd: $6$rounds=4096$wWs.PP/h$9IqTmVxXh1VjFmPfJmGzYp1U1K4YJ1Q5X3Y3Z4a5B6c7D8e9F0g1H2i3J4k5L6m7
chpasswd:
  list: |
    ${USERNAME}:${PASSWORD}
    root:${PASSWORD}
  expire: false
ssh_pwauth: true
package_update: true
package_upgrade: false
runcmd:
  - echo "VM Configured Successfully" > /etc/motd
EOF

    # Buat meta-data
    cat > "${VM_DIR}/meta-data" <<EOF
instance-id: ubuntu-vm-8core
local-hostname: ubuntu-8core
EOF

    # Generate ISO Seed
    if command -v cloud-localds &> /dev/null; then
        cloud-localds "$seed_file" "${VM_DIR}/user-data" "${VM_DIR}/meta-data"
    else
        log_error "cloud-localds tidak ditemukan (package: cloud-image-utils)"
        exit 1
    fi
    
    echo "$seed_file"
}

start_vm() {
    local seed_file=$(create_cloud_init)

    log_info "Starting VM with ${VCPUS} Cores..."
    
    # Hentikan proses lama jika ada
    pkill -f "qemu-system.*$DISK_PATH" || true
    sleep 1

    # Jalankan VM (Headless / Nographic)
    # Menggunakan virtio untuk performa maksimal
    qemu-system-x86_64 \
        -enable-kvm \
        -m "$MEMORY" \
        -smp "$VCPUS" \
        -cpu host \
        -drive "file=${DISK_PATH},format=qcow2,if=virtio" \
        -drive "file=${seed_file},format=raw,if=virtio" \
        -netdev "user,id=net0,hostfwd=tcp::${SSH_PORT}-:22" \
        -device "virtio-net-pci,netdev=net0" \
        -vga none -nographic -serial mon:stdio \
        -display none \
        > /dev/null 2>&1 &

    log_success "VM Process Started (PID: $!)"
}

wait_for_ssh() {
    log_info "Waiting for VM to boot up and initialize SSH..."
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        # Cek port SSH
        if timeout 1 bash -c "cat < /dev/null > /dev/tcp/127.0.0.1/${SSH_PORT}" 2>/dev/null; then
            sleep 5 # Tunggu sedikit agar service ssh benar-benar siap menerima login
            log_success "SSH Service is Ready!"
            return 0
        fi
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    log_error "Gagal terhubung ke SSH dalam waktu yang ditentukan."
    return 1
}

# ----------------- MAIN EXECUTION -----------------

print_header

# 1. Persiapan Lingkungan
setup_env

# 2. Konfigurasi User
log_warn "Default Credentials:"
echo "  Username: ${USERNAME}"
echo "  Password: ${PASSWORD}"
read -p "$(log_info "Tekan Enter untuk memulai VM...")"

# 3. Start VM
start_vm

# 4. Tunggu Boot
wait_for_ssh

# 5. Masuk ke Mode Login Interaktif
interactive_ssh_login "$SSH_PORT" "$USERNAME"

log_info "Exiting script. VM masih berjalan di background."
log_info "Untuk mematikan VM manual: pkill -f 'qemu-system.*$DISK_PATH'"