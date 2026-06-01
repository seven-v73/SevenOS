#!/usr/bin/env bash
set -euo pipefail

ln -sf /usr/share/zoneinfo/UTC /etc/localtime
systemctl enable NetworkManager.service
systemctl enable ModemManager.service 2>/dev/null || true
systemctl enable plymouth-quit.service 2>/dev/null || true
systemctl enable sevenos-live-session.service 2>/dev/null || true
systemctl set-default graphical.target

useradd -m -G wheel -s /bin/bash seven
for group in video input audio storage network uucp; do
  getent group "$group" >/dev/null 2>&1 && usermod -aG "$group" seven || true
done
passwd -d seven

install -d /etc/systemd/system/getty@tty1.service.d
cat >/etc/systemd/system/getty@tty1.service.d/20-sevenos-live-autologin.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin seven --noclear %I $TERM
EOF

install -d /etc/sddm.conf.d /usr/share/wayland-sessions
cat >/etc/sddm.conf.d/20-sevenos-live.conf <<'EOF'
[Autologin]
User=seven
Session=sevenos-live.desktop
Relogin=true

[Theme]
Current=sevenos

[Users]
MinimumUid=1000
MaximumUid=60513
EOF
cat >/usr/share/wayland-sessions/sevenos-live.desktop <<'EOF'
[Desktop Entry]
Name=SevenOS Live
Comment=SevenOS graphical live session
Exec=/usr/local/bin/sevenos-live-session
Type=Application
DesktopNames=SevenOS;Hyprland
EOF

install -Dm755 /opt/SevenOS/bin/sevenosctl /usr/local/bin/sevenosctl
install -Dm755 /opt/SevenOS/bin/seven /usr/local/bin/seven
install -Dm755 /opt/SevenOS/bin/seven-country /usr/local/bin/seven-country
install -Dm755 /opt/SevenOS/bin/seven-installer /usr/local/bin/seven-installer
install -Dm755 /opt/SevenOS/bin/seven-installer-native /usr/local/bin/seven-installer-native
install -Dm755 /opt/SevenOS/bin/seven-power /usr/local/bin/seven-power
install -Dm755 /opt/SevenOS/bin/seven-wifi /usr/local/bin/seven-wifi
install -Dm755 /opt/SevenOS/bin/seven-welcome /usr/local/bin/seven-welcome
install -Dm755 /opt/SevenOS/bin/seven-waybar-profile /usr/local/bin/seven-waybar-profile
install -Dm755 /opt/SevenOS/bin/seven-waybar-security /usr/local/bin/seven-waybar-security
install -Dm755 /opt/SevenOS/bin/sevenpkg /usr/local/bin/sevenpkg
install -Dm755 /opt/SevenOS/scripts/boot-splash.sh /usr/local/bin/seven-boot-splash
install -Dm755 /opt/SevenOS/scripts/login-theme.sh /usr/local/bin/seven-login-theme
install -Dm755 /opt/SevenOS/scripts/network.sh /usr/local/bin/seven-network
install -Dm644 /opt/SevenOS/identity/assets/icon-installer.svg /usr/share/icons/hicolor/scalable/apps/seven-installer.svg

install -d /etc/calamares/modules /usr/share/calamares/branding/sevenos
install -m0644 /opt/SevenOS/installer/calamares/settings.conf /etc/calamares/settings.conf
install -m0644 /opt/SevenOS/installer/calamares/modules/shellprocess.conf /etc/calamares/modules/shellprocess.conf
install -m0644 /opt/SevenOS/installer/calamares/modules/sevenos.conf /etc/calamares/modules/sevenos.conf
cp -a /opt/SevenOS/installer/calamares/branding/sevenos/. /usr/share/calamares/branding/sevenos/

if [[ -x /opt/SevenOS/scripts/install-cli.sh ]]; then
  env SEVENOS_ROOT=/opt/SevenOS SEVENOS_HOST_HOME=/home/seven HOME=/home/seven USER=seven \
    /opt/SevenOS/scripts/install-cli.sh || true
fi

install -d \
  /home/seven/.config/hypr \
  /home/seven/.config/waybar \
  /home/seven/.config/kitty \
  /home/seven/.config/rofi \
  /home/seven/.config/mako \
  /home/seven/.config/swaync \
  /home/seven/.config/wlogout \
  /home/seven/.config/gtk-3.0 \
  /home/seven/.config/gtk-4.0 \
  /home/seven/.config/qt5ct \
  /home/seven/.config/qt6ct \
  /home/seven/.config/fontconfig \
  /home/seven/.config/sevenos \
  /home/seven/.config/systemd/user \
  /home/seven/.local/share/applications

