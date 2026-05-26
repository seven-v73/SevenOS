#!/usr/bin/env bash
set -euo pipefail

ln -sf /usr/share/zoneinfo/UTC /etc/localtime
systemctl enable NetworkManager.service
systemctl enable ModemManager.service 2>/dev/null || true
systemctl enable plymouth-quit.service 2>/dev/null || true

useradd -m -G wheel -s /bin/bash seven
passwd -l seven

install -Dm755 /opt/SevenOS/bin/sevenosctl /usr/local/bin/sevenosctl
install -Dm755 /opt/SevenOS/bin/seven /usr/local/bin/seven
install -Dm755 /opt/SevenOS/bin/seven-country /usr/local/bin/seven-country
install -Dm755 /opt/SevenOS/bin/seven-installer /usr/local/bin/seven-installer
install -Dm755 /opt/SevenOS/bin/seven-power /usr/local/bin/seven-power
install -Dm755 /opt/SevenOS/bin/seven-wifi /usr/local/bin/seven-wifi
install -Dm755 /opt/SevenOS/bin/seven-welcome /usr/local/bin/seven-welcome
install -Dm755 /opt/SevenOS/bin/seven-waybar-profile /usr/local/bin/seven-waybar-profile
install -Dm755 /opt/SevenOS/bin/seven-waybar-security /usr/local/bin/seven-waybar-security
install -Dm755 /opt/SevenOS/bin/sevenpkg /usr/local/bin/sevenpkg
install -Dm755 /opt/SevenOS/scripts/boot-splash.sh /usr/local/bin/seven-boot-splash
install -Dm755 /opt/SevenOS/scripts/network.sh /usr/local/bin/seven-network

install -d /usr/share/plymouth/themes/sevenos
install -m0644 /opt/SevenOS/branding/plymouth/sevenos/sevenos.plymouth /usr/share/plymouth/themes/sevenos/sevenos.plymouth
install -m0644 /opt/SevenOS/branding/plymouth/sevenos/sevenos.script /usr/share/plymouth/themes/sevenos/sevenos.script
install -m0644 /opt/SevenOS/branding/plymouth/sevenos/seven-prism.png /usr/share/plymouth/themes/sevenos/seven-prism.png
install -d /etc/plymouth
cat >/etc/plymouth/plymouthd.conf <<'EOF'
[Daemon]
Theme=sevenos
ShowDelay=0
EOF
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  plymouth-set-default-theme sevenos || true
fi
