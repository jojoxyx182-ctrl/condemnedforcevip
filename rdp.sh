#!/bin/bash

set -e

RDP_USER="rdp"
RDP_PASS=$(openssl rand -base64 16)

echo "=== Install XRDP ==="
apt update
apt install -y xrdp xfce4 xfce4-goodies

systemctl enable xrdp
systemctl restart xrdp

echo "=== Buat User RDP ==="
if ! id "$RDP_USER" &>/dev/null; then
  useradd -m -s /bin/bash "$RDP_USER"
  echo "$RDP_USER:$RDP_PASS" | chpasswd
fi

usermod -aG sudo "$RDP_USER"

echo "xfce4-session" > /home/$RDP_USER/.xsession
chown $RDP_USER:$RDP_USER /home/$RDP_USER/.xsession

SERVER_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')

echo "================================="
echo "RDP READY"
echo "IP        : $SERVER_IP"
echo "PORT      : 3389"
echo "USERNAME  : $RDP_USER"
echo "PASSWORD  : $RDP_PASS"
echo "================================="