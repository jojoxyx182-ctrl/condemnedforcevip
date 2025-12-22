#!/bin/bash

set -e

RDP_USER="rdp"

echo "=== Update system ==="
apt update

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

systemctl enable xrdp
systemctl restart xrdp

echo "=== Create RDP User ==="
if ! id "$RDP_USER" &>/dev/null; then
  useradd -m -s /bin/bash "$RDP_USER"
  passwd "$RDP_USER"
  usermod -aG sudo "$RDP_USER"
fi

echo "startxfce4" > /home/$RDP_USER/.xsessionrc
chown $RDP_USER:$RDP_USER /home/$RDP_USER/.xsessionrc

echo "=== Install Browsers ==="
apt install -y firefox chromium

SERVER_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')

echo "===================================="
echo "RDP READY"
echo "IP       : $SERVER_IP"
echo "PORT     : 3389"
echo "USER     : $RDP_USER"
echo "NOTE     : APK bisa di-download via browser"
echo "===================================="