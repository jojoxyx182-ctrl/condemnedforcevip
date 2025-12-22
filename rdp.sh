#!/bin/bash

set -e

RDP_USER="rdp"

echo "=== Update system ==="
apt update -y

echo "=== Install XRDP & Desktop ==="
apt install -y \
  xrdp \
  xorgxrdp \
  xfce4 \
  xfce4-goodies \
  dbus-x11 \
  sudo \
  curl \
  wget

echo "=== Enable XRDP ==="
systemctl enable xrdp
systemctl restart xrdp

echo "=== Create RDP User ==="
if ! id "$RDP_USER" &>/dev/null; then
  useradd -m -s /bin/bash "$RDP_USER"
  echo
  echo "SET PASSWORD UNTUK USER rdp"
  passwd "$RDP_USER"
  usermod -aG sudo "$RDP_USER"
fi

echo "=== Set XFCE Session ==="
echo "startxfce4" > /home/$RDP_USER/.xsessionrc
chown $RDP_USER:$RDP_USER /home/$RDP_USER/.xsessionrc
chmod 644 /home/$RDP_USER/.xsessionrc

echo "=== Fix Permission ==="
chown -R $RDP_USER:$RDP_USER /home/$RDP_USER

echo "=== Install Browsers ==="
apt install -y firefox chromium || apt install -y firefox-esr chromium

echo "=== Open Firewall (if UFW exists) ==="
ufw allow 3389 || true
ufw reload || true

SERVER_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')

echo
echo "======================================"
echo "RDP READY"
echo "IP       : $SERVER_IP"
echo "PORT     : 3389"
echo "USER     : $RDP_USER"
echo "SESSION  : Xorg"
echo "NOTE     : Browsing ready (Firefox & Chromium)"
echo "======================================"