#!/bin/bash

# ================= COLORS =================
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

RED='\033[38;5;196m'
GREEN='\033[38;5;82m'
CYAN='\033[38;5;51m'
WHITE='\033[38;5;255m'
GRAY='\033[38;5;242m'
YELLOW='\033[38;5;226m'

# Pill Header
L_PILL='\033[48;5;93m\033[38;5;255m'
R_PILL='\033[48;5;39m\033[38;5;16m'

PASS_FILE="/root/.rdp_credentials"

clear
echo -e "\n  ${L_PILL}${BOLD} CONDEMNED ${RESET}${R_PILL}${BOLD} FORCE RDP CHECKER ${RESET}"
echo -e "  ${GRAY}──────────────────────────────────────────────────────${RESET}\n"

echo -e "  ${CYAN}${BOLD}➤${RESET} ${WHITE}Memeriksa akun RDP VPS...${RESET}"
sleep 1

if [ ! -f "$PASS_FILE" ]; then
    echo ""
    echo -e "  ${RED}${BOLD}✗ Data RDP tidak ditemukan!${RESET}"
    echo -e "  ${DIM}Kemungkinan RDP belum pernah dibuat.${RESET}"
    echo ""
    echo -e "  ${DIM}Tekan ENTER untuk kembali...${RESET}"
    read
    exit 1
fi

source $PASS_FILE

echo ""
echo -e "  ${GRAY}────────────────────────────────────────${RESET}"
echo -e "  ${GREEN}${BOLD}RDP DITEMUKAN ✅${RESET}"
echo -e "  ${GRAY}────────────────────────────────────────${RESET}"
echo -e "  ${CYAN}USERNAME  ${WHITE}: ${GREEN}$USERNAME${RESET}"
echo -e "  ${CYAN}PASSWORD  ${WHITE}: ${GREEN}$PASSWORD${RESET}"
echo -e "  ${CYAN}PORT      ${WHITE}: ${GREEN}3389${RESET}"
echo -e "  ${GRAY}────────────────────────────────────────${RESET}"

echo ""
echo -e "  ${DIM}Tekan ENTER untuk kembali ke menu...${RESET}"
read