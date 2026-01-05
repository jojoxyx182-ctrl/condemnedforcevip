#!/bin/bash
# =====================================================
# CONDEMNEDFORCE XYZ - ENTERPRISE VM MANAGER V2
# Optimized for High RAM / Multi-Core VPS (Ubuntu)
# Features: Background Mode, Auto-Reconnect, Systemd
# =====================================================

set -euo pipefail

# ----------------- COLORS & UI -----------------
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

L_PILL='\033[48;5;93m\033[38;5;255m'
R_PILL='\033[48;5;39m\033[38;5;16m'

MAIN='\033[38;5;51m'
WHITE='\033[38;5;255m'
GRAY='\033[38;5;242m'
SUCCESS='\033[38;5;82m'
ERROR='\033[38;5;196m'
YELLOW='\033[38;5;226m'

# ----------------- CONFIGURATION -----------------
# Direktori penyimpanan VM dan Data
VM_DIR="${VM_DIR:-/root/force-vms}"
SERVICE_DIR="/etc/systemd/system"

# ----------------- FUNCTIONS -----------------

display_header() {
    clear
    echo -e "\n  ${L_PILL}${BOLD} FORCEXYZ ${RESET}${R_PILL}${BOLD} ENTERPRISE VM MANAGER ${RESET}"
    echo -e "  ${GRAY}──────────────────────────────────────────────────────${RESET}"
    echo -e "  ${GRAY}Mode: High-Performance | Persistent: Systemd/Screen${RESET}"
    echo
}

print_status() {
    local type=$1
    local message=$2
    
    case $type in
        "INFO") echo -e "${MAIN}📋 [INFO]${RESET} $message" ;;
        "WARN") echo -e "${YELLOW}⚠️  [WARN]${RESET} $message" ;;
        "ERROR") echo -e "${ERROR}❌ [ERROR]${RESET} $message" ;;
        "SUCCESS") echo -e "${SUCCESS}✅ [SUCCESS]${RESET} $message" ;;
        "INPUT") echo -e "${MAIN}🎯 [INPUT]${RESET} $message" ;;
        *) echo "[$type] $message" ;;
    esac
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_status "ERROR" "Script ini harus dijalankan sebagai root (sudo/root user)."
        exit 1
    fi
}

check_dependencies() {
    local deps=("qemu-system-x86_64" "wget" "cloud-localds" "qemu-img" "lsof" "screen")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_status "WARN" "Missing dependencies: ${missing_deps[*]}"
        print_status "INFO" "Installing dependencies automatically..."
        apt-get update -qq
        apt-get install -y qemu-kvm cloud-image-utils wget lsof screen cpu-checker
        print_status "SUCCESS" "Dependencies installed."
    fi
    
    # Check KVM support
    if ! kvm-ok &> /dev/null; then
        print_status "WARN" "KVM acceleration not available, VMs might be slow."
    else
        print_status "SUCCESS" "KVM Acceleration Enabled."
    fi
}

validate_input() {
    local type=$1
    local value=$2
    
    case $type in
        "number") [[ "$value" =~ ^[0-9]+$ ]] ;;
        "size") [[ "$value" =~ ^[0-9]+[GgMm]$ ]] ;;
        "port") [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge 23 ] && [ "$value" -le 65535 ] ;;
        "name") [[ "$value" =~ ^[a-zA-Z0-9_-]+$ ]] ;;
        "username") [[ "$value" =~ ^[a-z_][a-z0-9_-]*$ ]] ;;
        *) return 0 ;;
    esac
}

cleanup_temp() {
    if [ -f "user-data" ]; then rm -f "user-data"; fi
    if [ -f "meta-data" ]; then rm -f "meta-data"; fi
}

get_vm_list() {
    find "$VM_DIR" -name "*.conf" -exec basename {} .conf \; 2>/dev/null | sort
}

load_vm_config() {
    local vm_name=$1
    local config_file="$VM_DIR/$vm_name.conf"
    
    if [[ -f "$config_file" ]]; then
        # Unset variables to prevent leakage
        unset VM_NAME OS_TYPE CODENAME IMG_URL HOSTNAME USERNAME PASSWORD
        unset DISK_SIZE MEMORY CPUS SSH_PORT GUI_MODE PORT_FORWARDS IMG_FILE SEED_FILE CREATED AUTO_START
        
        source "$config_file"
        return 0
    else
        print_status "ERROR" "Configuration for '$vm_name' not found"
        return 1
    fi
}

