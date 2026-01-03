#!/bin/bash

# ===================================================
#  CONDEMNED FORCE - PTERODACTYL UNINSTALLER
#          NEXT GEN ULTRA EDITION
#                2025
# ===================================================
#  Developed by: CONDEMNED FORCE
#  Power • Control • Domination
# ===================================================

set -e

# ================= COLORS =================

RESET="\e[0m"
BOLD="\e[1m"
DIM="\e[2m"
UNDERLINE="\e[4m"

CYAN="\e[96m"
BLUE="\e[94m"
PURPLE="\e[95m"
GREEN="\e[92m"
YELLOW="\e[93m"
RED="\e[91m"
WHITE="\e[97m"

NEON_GREEN="\e[38;5;82m"
NEON_PURPLE="\e[38;5;165m"
NEON_BLUE="\e[38;5;75m"
GLOW="\e[38;5;51m"
DANGER="\e[38;5;196m"

clear

# ================= BANNER =================

echo -e "${NEON_BLUE}"
cat << "EOF"

   _____   __  __   _____   _   _   _   _   _____   _   _   _____   _     
  |  __ \ / _|/ _| |  __ \ | \ | | | \ | | |  __ \ | \ | | |  __ \ | |    
  | |__) | |_| |_  | |__) | |  \| | |  \| | | |__) | |  \| | | |__) | |    
  |  ___/|  _|  _| |  _  /  | . ` | | . ` | |  ___/  | . ` | |  _  /  | |    
  | |    | | | |   | | \ \  | |\  | | |\  | | |      | |\  | | | \ \  | |____
  |_|    |_| |_|   |_|  \_\ |_| \_| |_| \_| |_|      |_| \_| |_|  \_\ |______|

EOF

echo -e "${DANGER}${BOLD}                ⚡ DANGEROUS UNINSTALLER ⚡${RESET}"
echo -e "${NEON_PURPLE}${BOLD}          CONDEMNED FORCE | ULTRA EDITION 2025${RESET}"
echo -e "${GLOW}        Irreversible • Fast • Total Annihilation${RESET}"
echo -e "${DIM}        Developed by: ${BOLD}CONDEMNED FORCE${RESET}"
echo -e "${DIM}        Power • Control • Domination${RESET}"
echo -e "${NEON_BLUE}══════════════════════════════════════════════════════════${RESET}\n"

# ================= UI FUNCTIONS =================

progress() { echo -e "${NEON_GREEN}${BOLD}➤ $1${RESET}"; }
success()  { echo -e "${GREEN}${BOLD}✓ $1${RESET}"; }
warning()  { echo -e "${YELLOW}${BOLD}! $1${RESET}"; }
danger()   { echo -e "${DANGER}${BOLD}⚠ $1${RESET}"; }
error()    { echo -e "${RED}${BOLD}✘ $1${RESET}"; }

# ================= CONFIRM =================

confirm_action() {
    local message="$1"
    echo -e "\n${DANGER}${BOLD}DANGER ZONE${RESET}"
    echo -e "${YELLOW}${BOLD}   $message${RESET}\n"
    read -p $'\e[93m\e[1m   Type "YES" to authorize execution: \e[0m' -r REPLY
    echo
    [[ "$REPLY" == "YES" ]] || {
        echo -e "${GREEN}${BOLD}   Operation aborted safely.${RESET}\n"
        return 1
    }
}

# ================= NGINX CLEANUP =================

cleanup_nginx() {
    progress "Purging Nginx configurations..."
    rm -f /etc/nginx/sites-enabled/pterodactyl.conf 2>/dev/null && success "sites-enabled removed"
    rm -f /etc/nginx/sites-available/pterodactyl.conf 2>/dev/null && success "sites-available removed"
    rm -f /etc/nginx/conf.d/pterodactyl.conf 2>/dev/null && success "conf.d removed"

    if command -v nginx >/dev/null 2>&1; then
        systemctl restart nginx >/dev/null 2>&1 && success "Nginx restarted"
    fi
}

# ================= PANEL =================

uninstall_panel() {
    echo -e "${NEON_PURPLE}${BOLD}╔════════════════════════════════════════╗${RESET}"
    echo -e "${NEON_PURPLE}${BOLD}║     UNINSTALLING PTERODACTYL PANEL      ║${RESET}"
    echo -e "${NEON_PURPLE}${BOLD}╚════════════════════════════════════════╝${RESET}\n"

    confirm_action "This will PERMANENTLY erase Panel, database, and configs." || return

    progress "Stopping queue service..."
    systemctl stop pteroq.service 2>/dev/null || true
    systemctl disable pteroq.service 2>/dev/null || true
    rm -f /etc/systemd/system/pteroq.service
    systemctl daemon-reload
    success "Queue service terminated"

    progress "Removing cron schedules..."
    (crontab -l 2>/dev/null | grep -v 'pterodactyl/artisan') | crontab - 2>/dev/null || true
    success "Cron cleared"

    progress "Deleting panel files..."
    rm -rf /var/www/pterodactyl
    success "Panel directory destroyed"

    progress "Dropping database..."
    mysql -e "DROP DATABASE IF EXISTS panel;" 2>/dev/null || true
    mysql -e "DROP USER IF EXISTS 'pterodactyl'@'127.0.0.1';" 2>/dev/null || true
    mysql -e "FLUSH PRIVILEGES;" 2>/dev/null || true
    success "Database wiped"

    cleanup_nginx
    echo -e "\n${DANGER}${BOLD}✓ Panel eliminated by CONDEMNED FORCE.${RESET}\n"
}

# ================= WINGS =================

uninstall_wings() {
    echo -e "${NEON_PURPLE}${BOLD}╔════════════════════════════════════════╗${RESET}"
    echo -e "${NEON_PURPLE}${BOLD}║      UNINSTALLING PTERODACTYL WINGS     ║${RESET}"
    echo -e "${NEON_PURPLE}${BOLD}╚════════════════════════════════════════╝${RESET}\n"

    confirm_action "This will PERMANENTLY erase Wings and ALL server data." || return

    progress "Stopping Wings..."
    systemctl stop wings 2>/dev/null || true
    systemctl disable wings 2>/dev/null || true
    rm -f /etc/systemd/system/wings.service
    systemctl daemon-reload
    success "Wings service neutralized"

    progress "Deleting Wings data..."
    rm -rf /etc/pterodactyl /var/lib/pterodactyl /var/log/pterodactyl
    rm -f /usr/local/bin/wings /usr/local/bin/wing
    success "All Wings data destroyed"

    echo -e "\n${DANGER}${BOLD}✓ Wings terminated by CONDEMNED FORCE.${RESET}\n"
}

# ================= NUCLEAR =================

uninstall_both() {
    echo -e "${DANGER}${BOLD}╔══════════════════════════════════════════════════╗${RESET}"
    echo -e "${DANGER}${BOLD}║      NUCLEAR OPTION: TOTAL SYSTEM PURGE           ║${RESET}"
    echo -e "${DANGER}${BOLD}╚══════════════════════════════════════════════════╝${RESET}\n"

    confirm_action "THIS WILL ERASE EVERYTHING. NO RECOVERY." || return
    uninstall_panel
    uninstall_wings
    echo -e "${DANGER}${BOLD}✓ System obliterated by CONDEMNED FORCE.${RESET}\n"
}

# ================= MENU =================

show_menu() {
    clear
    echo -e "${NEON_BLUE}"
cat << "EOF"

   ██████╗ ██████╗ ███╗   ██╗██████╗ ███████╗███╗   ███╗
  ██╔════╝██╔═══██╗████╗  ██║██╔══██╗██╔════╝████╗ ████║
  ██║     ██║   ██║██╔██╗ ██║██║  ██║█████╗  ██╔████╔██║
  ██║     ██║   ██║██║╚██╗██║██║  ██║██╔══╝  ██║╚██╔╝██║
  ╚██████╗╚██████╔╝██║ ╚████║██████╔╝███████╗██║ ╚═╝ ██║
   ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚═════╝ ╚══════╝╚═╝     ╚═╝

EOF

    echo -e "${DANGER}${BOLD}         CONDEMNED FORCE - UNINSTALLER${RESET}"
    echo -e "${NEON_PURPLE}${BOLD}               ULTRA EDITION 2025${RESET}\n"

    echo -e "${GLOW}${BOLD}╔══════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}   Select Operation:${RESET}"
    echo -e "${GLOW}${BOLD}╠══════════════════════════════════════════════════╣${RESET}"
    echo -e "${YELLOW}   ${GREEN}${BOLD}1)${RESET} ${WHITE}Uninstall Panel${RESET}"
    echo -e "${YELLOW}   ${GREEN}${BOLD}2)${RESET} ${WHITE}Uninstall Wings${RESET}"
    echo -e "${YELLOW}   ${GREEN}${BOLD}3)${RESET} ${WHITE}Nuclear Removal (ALL)${RESET}"
    echo -e "${YELLOW}   ${RED}${BOLD}0)${RESET} ${WHITE}Exit${RESET}"
    echo -e "${GLOW}${BOLD}╚══════════════════════════════════════════════════╝${RESET}\n"

    danger "ALL ACTIONS ARE FINAL. NO RECOVERY."
    echo -e "\n${NEON_GREEN}${BOLD}CONDEMNED FORCE${RESET}"
    echo -e "${DIM}Elite System Removal Division${RESET}\n"
}

# ================= LOOP =================

while true; do
    show_menu
    read -p $'\e[93m\e[1mChoose option [0-3]: \e[0m' choice
    echo
    case $choice in
        1) uninstall_panel ;;
        2) uninstall_wings ;;
        3) uninstall_both ;;
        0) echo -e "${GREEN}${BOLD}Session terminated. Goodbye.${RESET}\n"; exit 0 ;;
        *) error "Invalid option!" ; sleep 2 ;;
    esac
    echo -e "${YELLOW}Press Enter to continue...${RESET}"
    read -r
done