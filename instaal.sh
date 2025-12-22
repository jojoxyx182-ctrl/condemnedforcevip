#!/bin/bash
set -e

# =====================================================
# CONDEMNEDFORCE XYZ - INSTALLER (CLIENT)
# =====================================================

# ---------------- COLORS ----------------
RESET='\033[0m'
BOLD='\033[1m'
MAIN='\033[38;5;51m'
WHITE='\033[38;5;255m'
GRAY='\033[38;5;242m'
SUCCESS='\033[38;5;82m'
ERROR='\033[38;5;196m'

# ---------------- ROOT CHECK ----------------
[[ $EUID -ne 0 ]] && echo -e "${ERROR}Run as root${RESET}" && exit 1

# ---------------- PATH ----------------
NOV="/root/.nov"
TOKEN_FILE="$NOV/token"
LICENSE_FILE="$NOV/license"

# ---------------- REPO ----------------
OWNER="jojoxyx182-ctrl"
REPO="condemnedforcevip"
RAW="https://raw.githubusercontent.com/$OWNER/$REPO/main"

# ---------------- LOAD TOKEN ----------------
[[ ! -f $TOKEN_FILE ]] && echo -e "${ERROR}Token missing${RESET}" && exit 1
GITHUB_TOKEN="$(cat $TOKEN_FILE)"

# ---------------- LOAD LICENSE ----------------
[[ ! -f $LICENSE_FILE ]] && echo -e "${ERROR}License missing${RESET}" && exit 1
LICENSE_KEY="$(cat $LICENSE_FILE | tr -d ' ')"

# ---------------- GET IP ----------------
MY_IP="$(curl -s api.ipify.org)"

# ---------------- FETCH LICENSE DB ----------------
LICENSE_DB=$(curl -fsSL -H "Authorization: token $GITHUB_TOKEN" "$RAW/licenses.txt")

LINE=$(echo "$LICENSE_DB" | grep "^$LICENSE_KEY|")
[[ -z "$LINE" ]] && echo -e "${ERROR}License invalid${RESET}" && exit 1

LIC_IP=$(echo "$LINE" | cut -d'|' -f2)
LIC_STATUS=$(echo "$LINE" | cut -d'|' -f3)
LIC_EXP=$(echo "$LINE" | cut -d'|' -f4)

# ---------------- CHECK STATUS ----------------
[[ "$LIC_STATUS" != "active" ]] && echo -e "${ERROR}License disabled${RESET}" && exit 1

# ---------------- CHECK IP ----------------
if [[ "$LIC_IP" != "UNBOUND" && "$LIC_IP" != "$MY_IP" ]]; then
    echo -e "${ERROR}License bound to another VPS${RESET}"
    exit 1
fi

# ---------------- CHECK EXPIRED ----------------
TODAY=$(date +%s)
EXPIRE=$(date -d "$LIC_EXP" +%s 2>/dev/null || echo 0)

[[ $TODAY -gt $EXPIRE ]] && echo -e "${ERROR}License expired${RESET}" && exit 1

# ---------------- UI ----------------
header() {
    clear
    echo -e "${BOLD}${MAIN}CONDEMNEDFORCE XYZ${RESET}"
    echo -e "${GRAY}Secure Installer${RESET}"
    echo -e "${GRAY}────────────────────────${RESET}"
}

pause() { read -p "Press ENTER..."; }

run_remote() {
    bash <(
        curl -fsSL \
        -H "Authorization: token $GITHUB_TOKEN" \
        "$1"
    )
    pause
}

# ---------------- MENU ----------------
while true; do
    header
    echo -e "${WHITE}1${RESET}. Install Panel"
    echo -e "${WHITE}2${RESET}. Install Node"
    echo -e "${WHITE}3${RESET}. Install Theme"
    echo -e "${WHITE}4${RESET}. Install RDP"
    echo -e "${WHITE}5${RESET}. License Info"
    echo -e "${WHITE}0${RESET}. Exit"
    echo ""
    read -p "Choose: " c

    case $c in
        1) run_remote "$RAW/panel.sh" ;;
        2) run_remote "$RAW/node.sh" ;;
        3) run_remote "$RAW/tema.sh" ;;
        4) run_remote "$RAW/rdp.sh" ;;
        5)
            header
            echo "License : $LICENSE_KEY"
            echo "IP      : $MY_IP"
            echo "Expired : $LIC_EXP"
            pause
            ;;
        0) exit 0 ;;
        *) echo "Invalid"; sleep 1 ;;
    esac
done