save_vm_config() {
    local config_file="$VM_DIR/$VM_NAME.conf"
    
    # Pastikan variabel penting ada
    AUTO_START="${AUTO_START:-false}"
    
    cat > "$config_file" <<EOF
VM_NAME="$VM_NAME"
OS_TYPE="$OS_TYPE"
CODENAME="$CODENAME"
IMG_URL="$IMG_URL"
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
DISK_SIZE="$DISK_SIZE"
MEMORY="$MEMORY"
CPUS="$CPUS"
SSH_PORT="$SSH_PORT"
GUI_MODE="$GUI_MODE"
PORT_FORWARDS="$PORT_FORWARDS"
IMG_FILE="$IMG_FILE"
SEED_FILE="$SEED_FILE"
CREATED="$CREATED"
AUTO_START="$AUTO_START"
EOF
}

is_vm_running() {
    local vm_name=$1
    # Cek via systemd service terlebih dahulu
    if systemctl is-active --quiet "vm-$vm_name.service"; then
        return 0
    fi
    # Fallback cek screen session (untuk backward compatibility)
    if screen -list | grep -q "$vm_name"; then
        return 0
    fi
    # Fallback cek proses qemu
    if load_vm_config "$vm_name" 2>/dev/null; then
        if pgrep -f "qemu-system.*$IMG_FILE" >/dev/null; then
            return 0
        fi
    fi
    return 1
}

# --- Fungsi Systemd Service ---

create_systemd_service() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        local service_file="$SERVICE_DIR/vm-$vm_name.service"
        
        # Cek apakah sudah ada
        if [[ -f "$service_file" ]]; then
            # Update config saja jika ada
            systemctl daemon-reload
            return 0
        fi

        print_status "INFO" "Creating systemd service for $vm_name..."
        
        cat > "$service_file" <<EOF
[Unit]
Description=QEMU VM $vm_name
After=network.target

[Service]
Type=simple
ExecStartPre=-/bin/rm -f ${IMG_FILE}.lock
ExecStart=$0 start-daemon $vm_name
ExecStop=$0 stop-daemon $vm_name
Restart=on-failure
RestartSec=5s
User=root
Group=kvm

# Logging
StandardOutput=journal
StandardError=journal

# Performance Tuning
LimitNOFILE=65536
LimitNPROC=65536
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        print_status "SUCCESS" "Systemd service created."
    fi
}

# ----------------- CORE VM FUNCTIONS -----------------

setup_vm_image() {
    print_status "INFO" "Preparing disk image..."
    
    mkdir -p "$VM_DIR"
    
    if [[ -f "$IMG_FILE" ]]; then
        print_status "INFO" "Image exists."
    else
        print_status "INFO" "Downloading $IMG_URL..."
        wget --progress=bar:force "$IMG_URL" -O "$IMG_FILE.tmp" || {
            print_status "ERROR" "Download failed!"
            rm -f "$IMG_FILE.tmp"
            exit 1
        }
        mv "$IMG_FILE.tmp" "$IMG_FILE"
    fi
    
    # Resize image logic
    if ! qemu-img info "$IMG_FILE" | grep -q "virtual size:.*$DISK_SIZE"; then
        print_status "INFO" "Resizing disk to $DISK_SIZE..."
        qemu-img resize "$IMG_FILE" "$DISK_SIZE" 2>/dev/null || {
            # Jika resize gagal (misal file corrupt), download ulang
            print_status "WARN" "Resize failed, redownloading base image..."
            rm -f "$IMG_FILE"
            setup_vm_image # Recursive call once
            return
        }
    fi

    # Cloud-init
    cat > user-data <<EOF
#cloud-config
hostname: $HOSTNAME
ssh_pwauth: true
disable_root: false
users:
  - name: $USERNAME
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    password: $(openssl passwd -6 "$PASSWORD" | tr -d '\n')
chpasswd:
  list: |
    root:$PASSWORD
    $USERNAME:$PASSWORD
  expire: false
runcmd:
  - echo "Welcome to FORCEXYZ Managed VM" > /etc/motd
EOF

    cat > meta-data <<EOF
instance-id: iid-$VM_NAME
local-hostname: $HOSTNAME
EOF

    cloud-localds "$SEED_FILE" user-data meta-data
    rm -f user-data meta-data
    print_status "SUCCESS" "Disk & Seed ready."
}

