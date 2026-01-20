#!/bin/bash

set -e

RDP_USER="rdp"

echo "=== 1. Update & Install Core ==="
apt update -y
apt upgrade -y

apt install -y \
  xrdp \
  xorgxrdp \
  xfce4 \
  xfce4-goodies \
  dbus-x11 \
  sudo \
  curl \
  wget \
  fonts-noto \
  fonts-wqy-microhei \
  ttf-mscorefonts-installer \
  pulseaudio \
  pulseaudio-module-xrdp \
  pavucontrol

echo "=== 2. Configure XRDP for 'Real' Experience ==="
# 1. Memastikan semua user boleh login RDP
if [ -f /etc/X11/Xwrapper.config ]; then
    sed -i 's/allowed_users=console/allowed_users=anybody/' /etc/X11/Xwrapper.config
else
    echo "allowed_users=anybody" > /etc/X11/Xwrapper.config
fi

# 2. Memastikan XRDP menggunakan Xorg (Penting agar GPU bekerja)
# XRDP biasanya otomatis mendeteksi Xorg, tapi kita pastikan konfigurasi dasar bersih.
# Mencegah masalah black screen jika user baru login.

# 3. FIX AUDIO untuk RDP (Agar suara keluar real-time)
# Tambahkan user rdp ke group pulse-access agar punya akses audio
if id "$RDP_USER" &>/dev/null; then
    usermod -aG pulse-access $RDP_USER
fi
# Enable pulseaudio secara system-wide untuk xrdp
systemctl --global enable pulseaudio.service
systemctl --global enable pulseaudio.socket

echo "=== 3. Create RDP User ==="
if ! id "$RDP_USER" &>/dev/null; then
  useradd -m -s /bin/bash "$RDP_USER"
  echo
  echo "SET PASSWORD UNTUK USER rdp"
  passwd "$RDP_USER"
  usermod -aG sudo "$RDP_USER"
  usermod -aG audio $RDP_USER
  usermod -aG pulse-access $RDP_USER
fi

echo "=== 4. Visual Tweaks (Make it look Real) ==="
# Set XFCE Session
echo "xfce4-session" > /home/$RDP_USER/.xsession
chown $RDP_USER:$RDP_USER /home/$RDP_USER/.xsession

# Buat direktori konfigurasi XFCE jika belum ada
mkdir -p /home/$RDP_USER/.config/xfce4/xfconf/xfce-perchannel-xml
chown $RDP_USER:$RDP_USER -R /home/$RDP_USER/.config

# TWEAK 1: Font & Icon Mirip Windows (Gunakan Font Sans)
cat > /home/$RDP_USER/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="IconThemeName" type="string" value="Adwaita"/>
    <property name="ThemeName" type="string" value="Greybird"/>
    <property name="FontName" type="string" value="Sans 10"/>
  </property>
</channel>
EOF

# TWEAK 2: Background Biru Gelap (Agar tidak putih polos yang terasa 'kosong')
# Membuat background biru solid agar lebih ringan daripada wallpaper gambar
# (Anda bisa mengganti ini nanti leluhur Properties di Desktop)
mkdir -p /home/$RDP_USER/.config/xfce4/xfconf/xfce-perchannel-xml/
cat > /home/$RDP_USER/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="image-path" type="empty"/>
        <property name="last-image" type="empty"/>
        <property name="color-style" type="int" value="0"/>
        <property name="color1" type="array">
          <value type="uint" value="29"/>
          <value type="uint" value="29"/>
          <value type="uint" value="33"/>
        </property>
      </property>
    </property>
  </property>
</channel>
EOF

# Perbaiki permission agar user bisa mengubah settingan nanti
chown -R $RDP_USER:$RDP_USER /home/$RDP_USER/.config
chown $RDP_USER:$RDP_USER /home/$RDP_USER/.xsession

echo "=== 5. Restart Services ==="
systemctl enable xrdp
systemctl restart xrdp

echo "=== 6. Install Browsers ==="
apt install -y firefox-esr -y || apt install -y chromium -y

echo "=== 7. Firewall ==="
ufw allow 3389/tcp || true
ufw reload || true

SERVER_IP=$(curl -s ifconfig.me || curl -s ip.sb || hostname -I | awk '{print $1}')

echo
echo "============================================"
echo "RDP WINDOWS-LIKE EXPERIENCE READY"
echo "============================================"
echo "IP       : $SERVER_IP"
echo "PORT     : 3389"
echo "USER     : $RDP_USER"
echo "AUDIO    : ENABLED (Check volume mixer if silent)"
echo "CLIPBOARD: ENABLED"
echo "============================================"
