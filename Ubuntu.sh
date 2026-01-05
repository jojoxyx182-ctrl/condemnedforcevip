#!/bin/bash
# =====================================================
# CONDEMNEDFORCE XYZ - USER MODE VM MANAGER (NO ROOT)
# Optimized for Non-Root Users (Background Screen Mode)
# Note: No Systemd/Auto-Boot (Requires Root perms)
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
# Gunakan Home Directory user yang sedang login
VM_DIR="${VM_DIR:-$HOME/force-vms}"
IS_ROOT=false
if [[ $EUID -eq 0 ]]; then
    IS_ROOT=true
fi

# ----------------- FUNCTIONS -----------------

display_header() {
    clear
    echo -e "\n  ${L_PILL}${BOLD} FORCEXYZ ${RESET}${R_PILL}${BOLD} USER MODE VM MANAGER ${RESET}"
    echo -e "  ${GRAY}──────────────────────────────────────────────────────${RESET}"
    if [[ "$IS_ROOT" == "true" ]]; then
        echo -e "  ${YELLOW}Running as ROOT (Full Features Enabled)${RESET}"
    else
        echo -e "  ${SUCCESS}Running as USER: $USER (No Root required)${RESET}"
    fi
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
        
        if [[ "$IS_ROOT" == "true" ]]; then
            print_status "INFO" "Installing dependencies..."
            apt-get update -qq
            apt-get install -y qemu-kvm cloud-image-utils wget lsof screen
        else
            print_status "ERROR" "You are not root. Please ask admin to install:"
            echo "  sudo apt-get install -y ${missing_deps[*]}"
            read -p "Press Enter to try anyway (might fail)..."
        fi
    fi
    
    # Check KVM Access Permission for User
    if [[ "$IS_ROOT" == "false" ]]; then
        if [[ ! -r /dev/kvm ]]; then
            print_status "WARN" "Cannot access /dev/kvm."
            print_status "INFO" "Trying to fix permissions..."
            # Try to add user to kvm group (requires sudo access usually)
            if command -v sudo &> /dev/null; then
                sudo usermod -aG kvm "$USER" 2>/dev/null || true
                sudo usermod -aG libvirt "$USER" 2>/dev/null || true
                print_status "INFO" "Please logout and login again for KVM group to take effect."
            else
                print_status "WARN" "No sudo access found. KVM might not work. VMs will be slow (TCG)."
            fi
        fi
    fi
}

validate_input() {
    local type=$1
    local value=$2
    
    case $type in
        "number") [[ "$value" =~ ^[0-9]+$ ]] ;;
        "size") [[ "$value" =~ ^[0-9]+[GgMm]$ ]] ;;
        "port") 
            # User biasa tidak boleh pakai port < 1024
            if [[ "$IS_ROOT" == "false" ]] && [ "$value" -le 1024 ]; then
                print_status "ERROR" "Non-root users cannot use ports <= 1024. Use >1024 (e.g., 2222)"
                return 1
            fi
            [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge 23 ] && [ "$value" -le 65535 ] 
            ;;
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
        unset VM_NAME OS_TYPE CODENAME IMG_URL HOSTNAME USERNAME PASSWORD
        unset DISK_SIZE MEMORY CPUS SSH_PORT GUI_MODE PORT_FORWARDS IMG_FILE SEED_FILE CREATED
        
        source "$config_file"
        return 0
    else
        print_status "ERROR" "Configuration for '$vm_name' not found"
        return 1
    fi
}

save_vm_config() {
    local config_file="$VM_DIR/$VM_NAME.conf"
    
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
EOF
}

