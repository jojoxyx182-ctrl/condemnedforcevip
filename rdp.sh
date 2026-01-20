#!/bin/bash
set -e

RDP_USER="rdp"

echo "=== Update system minimal ==="
apt update -y
apt upgrade -y

echo "=== Install XRDP + LXDE (SUPER RINGAN) ==="
apt install -y --no-install-recommends \
  xrdp \
  xorgxrdp \
  lxde-core \
  lxterminal \
  openbox \
  dbus-x11 \
  sudo \
  curl \
  wget \
  nano

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

echo "=== Set LXDE Session ==="
echo "exec startlxde" > /home/$RDP_USER/.xsession
chown $RDP_USER:$RDP_USER /home/$RDP_USER/.xsession
chmod 644 /home/$RDP_USER/.xsession

echo "=== XRDP PERFORMANCE TWEAK ==="
cat > /etc/xrdp/xrdp.ini <<'EOF'
[Globals]
bitmap_cache=true
bitmap_compression=true
port=3389
crypt_level=low
max_bpp=16
use_fastpath=both
tcp_nodelay=true
tcp_keepalive=true

[Xorg]
name=Xorg
lib=libxup.so
username=ask
password=ask
ip=127.0.0.1
port=-1
code=20
EOF

echo "=== Disable Heavy Services ==="
systemctl disable bluetooth || true
systemctl disable cups || true
systemctl disable cups-browsed || true
systemctl disable avahi-daemon || true
systemctl disable ModemManager || true

echo "=== LXDE Speed Tweaks ==="
mkdir -p /home/$RDP_USER/.config/lxsession/LXDE
cat > /home/$RDP_USER/.config/lxsession/LXDE/autostart <<'EOF'
@lxpanel --profile LXDE
@pcmanfm --desktop --profile LXDE

# MATIKAN SEMUA ANIMASI & EFFECT
@xset s off
@xset -dpms
@xset s noblank
EOF

chown -R $RDP_USER:$RDP_USER /home/$RDP_USER/.config

echo "=== Install Lightweight Browser ==="
apt install -y firefox-esr

echo "=== Open Firewall ==="
ufw allow 3389 || true
ufw reload || true

systemctl restart xrdp

SERVER_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')

echo
echo "======================================"
echo "RDP SUPER RINGAN READY 🚀"
echo "IP       : $SERVER_IP"
echo "PORT     : 3389"
echo "USER     : $RDP_USER"
echo "SESSION  : Xorg"
echo "DESKTOP  : LXDE (Ultra Lightweight)"
echo "RAM IDLE : ±300MB"
echo "======================================"
