#!/bin/bash
set -e

USER_RDP="rdp"

echo "=== Update ==="
apt update -y
apt upgrade -y

echo "=== Install XRDP + Openbox (MINIMAL) ==="
apt install -y --no-install-recommends \
  xrdp \
  xorgxrdp \
  openbox \
  xterm \
  dbus-x11 \
  sudo \
  curl \
  wget \
  nano

echo "=== Fix XRDP Permission ==="
adduser xrdp ssl-cert || true

echo "=== Create User ==="
if ! id "$USER_RDP" &>/dev/null; then
  useradd -m -s /bin/bash "$USER_RDP"
  passwd "$USER_RDP"
  usermod -aG sudo "$USER_RDP"
fi

echo "=== Openbox Session ==="
echo "exec openbox-session" > /home/$USER_RDP/.xsession
chown $USER_RDP:$USER_RDP /home/$USER_RDP/.xsession
chmod 644 /home/$USER_RDP/.xsession

echo "=== Disable ALL effects ==="
mkdir -p /home/$USER_RDP/.config/openbox
cat > /home/$USER_RDP/.config/openbox/autostart <<'EOF'
xset s off
xset -dpms
xset s noblank
EOF
chown -R $USER_RDP:$USER_RDP /home/$USER_RDP/.config

echo "=== XRDP Ultra Low Latency ==="
cat > /etc/xrdp/xrdp.ini <<'EOF'
[Globals]
port=3389
crypt_level=low
max_bpp=15
bitmap_cache=false
bitmap_compression=false
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

echo "=== Install Browser (LIGHT) ==="
apt install -y firefox-esr

echo "=== Restart XRDP ==="
systemctl enable xrdp
systemctl restart xrdp

IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')

echo
echo "================================"
echo "RDP MINIMAL READY"
echo "IP   : $IP"
echo "PORT : 3389"
echo "USER : $USER_RDP"
echo "NOTE : Desktop kosong, buka browser manual"
echo "================================"
