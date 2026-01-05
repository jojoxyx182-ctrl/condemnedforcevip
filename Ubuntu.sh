#!/bin/bash
# ==========================================
# UBUNTU VM - 8 CORE (NO SSHPASS VERSION)
# ==========================================
# Fitur:
# - Support semua terminal (Linux/Mac/WSL)
# - Tanpa dependensi 'sshpass' (Pure Bash)
# - Auto-boot + Input Password Loop
# - Ubuntu 24.04 LTS Stable
# ==========================================

set -euo pipefail

# ----------------- CONFIG -----------------
IMG_NAME="ubuntu-24.04-server-cloudimg-amd64.img"
IMG_URL="https://cloud-images.ubuntu.com/noble/current/${IMG_NAME}"
VM_DIR="${HOME}/ubuntu-vm-auto"
VM_NAME="ubuntu-server"
IMG_PATH="${VM_DIR}/${IMG_NAME}"
DISK_PATH="${VM_DIR}/${VM_NAME}.qcow2"
SSH_PORT="2222"
USERNAME="ubuntu"

# Resource Specs (8 Core)
VCPUS="8"
MEMORY="4096"
DISK_SIZE="20G"

# ----------------- COLORS -----------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ----------------- FUNCTIONS -----------------

print_header() {
    clear
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║   ${GREEN}UBUNTU 24.04 - 8 CORE AUTOMATED${NC}      ${CYAN}${BOLD}║${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════╝${NC}"
    echo
}

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_dependencies() {
    local deps=("qemu-system-x86_64" "qemu-img" "wget")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Missing dependency: '$dep'"
            echo "Silakan install manual: sudo apt install qemu-system qemu-utils wget"
            exit 1
        fi
    done
}

# Fungsi Setup Password
setup_password() {
    while true; do
        echo
        echo -e "${YELLOW}══════════════════════════════════════════${NC}"
        echo -ne "${CYAN}🔑 Masukan Password Baru untuk user '${USERNAME}': ${NC}"
        read -s USER_PASS
        echo
        
        if [[ -z "$USER_PASS" ]]; then
            log_warn "Password tidak boleh kosong!"
            continue
        fi

        echo -ne "${CYAN}🔑 Ulangi Password: ${NC}"
        read -s USER_PASS_CONFIRM
        echo

        if [[ "$USER_PASS" == "$USER_PASS_CONFIRM" ]]; then
            log_success "Password disimpan!"
            break
        else
            log_error "Password tidak cocok, ulangi lagi."
        fi
    done
}

# Fungsi Download & Setup Image
setup_env() {
    mkdir -p "$VM_DIR"
    
    if [[ ! -f "$IMG_PATH" ]]; then
        log_info "Mengdownload Ubuntu Cloud Image (Sekali saja)..."
        wget --progress=bar:force "$IMG_URL" -O "$IMG_PATH" || {
            log_error "Gagal download image. Cek koneksi internet."
            exit 1
        }
    fi

    if [[ ! -f "$DISK_PATH" ]]; then
        log_info "Membuat Disk VM (${DISK_SIZE})..."
        qemu-img create -f qcow2 -F qcow2 -b "$IMG_PATH" "$DISK_PATH" "$DISK_SIZE"
    fi
}

# Generate Hash Password untuk cloud-init
generate_passwd_hash() {
    # Cara paling portabel tanpa python/perl complex
    # Kita gunakan openssl jika ada, fallback ke plaintext (ubuntu cloud img suport plaintext utk dev)
    if command -v openssl &> /dev/null; then
        openssl passwd -6 "$USER_PASS"
    else
        # Fallback jika openssl tidak ada (jarang terjadi)
        echo "$USER_PASS"
    fi
}

create_cloud_init() {
    local seed_file="${VM_DIR}/seed.iso"
    local pass_hash=$(generate_passwd_hash)

    cat > "${VM_DIR}/user-data" <<EOF
#cloud-config
hostname: ubuntu-8core
manage_etc_hosts: true
users:
  - name: ${USERNAME}
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: ${pass_hash}
chpasswd:
  list: |
    root:${pass_hash}
  expire: false
ssh_pwauth: true
runcmd:
  - echo "System Ready" > /etc/motd
EOF

    cat > "${VM_DIR}/meta-data" <<EOF
instance-id: ubuntu-vm-auto
local-hostname: ubuntu-8core
EOF

    # Buat ISO Seed
    if command -v cloud-localds &> /dev/null; then
        cloud-localds "$seed_file" "${VM_DIR}/user-data" "${VM_DIR}/meta-data"
    else
        log_error "Tool 'cloud-localds' tidak ditemukan."
        log_info "Install: sudo apt install cloud-image-utils"
        exit 1
    fi
    
    echo "$seed_file"
}

start_vm() {
    local seed_file=$(create_cloud_init)

    log_info "Menjalankan VM dengan ${VCPUS} Core..."
    
    # Kill zombie process jika ada
    pkill -f "qemu-system.*$DISK_PATH" || true
    sleep 1

    # Jalankan VM (Background, Headless)
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

    log_success "VM Berjalan (PID: $!)"
}

wait_and_login_manual() {
    local host="127.0.0.1"
    local port="$SSH_PORT"
    
    log_info "Menunggu VM booting dan SSH service aktif..."
    local max_wait=90
    local count=0
    
    # Loop cek koneksi port
    while [ $count -lt $max_wait ]; do
        if timeout 1 bash -c "cat < /dev/null > /dev/tcp/${host}/${port}" 2>/dev/null; then
            sleep 3 # Extra wait untuk stability
            break
        fi
        echo -n "."
        sleep 2
        ((count++))
    done
    
    echo
    if [ $count -ge $max_wait ]; then
        log_error "Timeout! VM tidak merespons SSH."
        log_info "Cek status manual: ssh -p ${port} ${USERNAME}@${host}"
        return 1
    fi

    log_success "VM SUDAH SIAP!"
    echo
    echo -e "${YELLOW}══════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}MODE KONEKSI MANUAL${NC}"
    echo -e "  Host: ${host}"
    echo -e "  Port: ${port}"
    echo -e "  User: ${USERNAME}"
    echo -e "${YELLOW}══════════════════════════════════════════${NC}"
    echo
    log_info "Silakan gunakan perintah di bawah ini di terminal baru (tab baru) untuk login:"
    echo -e "${CYAN}  ssh -p ${port} ${USERNAME}@${host}${NC}"
    echo
    
    read -p "Tekan Enter jika sudah mencoba login..."
}

# ----------------- MAIN -----------------

print_header
check_dependencies
setup_env

# 1. Input Password
setup_password

# 2. Start VM
start_vm

# 3. Tunggu & Info Login
wait_and_login_manual

log_info "Script selesai. VM tetap berjalan di latar belakang."
log_info "Untuk mematikan VM: pkill -f 'qemu-system.*$DISK_PATH'"