#!/bin/bash

# =======================
# COLORS - FORCEXYZ THEME
# =======================
R="\e[38;5;51m"     # MAIN
G="\e[38;5;82m"     # SUCCESS
Y="\e[38;5;255m"    # WHITE
B="\e[38;5;39m"
C="\e[38;5;45m"
M="\e[38;5;93m"     # PURPLE
W="\e[38;5;255m"
N="\e[0m"
BOLD="\e[1m"

# =======================
# HEADER (REPLACE LOGO)
# =======================
print_jishnu_logo() {
    clear
    echo -e "\n  ${M}${BOLD} FORCEXYZ ${N}${R}${BOLD} VPS MANAGER ${N}"
    echo -e "  ${M}──────────────────────────────────────────────────────${N}\n"
}

print_divider() {
    echo -e "${M}──────────────────────────────────────────────────────────────${N}"
}

print_status() {
    echo -e "\n${R}▶▶${2} ${1}${N}\n"
}

print_option() {
    local num="$1"
    local text="$2"
    printf "  ${R}%s${N}  ${W}%s${N}\n" "$num." "$text"
}

print_footer() {
    echo -e "\n${M}──────────────────────────────────────────────────────────────${N}"
    echo -e "${W}FORCEXYZ © 2025 - All Rights Reserved${N}\n"
}

# =======================
# MAIN LOOP (ORI)
# =======================
while true; do
    print_jishnu_logo

    echo -e "${R}MAIN OPTIONS${N}\n"

    print_option "1" "🚀 GitHub VPS Maker"
    print_option "2" "🔧 IDX Tool Setup"
    print_option "3" "⚡ IDX VPS Maker"
    print_option "4" "❌ Exit"

    print_divider
    echo -ne "${R}▶▶${W} Select Option [1-4] : ${C}"
    read op
    echo -ne "${N}"

    case $op in

    1)
        print_jishnu_logo
        print_status "🚀 GITHUB VPS MAKER" "$R"

        RAM=16384
        CPU=8
        DISK_SIZE=100G
        CONTAINER_NAME=hopingboyz
        IMAGE_NAME=hopingboyz/debain12
        VMDATA_DIR="$PWD/vmdata"

        mkdir -p "$VMDATA_DIR"

        echo -e "${G}RAM        : ${W}$RAM MB"
        echo -e "${G}CPU        : ${W}$CPU cores"
        echo -e "${G}DISK SIZE  : ${W}$DISK_SIZE"
        echo -e "${G}NAME       : ${W}$CONTAINER_NAME"
        echo -e "${G}IMAGE      : ${W}$IMAGE_NAME\n"

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
        print_jishnu_logo
        print_status "🔧 IDX TOOL SETUP" "$R"

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

        echo -e "${G}✔ IDX Tool setup complete${N}"
        read -p "Press Enter to return..."
        ;;

    3)
        print_jishnu_logo
        print_status "⚡ IDX VPS MAKER" "$R"

        echo -e "${C}Executing remote script...${N}"
        bash <(curl -s https://raw.githubusercontent.com/jojoxyx182-ctrl/condemnedforcevip/refs/heads/main/os.sh)

        read -p "Press Enter to return..."
        ;;

    4)
        print_jishnu_logo
        echo -e "${G}Session terminated. Goodbye!${N}"
        print_footer
        exit 0
        ;;

    *)
        echo -e "${R}❌ Invalid option! Use 1-4 only.${N}"
        sleep 2
        ;;
    esac
done