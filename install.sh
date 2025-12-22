#!/bin/bash

# =====================================================
# CONDEMNEDFORCE XYZ - HOSTING MANAGER
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
    echo -e "\n  ${L_PILL}${BOLD} FORCEXYZ ${RESET}${R_PILL}${BOLD} HOSTING MANAGER ${RESET}"
    echo -e "  ${GRAY}──────────────────────────────────────────────────────${RESET}"
}

info_line() {
    printf "  ${MAIN}%-15s${RESET} ${WHITE}%s${RESET}\n" "$1:" "$2"
}

# ----------------- SAFE REMOTE RUN -----------------
run_remote() {
    url="$1"
    header
    echo -e "  ${DIM}Fetching script...${RESET}\n"

    if ! curl -fsSL "$url" | head -n 1 | grep -q "#!/bin/bash"; then
        echo -e "  ${ERROR}ERROR:${RESET} Script tidak valid atau URL salah"
        echo -e "  ${GRAY}$url${RESET}"
        echo -e "\n  Press ENTER..."
        read
        return
    fi

    bash <(curl -fsSL "$url")

    echo -e "\n  ${DIM}Press ENTER to return to menu...${RESET}"
    read
}

# ----------------- SYSTEM INFO -----------------
show_all_info() {
    header
    echo -e "  ${BOLD}${WHITE}FULL SYSTEM DIAGNOSTICS${RESET}\n"

    info_line "OS" "$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"
    info_line "CPU" "$(lscpu | awk -F: '/Model name/ {print $2}' | xargs)"
    info_line "Cores" "$(nproc)"
    info_line "RAM" "$(free -h | awk '/Mem:/ {print $3 " / " $2}')"
    info_line "Disk" "$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')"
    info_line "Kernel" "$(uname -r)"
    info_line "Uptime" "$(uptime -p)"

    echo -e "\n  ${GRAY}─────────────────────────────────${RESET}"

    pub_ip=$(curl -s --max-time 3 api.ipify.org || echo "N/A")
    isp=$(curl -s --max-time 3 ipinfo.io/org || echo "N/A")
    loc=$(curl -s --max-time 3 ipinfo.io/country || echo "N/A")

    info_line "Public IP" "$pub_ip"
    info_line "ISP" "$isp"
    info_line "Country" "$loc"

    echo -e "\n  ${DIM}Press ENTER to return...${RESET}"
    read
}

# ----------------- TAILSCALE INSTALL -----------------
install_tailscale() {
    header
    echo -e "  ${BOLD}${WHITE}Installing Tailscale${RESET}\n"

    if command -v tailscale >/dev/null 2>&1; then
        echo -e "  ${SUCCESS}Tailscale already installed${RESET}"
    else
        curl -fsSL https://tailscale.com/install.sh | sh
    fi

    systemctl enable --now tailscaled

    echo -e "\n  ${SUCCESS}Tailscale installed successfully${RESET}\n"
    echo -e "  ${WHITE}Login dengan perintah:${RESET}"
    echo -e "  ${MAIN}tailscale up${RESET}"

    echo -e "\n  ${DIM}Press ENTER AFTER login to return menu...${RESET}"
    read
}

# ----------------- MAIN LOOP -----------------
while true; do
    header
    echo -e "  ${BOLD}${WHITE}MAIN MENU${RESET}\n"

    printf "  ${MAIN}${BOLD}%s${RESET}  ${WHITE}%-30s${RESET}\n" "1" "Install Pterodactyl Panel"
    printf "  ${MAIN}${BOLD}%s${RESET}  ${WHITE}%-30s${RESET}\n" "2" "Install Wings (Node)"
    printf "  ${MAIN}${BOLD}%s${RESET}  ${WHITE}%-30s${RESET}\n" "9" "Uninstall Wings (Node)"
    printf "  ${MAIN}${BOLD}%s${RESET}  ${WHITE}%-30s${RESET}\n" "10" "Uninstall Pterodactyl (Node)"
    printf "  ${MAIN}${BOLD}%s${RESET}  ${WHITE}%-30s${RESET}\n" "3" "Install Blueprints"
    printf "  ${MAIN}${BOLD}%s${RESET}  ${WHITE}%-30s${RESET}\n" "4" "Setup IDX 24/7"
    printf "  ${MAIN}${BOLD}%s${RESET}  ${WHITE}%-30s${RESET}\n" "5" "System Tools"
    printf "  ${MAIN}${BOLD}%s${RESET}  ${WHITE}%-30s${RESET}\n" "6" "Install RDP"
    printf "  ${MAIN}${BOLD}%s${RESET}  ${WHITE}%-30s${RESET}\n" "7" "Install Tailscale"
    printf "  ${MAIN}${BOLD}%s${RESET}  ${WHITE}%-30s${RESET}\n" "8" "Stup teks"

    echo ""
    printf "  ${MAIN}${BOLD}%s${RESET}  ${WHITE}%-30s${RESET}\n" "0" "Exit"

    echo -e "\n  ${GRAY}──────────────────────────────────────────────────────${RESET}"
    echo -ne "  ${BOLD}Choice ${MAIN}❯${RESET} "
    read -r c

    case "$c" in
        1) run_remote https://raw.githubusercontent.com/jojoxyx182-ctrl/condemnedforcevip/refs/heads/main/panel.sh ;;
        2) run_remote https://raw.githubusercontent.com/jojoxyx182-ctrl/condemnedforcevip/refs/heads/main/node.sh ;;
        3) run_remote https://raw.githubusercontent.com/jojoxyx182-ctrl/condemnedforcevip/refs/heads/main/tema.sh ;;
        4) run_remote https://raw.githubusercontent.com/jojoxyx182-ctrl/condemnedforcevip/refs/heads/main/443.sh ;;
        5) show_all_info ;;
        6) run_remote https://raw.githubusercontent.com/jojoxyx182-ctrl/condemnedforcevip/refs/heads/main/rdp.sh ;;
        7) install_tailscale ;;
        8) run_remote https://raw.githubusercontent.com/jojoxyx182-ctrl/condemnedforcevip/refs/heads/main/txt24 ;;
        9) run_remote https://raw.githubusercontent.com/jojoxyx182-ctrl/condemnedforcevip/refs/heads/main/uninstallwing.sh ;;
        10) run_remote https://raw.githubusercontent.com/jojoxyx182-ctrl/condemnedforcevip/refs/heads/main/uninstallpanel.sh ;;
        0)
            echo -e "\n  ${SUCCESS}${BOLD}Thanks for using this tool! 🌟${RESET}\n"
            exit 0
            ;;
        *)
            echo -e "  ${ERROR}Invalid option${RESET}"
            sleep 1
            ;;
    esac
done