install -m0644 /opt/SevenOS/hyprland/hyprland.conf /home/seven/.config/hypr/hyprland.conf
cp -a /opt/SevenOS/hyprland/conf /home/seven/.config/hypr/
cp -a /opt/SevenOS/hyprland/lua /home/seven/.config/hypr/
cp -a /opt/SevenOS/hyprland/waybar/. /home/seven/.config/waybar/
cp -a /opt/SevenOS/hyprland/kitty/. /home/seven/.config/kitty/
cp -a /opt/SevenOS/hyprland/rofi/. /home/seven/.config/rofi/
cp -a /opt/SevenOS/hyprland/mako/. /home/seven/.config/mako/
cp -a /opt/SevenOS/hyprland/swaync/. /home/seven/.config/swaync/
cp -a /opt/SevenOS/hyprland/wlogout/. /home/seven/.config/wlogout/
cp -a /opt/SevenOS/hyprland/gtk-3.0/. /home/seven/.config/gtk-3.0/
cp -a /opt/SevenOS/hyprland/gtk-4.0/. /home/seven/.config/gtk-4.0/
cp -a /opt/SevenOS/hyprland/qt5ct/. /home/seven/.config/qt5ct/
cp -a /opt/SevenOS/hyprland/qt6ct/. /home/seven/.config/qt6ct/
cp -a /opt/SevenOS/hyprland/fontconfig/. /home/seven/.config/fontconfig/
cp -a /opt/SevenOS/systemd/user/. /home/seven/.config/systemd/user/
cp -a /opt/SevenOS/seven-hub/*.desktop /home/seven/.local/share/applications/ 2>/dev/null || true
cp -a /opt/SevenOS/archiso/profile/airootfs/usr/share/applications/*.desktop /home/seven/.local/share/applications/ 2>/dev/null || true

cat >/home/seven/.config/sevenos/profile.env <<'EOF'
SEVENOS_PROFILE=equinox
EOF
cat >/home/seven/.config/sevenos/theme.conf <<'EOF'
SEVENOS_THEME_MODE=dark
EOF
cat >/home/seven/.config/sevenos/language.env <<'EOF'
SEVENOS_LANGUAGE=en_US.UTF-8
LANG=en_US.UTF-8
LC_MESSAGES=en_US.UTF-8
LANGUAGE=en
EOF
cat >/home/seven/.bash_profile <<'EOF'
if [[ -z "${WAYLAND_DISPLAY:-}${DISPLAY:-}" && "${XDG_VTNR:-}" == "1" ]]; then
  export SEVENOS_ROOT=/opt/SevenOS
  export SEVENOS_LIVE_SESSION=1
  exec /usr/local/bin/sevenos-live-session
fi
EOF
cat >>/home/seven/.config/hypr/conf/custom.conf <<'EOF'

# SevenOS live ISO first-screen route.
exec-once = /usr/local/bin/sevenos-live-ready
EOF

chown -R seven:seven /home/seven
runuser -u seven -- systemctl --user enable sevenos-session.target 2>/dev/null || true

SEVENOS_ROOT=/opt/SevenOS /opt/SevenOS/scripts/boot-splash.sh theme --yes || {
  install -d /usr/share/plymouth/themes/sevenos
  install -m0644 /opt/SevenOS/branding/plymouth/sevenos/sevenos.plymouth /usr/share/plymouth/themes/sevenos/sevenos.plymouth
  install -m0644 /opt/SevenOS/branding/plymouth/sevenos/sevenos.script /usr/share/plymouth/themes/sevenos/sevenos.script
  install -m0644 /opt/SevenOS/branding/plymouth/sevenos/seven-prism.png /usr/share/plymouth/themes/sevenos/seven-prism.png
}
install -d /etc/plymouth
cat >/etc/plymouth/plymouthd.conf <<'EOF'
[Daemon]
Theme=sevenos
ShowDelay=0
EOF
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  plymouth-set-default-theme sevenos || true
fi

SEVENOS_ROOT=/opt/SevenOS /opt/SevenOS/scripts/login-theme.sh apply --yes || {
  install -d /usr/share/sddm/themes/sevenos/assets /etc/sddm.conf.d
  install -m0644 /opt/SevenOS/branding/sddm/sevenos/Main.qml /usr/share/sddm/themes/sevenos/Main.qml
  install -m0644 /opt/SevenOS/branding/sddm/sevenos/theme.conf /usr/share/sddm/themes/sevenos/theme.conf
  install -m0644 /opt/SevenOS/branding/sddm/sevenos/metadata.desktop /usr/share/sddm/themes/sevenos/metadata.desktop
  install -m0644 /opt/SevenOS/branding/sddm/sevenos/assets/seven-prism.png /usr/share/sddm/themes/sevenos/assets/seven-prism.png
  printf '[Theme]\nCurrent=sevenos\n' >/etc/sddm.conf.d/10-sevenos-theme.conf
}