create_new_vm() {
    print_status "INFO" "Creating new VM configuration..."
    
    # OS Select
    local i=1
    local os_options=()
    for os in "${!OS_OPTIONS[@]}"; do
        echo "  $i) $os"
        os_options[$i]="$os"
        ((i++))
    done
    
    read -p "$(print_status "INPUT" "Select OS (1-${#OS_OPTIONS[@]}): ")" choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#OS_OPTIONS[@]} ]; then
        print_status "ERROR" "Invalid choice"; return 1;
    fi
    
    local os="${os_options[$choice]}"
    IFS='|' read -r OS_TYPE CODENAME IMG_URL DEFAULT_HOSTNAME DEFAULT_USERNAME DEFAULT_PASSWORD <<< "${OS_OPTIONS[$os]}"

    # Defaults
    VM_NAME="$DEFAULT_HOSTNAME"
    HOSTNAME="$VM_NAME"
    USERNAME="$DEFAULT_USERNAME"
    PASSWORD="$DEFAULT_PASSWORD"
    DISK_SIZE="20G"
    MEMORY="2048"
    CPUS="2"
    SSH_PORT="2222"
    GUI_MODE="false"
    AUTO_START="false"
    
    # Input Loop
    while true; do
        read -p "VM Name [$VM_NAME]: " input; VM_NAME="${input:-$VM_NAME}"
        validate_input "name" "$VM_NAME" && break || print_status "ERROR" "Invalid name"
    done

    read -p "Hostname [$HOSTNAME]: " input; HOSTNAME="${input:-$HOSTNAME}"
    read -p "Username [$USERNAME]: " input; USERNAME="${input:-$USERNAME}"
    read -sp "Password [Default: $DEFAULT_PASSWORD]: " input; echo; PASSWORD="${input:-$PASSWORD}"
    
    # Auto detect High Performance defaults
    local total_mem=$(free -m | awk '/Mem:/ {print $2}')
    local suggested_mem=$((total_mem / 4)) # Assign 25% of total RAM
    if [ $suggested_mem -lt 2048 ]; then suggested_mem=2048; fi
    
    read -p "Memory MB [Suggested: $suggested_mem]: " input; MEMORY="${input:-$suggested_mem}"
    read -p "CPUs [Suggested: Max Available]: " input; CPUS="${input:-$((nproc))}"
    
    read -p "Disk Size [$DISK_SIZE]: " input; DISK_SIZE="${input:-$DISK_SIZE}"
    
    while true; do
        read -p "SSH Port [$SSH_PORT]: " input; SSH_PORT="${input:-$SSH_PORT}"
        validate_input "port" "$SSH_PORT" && ! ss -tln 2>/dev/null | grep -q ":$SSH_PORT " && break || print_status "ERROR" "Port invalid or in use"
    done

    read -p "Enable GUI (VNC/SDL)? (y/N): " input; GUI_MODE="${input:-false}"
    [[ "$GUI_MODE" =~ ^[Yy]$ ]] && GUI_MODE=true || GUI_MODE=false
    
    read -p "Auto-start on boot? (y/N): " input; AUTO_START="${input:-false}"
    [[ "$AUTO_START" =~ ^[Yy]$ ]] && AUTO_START=true || AUTO_START=false

    read -p "Extra Ports (host:guest, comma sep): " PORT_FORWARDS
    
    IMG_FILE="$VM_DIR/$VM_NAME.img"
    SEED_FILE="$VM_DIR/$VM_NAME-seed.iso"
    CREATED="$(date)"
    
    setup_vm_image
    save_vm_config
    create_systemd_service
    
    # Enable auto-start if requested
    if [[ "$AUTO_START" == "true" ]]; then
        systemctl enable "vm-$VM_NAME.service" >/dev/null 2>&1
    fi
    
    print_status "SUCCESS" "VM '$VM_NAME' created. Ready to start."
}

start_vm() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        if is_vm_running "$vm_name"; then
            print_status "WARN" "VM '$vm_name' is already running!"
            return 1
        fi
        
        print_status "INFO" "Starting VM: $vm_name ($MEMORY MB RAM, $CPUS vCPU)"
        
        # Use Systemd to start (Recommended)
        if systemctl list-unit-files | grep -q "vm-$vm_name.service"; then
            systemctl start "vm-$vm_name.service"
            sleep 2
            if is_vm_running "$vm_name"; then
                print_status "SUCCESS" "VM Started via Systemd."
                print_status "INFO" "Attach to console using Main Menu > Attach VM"
            else
                print_status "ERROR" "Failed to start (Check logs: journalctl -u vm-$vm_name)"
            fi
        else
            print_status "WARN" "No systemd service found, starting in legacy screen mode..."
            start_vm_legacy_screen "$vm_name"
        fi
    fi
}

# Legacy Screen Start (Used internally by systemd or if service missing)
start_vm_legacy_screen() {
    local vm_name=$1
    load_vm_config "$vm_name" || return 1
    
    # Kill screen session if stuck
    screen -S "$vm_name" -X quit 2>/dev/null || true

    local qemu_cmd=(
        qemu-system-x86_64
        -enable-kvm
        -m "$MEMORY"
        -smp "$CPUS,sockets=1,cores=$CPUS,threads=1"
        -cpu host,+hv_relaxed,+hv_time,+hv_vapic,+hv_spinlocks=0x2000
        -drive "file=$IMG_FILE,format=qcow2,if=virtio,cache=writeback"
        -drive "file=$SEED_FILE,format=raw,if=virtio"
        -netdev "user,id=n0,hostfwd=tcp::$SSH_PORT-:22"
        -device virtio-net-pci,netdev=n0
        -device virtio-rng-pci
        -vga virtio
    )

    # Port Forwarding
    if [[ -n "$PORT_FORWARDS" ]]; then
        IFS=',' read -ra forwards <<< "$PORT_FORWARDS"
        for forward in "${forwards[@]}"; do
            IFS=':' read -r host_port guest_port <<< "$forward"
            qemu_cmd+=(-device "virtio-net-pci,netdev=n$host_port")
            qemu_cmd+=(-netdev "user,id=n$host_port,hostfwd=tcp::$host_port-:$guest_port")
        done
    fi

    # Display Mode
    if [[ "$GUI_MODE" == true ]]; then
        print_status "INFO" "GUI Mode Enabled (VNC/SDL) - Not supported via Screen usually, using Headless with VNC"
        # VNC setup
        local vnc_port=$((5900 + (SSH_PORT % 1000))) # Simple VNC port algo
        qemu_cmd+=(-display vnc=:$((vnc_port-5900)))
        print_status "INFO" "Connect VNC to localhost:$vnc_port"
    else
        qemu_cmd+=(-nographic -serial mon:stdio)
    fi

    print_status "INFO" "Launching in screen session '$vm_name'..."
    
    # Detach screen immediately
    screen -dmS "$vm_name" bash -c "\"${qemu_cmd[@]}\""
    
    sleep 2
    if screen -list | grep -q "$vm_name"; then
        print_status "SUCCESS" "VM is running in background."
        print_status "INFO" "SSH: ssh -p $SSH_PORT $USERNAME@localhost"
    else
        print_status "ERROR" "Failed to start VM."
    fi
}

# Wrapper for systemd ExecStart
start_daemon() {
    # This function is called by systemd directly. 
    # We need to run qemu directly, not screen, for systemd to manage the PID correctly.
    # HOWEVER, to keep the "Attach" feature working easily for the user via this script,
    # we will still use screen here but systemd will manage the screen process.
    
    local vm_name=$1
    load_vm_config "$vm_name" || exit 1
    
    # Reconstruct command without screen
    local qemu_cmd=(
        qemu-system-x86_64
        -enable-kvm
        -m "$MEMORY"
        -smp "$CPUS"
        -cpu host
        -drive "file=$IMG_FILE,format=qcow2,if=virtio"
        -drive "file=$SEED_FILE,format=raw,if=virtio"
        -netdev "user,id=n0,hostfwd=tcp::$SSH_PORT-:22"
        -device virtio-net-pci,netdev=n0
        -device virtio-rng-pci
        -nographic
        -serial mon:stdio
    )
    
    # Add ports
    if [[ -n "$PORT_FORWARDS" ]]; then
        IFS=',' read -ra forwards <<< "$PORT_FORWARDS"
        for forward in "${forwards[@]}"; do
            IFS=':' read -r h_port g_port <<< "$forward"
            qemu_cmd+=(-netdev "user,id=fwd$h_port,hostfwd=tcp::$h_port-:$g_port")
            qemu_cmd+=(-device "virtio-net-pci,netdev=fwd$h_port")
        done
    fi

    # Run qemu directly (systemd will handle persistence)
    exec "${qemu_cmd[@]}"
}

stop_vm() {
    local vm_name=$1
    load_vm_config "$vm_name" || return 1
    
    print_status "INFO" "Stopping VM $vm_name..."
    
    if systemctl list-unit-files | grep -q "vm-$vm_name.service"; then
        systemctl stop "vm-$vm_name.service"
    fi
    
    # Kill screen session too
    screen -S "$vm_name" -X quit 2>/dev/null || true
    
    # Force kill qemu
    pkill -f "qemu-system.*$IMG_FILE" || true
    
    sleep 1
    if is_vm_running "$vm_name"; then
        print_status "WARN" "Force killing..."
        pkill -9 -f "qemu-system.*$IMG_FILE"
    fi
    
    print_status "SUCCESS" "VM Stopped."
}

stop_daemon() {
    # Wrapper for systemd ExecStop
    local vm_name=$1
    load_vm_config "$vm_name" 2>/dev/null || true
    pkill -f "qemu-system.*$IMG_FILE" || true
}

delete_vm() {
    local vm_name=$1
    read -p "$(print_status "INPUT" "Delete $vm_name? Type 'YES' to confirm: ")" confirm
    if [[ "$confirm" != "YES" ]]; then
        print_status "INFO" "Cancelled."; return 0
    fi
    
    stop_vm "$vm_name"
    
    # Disable/Remove Service
    if [ -f "$SERVICE_DIR/vm-$vm_name.service" ]; then
        systemctl disable "vm-$vm_name.service" >/dev/null 2>&1
        rm -f "$SERVICE_DIR/vm-$vm_name.service"
        systemctl daemon-reload
    fi
    
    rm -f "$IMG_FILE" "$SEED_FILE" "$VM_DIR/$vm_name.conf"
    print_status "SUCCESS" "VM Deleted."
}

attach_vm() {
    local vm_name=$1
    if ! is_vm_running "$vm_name"; then
        print_status "ERROR" "VM is not running."; return 1
    fi
    
    print_status "INFO" "Attaching to $vm_name console..."
    print_status "WARN" "Press Ctrl+A then D to detach without stopping."
    
    # If running via systemd (direct qemu), we might need to find the screen session created by legacy start
    # Or we rely on the fact that we used screen in the legacy mode.
    # Since V2 uses systemd->direct qemu by default, screen attaching is tricky unless we started it with screen.
    
    # Hybrid approach: Check if screen session exists
    if screen -list | grep -q "$vm_name"; then
        screen -r "$vm_name"
    else
        print_status "INFO" "VM is running in 'Headless Systemd' mode. Use SSH to connect."
        print_status "INFO" "SSH Port: $SSH_PORT | User: $USERNAME"
        read -p "Press Enter to switch to Screen Mode (Requires Restart)? (y/N): " sw
        if [[ "$sw" =~ ^[Yy]$ ]]; then
            print_status "WARN" "Stopping VM and restarting in Screen Mode..."
            stop_vm "$vm_name"
            start_vm_legacy_screen "$vm_name"
            sleep 2
            screen -r "$vm_name"
        fi
    fi
}

show_info() {
    local vm_name=$1
    load_vm_config "$vm_name" || return 1
    clear
    display_header
    echo -e "  ${BOLD}${WHITE}VM DETAILS${RESET}"
    echo "  ──────────────────────────────────────"
    echo "  Name        : $VM_NAME"
    echo "  OS          : $OS_TYPE $CODENAME"
    echo "  Hostname    : $HOSTNAME"
    echo "  User/Pass   : $USERNAME / $PASSWORD"
    echo "  SSH Port    : $SSH_PORT (ssh -p $SSH_PORT $USERNAME@localhost)"
    echo "  Specs       : ${MEMORY}MB RAM | $CPUS vCPU | $DISK_SIZE Disk"
    echo "  Status      : $(is_vm_running "$vm_name" && echo -e "${SUCCESS}Running${RESET}" || echo -e "${GRAY}Stopped${RESET}")"
    echo "  Auto Start  : $AUTO_START"
    echo "  Image Path  : $IMG_FILE"
    echo "  ──────────────────────────────────────"
    echo
}

# ----------------- MAIN MENU -----------------

main_menu() {
    while true; do
        display_header
        local vms=($(get_vm_list))
        local count=${#vms[@]}
        
        if [ $count -gt 0 ]; then
            echo -e "  ${BOLD}${WHITE}AVAILABLE VMS${RESET}"
            for i in "${!vms[@]}"; do
                local status=$(is_vm_running "${vms[$i]}" && echo "${SUCCESS}●${RESET}" || echo "${GRAY}○${RESET}")
                printf "   ${MAIN}%2d)${RESET} %s %s\n" $((i+1)) "${vms[$i]}" "$status"
            done
            echo
        fi
        
        echo -e "  ${BOLD}${WHITE}MANAGEMENT${RESET}"
        echo "   1) Create New VM"
        [ $count -gt 0 ] && echo "   2) Start VM"
        [ $count -gt 0 ] && echo "   3) Stop VM"
        [ $count -gt 0 ] && echo "   4) Restart VM"
        [ $count -gt 0 ] && echo "   5) Attach to Console (Screen)"
        [ $count -gt 0 ] && echo "   6) VM Info"
        [ $count -gt 0 ] && echo "   7) Delete VM"
        [ $count -gt 0 ] && echo "   8) Toggle Auto-Start"
        echo "   0) Exit"
        echo
        read -p "  Select option: " opt
        
        case $opt in
            1) create_new_vm ;;
            2) 
                read -p "  VM Number: " num
                [ "$num" -ge 1 ] && [ "$num" -le $count ] && start_vm "${vms[$((num-1))]}"
                ;;
            3)
                read -p "  VM Number: " num
                [ "$num" -ge 1 ] && [ "$num" -le $count ] && stop_vm "${vms[$((num-1))]}"
                ;;
            4)
                read -p "  VM Number: " num
                [ "$num" -ge 1 ] && [ "$num" -le $count ] && { stop_vm "${vms[$((num-1))]}"; start_vm "${vms[$((num-1))]}"; }
                ;;
            5)
                read -p "  VM Number: " num
                [ "$num" -ge 1 ] && [ "$num" -le $count ] && attach_vm "${vms[$((num-1))]}"
                ;;
            6)
                read -p "  VM Number: " num
                [ "$num" -ge 1 ] && [ "$num" -le $count ] && show_info "${vms[$((num-1))]}"
                ;;
            7)
                read -p "  VM Number: " num
                [ "$num" -ge 1 ] && [ "$num" -le $count ] && delete_vm "${vms[$((num-1))]}"
                ;;
            8)
                read -p "  VM Number: " num
                if [ "$num" -ge 1 ] && [ "$num" -le $count ]; then
                    local vm="${vms[$((num-1))]}"
                    load_vm_config "$vm"
                    if [[ "$AUTO_START" == "true" ]]; then
                        AUTO_START="false"
                        systemctl disable "vm-$vm.service" 2>/dev/null || true
                        print_status "SUCCESS" "Auto-start disabled for $vm"
                    else
                        AUTO_START="true"
                        systemctl enable "vm-$vm.service" 2>/dev/null || true
                        print_status "SUCCESS" "Auto-start enabled for $vm"
                    fi
                    save_vm_config
                fi
                ;;
            0) exit 0 ;;
            *) print_status "ERROR" "Invalid option" ;;
        esac
        read -p "  Press Enter to continue..." dummy
    done
}

# ----------------- INIT -----------------
check_root
check_dependencies
trap cleanup_temp EXIT

# OS Lists (Updated)
declare -A OS_OPTIONS=(
    ["Ubuntu 22.04"]="ubuntu|jammy|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img|ubuntu22|ubuntu|ubuntu"
    ["Ubuntu 24.04"]="ubuntu|noble|https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img|ubuntu24|ubuntu|ubuntu"
    ["Debian 12"]="debian|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|debian12|debian|debian"
    ["Debian 13 (Daily)"]="debian|trixie|https://cloud.debian.org/images/cloud/trixie/daily/latest/debian-13-generic-amd64-daily.qcow2|debian13|debian|debian"
    ["Fedora 40"]="fedora|40|https://download.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/x86_64/images/Fedora-Cloud-Base-40-1.14.x86_64.qcow2|fedora40|fedora|fedora"
    ["CentOS Stream 9"]="centos|stream9|https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2|centos9|centos|centos"
)

mkdir -p "$VM_DIR"

# Check if script is called by systemd internally
if [[ "${1:-}" == "start-daemon" ]]; then
    start_daemon "$2"
    exit $?
elif [[ "${1:-}" == "stop-daemon" ]]; then
    stop_daemon "$2"
    exit $?
fi

main_menu