is_vm_running() {
    local vm_name=$1
    
    # Cek via screen session
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

# ----------------- CORE VM FUNCTIONS (USER MODE) -----------------

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
            print_status "WARN" "Resize failed, image might be corrupted or wrong format."
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
    shell: //bin/bash
    password: $(openssl passwd -6 "$PASSWORD" | tr -d '\n')
chpasswd:
  list: |
    root:$PASSWORD
    $USERNAME:$PASSWORD
  expire: false
runcmd:
  - echo "Welcome to FORCEXYZ User Mode VM" > /etc/motd
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
    AUTO_START="false" # Disabled for non-root
    
    # Input Loop
    while true; do
        read -p "VM Name [$VM_NAME]: " input; VM_NAME="${input:-$VM_NAME}"
        validate_input "name" "$VM_NAME" && break || print_status "ERROR" "Invalid name"
    done

    read -p "Hostname [$HOSTNAME]: " input; HOSTNAME="${input:-$HOSTNAME}"
    read -p "Username [$USERNAME]: " input; USERNAME="${input:-$USERNAME}"
    read -sp "Password [Default: $DEFAULT_PASSWORD]: " input; echo; PASSWORD="${input:-$PASSWORD}"
    
    local total_mem=$(free -m | awk '/Mem:/ {print $2}')
    local suggested_mem=$((total_mem / 4))
    if [ $suggested_mem -lt 2048 ]; then suggested_mem=2048; fi
    
    read -p "Memory MB [Suggested: $suggested_mem]: " input; MEMORY="${input:-$suggested_mem}"
    read -p "CPUs [Suggested: $((nproc))]: " input; CPUS="${input:-$((nproc))}"
    read -p "Disk Size [$DISK_SIZE]: " input; DISK_SIZE="${input:-$DISK_SIZE}"
    
    while true; do
        print_status "WARN" "Non-root users cannot use ports < 1024."
        read -p "SSH Port [$SSH_PORT]: " input; SSH_PORT="${input:-$SSH_PORT}"
        validate_input "port" "$SSH_PORT" && break || print_status "ERROR" "Invalid port"
    done

    read -p "Enable GUI? (y/N): " input; GUI_MODE="${input:-false}"
    [[ "$GUI_MODE" =~ ^[Yy]$ ]] && GUI_MODE=true || GUI_MODE=false

    read -p "Extra Ports (host:guest): " PORT_FORWARDS
    
    IMG_FILE="$VM_DIR/$VM_NAME.img"
    SEED_FILE="$VM_DIR/$VM_NAME-seed.iso"
    CREATED="$(date)"
    
    setup_vm_image
    save_vm_config
    
    print_status "SUCCESS" "VM '$VM_NAME' created."
}

start_vm() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        if is_vm_running "$vm_name"; then
            print_status "WARN" "VM '$vm_name' is already running!"
            return 1
        fi
        
        print_status "INFO" "Starting VM: $vm_name ($MEMORY MB RAM, $CPUS vCPU)"
        
        # Kill stuck screen session
        screen -S "$vm_name" -X quit 2>/dev/null || true

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
            -vga virtio
        )

        # Port Forwarding
        if [[ -n "$PORT_FORWARDS" ]]; then
            IFS=',' read -ra forwards <<< "$PORT_FORWARDS"
            for forward in "${forwards[@]}"; do
                IFS=':' read -r host_port guest_port <<< "$forward"
                # Validasi port untuk user biasa
                if [[ "$IS_ROOT" == "false" ]] && [ "$host_port" -le 1024 ]; then
                    print_status "WARN" "Skipping port $host_port (requires root)."
                else
                    qemu_cmd+=(-netdev "user,id=fwd$host_port,hostfwd=tcp::$host_port-:$guest_port")
                    qemu_cmd+=(-device "virtio-net-pci,netdev=fwd$host_port")
                fi
            done
        fi

        # Display Mode
        if [[ "$GUI_MODE" == true ]]; then
            print_status "INFO" "GUI Mode: Using VNC"
            local vnc_port=$((5900 + (VM_NAME % 1000))) 
            qemu_cmd+=(-display vnc=:$((vnc_port-5900)))
        else
            qemu_cmd+=(-nographic -serial mon:stdio)
        fi

        print_status "INFO" "Launching in screen session '$vm_name'..."
        screen -dmS "$vm_name" bash -c "\"${qemu_cmd[@]}\""
        
        sleep 2
        if screen -list | grep -q "$vm_name"; then
            print_status "SUCCESS" "VM Started. SSH: ssh -p $SSH_PORT $USERNAME@localhost"
        else
            print_status "ERROR" "Failed to start VM."
        fi
    fi
}

stop_vm() {
    local vm_name=$1
    load_vm_config "$vm_name" || return 1
    
    print_status "INFO" "Stopping VM $vm_name..."
    
    screen -S "$vm_name" -X quit 2>/dev/null || true
    
    pkill -f "qemu-system.*$IMG_FILE" || true
    
    sleep 1
    if is_vm_running "$vm_name"; then
        print_status "WARN" "Force killing..."
        pkill -9 -f "qemu-system.*$IMG_FILE"
    fi
    
    print_status "SUCCESS" "VM Stopped."
}

delete_vm() {
    local vm_name=$1
    read -p "$(print_status "INPUT" "Delete $vm_name? Type 'YES' to confirm: ")" confirm
    if [[ "$confirm" != "YES" ]]; then
        print_status "INFO" "Cancelled."; return 0
    fi
    
    stop_vm "$vm_name"
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
    screen -r "$vm_name"
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
    echo "  SSH Port    : $SSH_PORT"
    echo "  Specs       : ${MEMORY}MB RAM | $CPUS vCPU | $DISK_SIZE Disk"
    echo "  Status      : $(is_vm_running "$vm_name" && echo -e "${SUCCESS}Running${RESET}" || echo -e "${GRAY}Stopped${RESET}")"
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
            0) exit 0 ;;
            *) print_status "ERROR" "Invalid option" ;;
        esac
        read -p "  Press Enter to continue..." dummy
    done
}

# ----------------- INIT -----------------
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

main_menu