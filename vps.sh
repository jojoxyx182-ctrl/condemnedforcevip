#!/bin/bash

# =====================================================
# FORCEXYZ - VPS / IDX MANAGER
# =====================================================

# =======================
# COLORS - FORCEXYZ STYLE
# =======================
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

# =======================
# FORCEXYZ HEADER
# =======================
print_jishnu_logo() {
    echo -e "\n  ${L_PILL}${BOLD} FORCEXYZ ${RESET}${R_PILL}${BOLD} VPS MANAGER ${RESET}"
    echo -e "  ${GRAY}──────────────────────────────────────────────────────${RESET}"
}

print_divider() {
    echo -e "  ${GRAY}──────────────────────────────────────────────────────${RESET}"
}

print_status() {
    echo -e "\n  ${MAIN}▶▶${RESET} ${WHITE}${1}${RESET}\n"
}

print_option() {
    local num="$1"
    local text="$2"
    printf "  ${MAIN}${BOLD}%s${RESET}  ${WHITE}%-30s${RESET}\n" "$num" "$text"
}

print_footer() {
    echo -e "\n  ${GRAY}──────────────────────────────────────────────────────${RESET}"
    echo -e "  ${DIM}FORCEXYZ © 2025 - All Rights Reserved${RESET}\n"
}

# =======================
# MAIN LOOP (ORIGINAL)
# =======================
while true; do
    clear
    print_jishnu_logo

    echo -e "\n  ${BOLD}${WHITE}MAIN OPTIONS${RESET}\n"

    print_option "1" "🚀 GitHub VPS Maker"
    print_option "2" "🔧 IDX Tool Setup"
    print_option "3" "⚡ IDX VPS Maker"
    print_option "4" "❌ Exit"

    print_divider
    echo -ne "  ${BOLD}Choice ${MAIN}❯${RESET} "
    read op

    case $op in

    1)
        clear
        print_jishnu_logo
        print_status "🚀 GITHUB VPS MAKER"

        RAM=16384
        CPU=8
        DISK_SIZE=100G
        CONTAINER_NAME=hopingboyz
        IMAGE_NAME=hopingboyz/debain12
        VMDATA_DIR="$PWD/vmdata"

        mkdir -p "$VMDATA_DIR"

        echo -e "  ${MAIN}RAM        :${WHITE} $RAM MB"
        echo -e "  ${MAIN}CPU        :${WHITE} $CPU cores"
        echo -e "  ${MAIN}DISK SIZE  :${WHITE} $DISK_SIZE"
        echo -e "  ${MAIN}NAME       :${WHITE} $CONTAINER_NAME"
        echo -e "  ${MAIN}IMAGE      :${WHITE} $IMAGE_NAME\n"

        docker run -it --rm \
          --name "$CONTAINER_NAME" \
          --device /dev/kvm \
          -v "$VMDATA_DIR":/vmdata \
          -e RAM="$RAM" \
          -e CPU="$CPU" \
          -e DISK_SIZE="$DISK_SIZE" \
          "$IMAGE_NAME"

        read -p "Press Enter to return..."
        ;;

    2)
        clear
        print_jishnu_logo
        print_status "🔧 IDX TOOL SETUP"

        cd ~ || exit
        rm -rf myapp flutter
        mkdir -p ~/vps123/.idx
        cd ~/vps123/.idx || exit

        cat <<EOF > dev.nix
{ pkgs, ... }: {
  channel = "stable-24.05";
  packages = with pkgs; [
    unzip openssh git qemu_kvm sudo cdrkit cloud-utils qemu
  ];
  env = { EDITOR = "nano"; };
}
EOF

        echo -e "  ${SUCCESS}✔ IDX Tool setup complete${RESET}"
        read -p "Press Enter to return..."
        ;;

    3)
        clear
        print_jishnu_logo
        print_status "⚡ IDX VPS MAKER"

        echo -e "  ${DIM}Executing remote script...${RESET}"
        bash <(curl -s https://rough-hall-1486.jishnumondal32.workers.dev)

        read -p "Press Enter to return..."
        ;;

    4)
        clear
        print_jishnu_logo
        echo -e "  ${SUCCESS}Session terminated. Goodbye!${RESET}"
        print_footer
        exit 0
        ;;

    *)
        echo -e "  ${ERROR}❌ Invalid option! Use 1-4 only.${RESET}"
        sleep 2
        ;;
    esac
done