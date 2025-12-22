#!/bin/bash

set -e

RDP_USER="rdp"
RDP_PASS=$(openssl rand -base64 16)
TAILSCALE_AUTHKEY="ISI_AUTHKEY_TAILSCALE_KAMU"

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

echo "=== Install Tailscale ==="
curl -fsSL https://tailscale.com/install.sh | sh
systemctl enable tailscaled
systemctl start tailscaled

tailscale up --authkey="$TAILSCALE_AUTHKEY" --hostname=vps-rdp

TS_IP=$(tailscale ip -4)

echo "================================="
echo "RDP READY"
echo "IP        : $TS_IP"
echo "PORT      : 3389"
echo "USERNAME  : $RDP_USER"
echo "PASSWORD  : $RDP_PASS"
echo "================================="