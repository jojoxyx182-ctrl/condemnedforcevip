#!/bin/bash

# =====================================================
# FORCEXYZ - VPS / IDX MANAGER
# =====================================================

set -e

# ----------------- COLORS -----------------
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

# ----------------- ROOT CHECK -----------------
if [[ $EUID -ne 0 ]]; then
    echo -e "${ERROR}This script must be run as root${RESET}"
    exit 1
fi

# ----------------- UI -----------------
header() {
    clear
    echo -e "\n  ${L_PILL}${BOLD} FORCEXYZ ${RESET}${R_PILL}${BOLD} VPS MANAGER ${RESET}"
    echo -e "  ${GRAY}──────────────────────────────────────────────────────${RESET}\n"
}

divider() {
    echo -e "  ${GRAY}──────────────────────────────────────────────────────${RESET}"
}

status() {
    echo -e "\n  ${MAIN}▶▶${RESET} ${WHITE}${1}${RESET}\n"
}

menu_option() {
    printf "  ${MAIN}${BOLD}%s${RESET}  ${WHITE}%-30s${RESET}\n" "$1" "$2"
}

footer() {
    echo -e "\n  ${GRAY}──────────────────────────────────────────────────────${RESET}"
    echo -e "  ${DIM}FORCEXYZ © 2025 - All Rights Reserved${RESET}\n"
}

# ----------------- MAIN LOOP -----------------
while true; do
    header

    echo -e "  ${BOLD}${WHITE}MAIN MENU${RESET}\n"

    menu_option "1" "GitHub VPS Maker"
    menu_option "2" "IDX Tool Setup"
    menu_option "3" "IDX VPS Maker"
    menu_option "0" "Exit"

    divider
    echo -ne "  ${BOLD}Choice ${MAIN}❯${RESET} "
    read -r op

    case "$op" in

        1)
            header
            status "GITHUB VPS MAKER"

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

            echo -e "\n  ${DIM}Press ENTER to return...${RESET}"
            read
            ;;

        2)
            header
            status "IDX TOOL SETUP"

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

            echo -e "  ${SUCCESS}IDX Tool setup complete${RESET}"
            echo -e "\n  ${DIM}Press ENTER to return...${RESET}"
            read
            ;;

        3)
            header
            status "IDX VPS MAKER"

            echo -e "  ${DIM}Executing remote script...${RESET}\n"
            bash <(curl -fsSL https://rough-hall-1486.jishnumondal32.workers.dev)

            echo -e "\n  ${DIM}Press ENTER to return...${RESET}"
            read
            ;;

        0)
            footer
            exit 0
            ;;

        *)
            echo -e "  ${ERROR}Invalid option${RESET}"
            sleep 1
            ;;
    esac
done