#!/bin/bash
set -e

# =====================================================
# CONDEMNED FORCE - AUTO RDP + CUSTOM PORT
# =====================================================

RDP_USER="rdpuser"
PASS_PREFIX="force"
PASS_LENGTH=8
PASS_FILE="/root/.rdp_credentials"

GREEN="\033[32m"
CYAN="\033[36m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

echo -e "${CYAN}[*] AUTO RDP INSTALLER (CUSTOM PORT)${RESET}"
echo ""

# ---------------- INPUT PORT ----------------
read -p "Masukkan PORT RDP (contoh: 3390): " RDP_PORT

if [[ -z "$RDP_PORT" ]]; then
    echo -e "${YELLOW}Port kosong, pakai default 3389${RESET}"
    RDP_PORT=3389
fi

if ! [[ "$RDP_PORT" =~ ^[0-9]+$ ]] || [ "$RDP_PORT" -lt 1 ] || [ "$RDP_PORT" -gt 65535 ]; then
    echo -e "${RED}Port tidak valid!${RESET}"
    exit 1
fi

# ---------------- OS DETECT ----------------
. /etc/os-release
OS=$ID

install_debian() {
    apt update -y
    DEBIAN_FRONTEND=noninteractive apt install -y \
        xrdp lxde-core lxde-common sudo dbus-x11 curl
}

install_redhat() {
    dnf install -y epel-release
    dnf install -y xrdp lxde-common sudo curl
}

# ---------------- INSTALL XRDP ----------------
if ! command -v xrdp >/dev/null; then
    case "$OS" in
        ubuntu|debian) install_debian ;;
        centos|almalinux|rocky|rhel) install_redhat ;;
        *) echo "OS NOT SUPPORTED"; exit 1 ;;
    esac
fi

# ---------------- SET PORT ----------------
sed -i "s/^port=.*/port=$RDP_PORT/" /etc/xrdp/xrdp.ini

# ---------------- ENABLE XRDP ----------------
systemctl enable --now xrdp

# ---------------- SESSION ----------------
echo "exec startlxde" > /etc/skel/.xsession

# ---------------- USER ----------------
if [ ! -f "$PASS_FILE" ]; then
    RAND=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $PASS_LENGTH)
    PASS="${PASS_PREFIX}${RAND}"

    useradd -m -s /bin/bash "$RDP_USER"
    echo "$RDP_USER:$PASS" | chpasswd
    usermod -aG sudo "$RDP_USER"

    echo "exec startlxde" > /home/$RDP_USER/.xsession
    chown $RDP_USER:$RDP_USER /home/$RDP_USER/.xsession

    echo "USERNAME=$RDP_USER" > $PASS_FILE
    echo "PASSWORD=$PASS" >> $PASS_FILE
    echo "PORT=$RDP_PORT" >> $PASS_FILE
    chmod 600 $PASS_FILE
fi

# ---------------- FIREWALL ----------------
if command -v ufw >/dev/null; then
    ufw allow $RDP_PORT/tcp || true
    ufw reload || true
fi

if command -v firewall-cmd >/dev/null; then
    firewall-cmd --add-port=${RDP_PORT}/tcp --permanent || true
    firewall-cmd --reload || true
fi

# ---------------- RESULT ----------------
source $PASS_FILE
IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}✔ RDP READY (CUSTOM PORT)${RESET}"
echo -e "${CYAN}IP       : $IP${RESET}"
echo -e "${CYAN}PORT     : $PORT${RESET}"
echo -e "${CYAN}USERNAME : $USERNAME${RESET}"
echo -e "${CYAN}PASSWORD : $PASSWORD${RESET}"
echo -e "${CYAN}DESKTOP  : LXDE${RESET}"
echo ""