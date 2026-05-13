#!/usr/bin/env bash

iso_name="sevenos"
iso_label="SEVENOS_$(date +%Y%m)"
iso_publisher="SevenOS <https://github.com/seven-v73/SevenOS>"
iso_application="SevenOS Live ISO"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=("iso")
bootmodes=("bios.syslinux.mbr" "bios.syslinux.eltorito" "uefi-x64.systemd-boot.esp" "uefi-x64.systemd-boot.eltorito")
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=("-comp" "xz" "-Xbcj" "x86" "-b" "1M" "-Xdict-size" "1M")
file_permissions=(
  ["/root"]="0:0:750"
  ["/etc/sudoers.d/99-sevenos"]="0:0:440"
  ["/usr/local/bin/sevenos-welcome"]="0:0:755"
)
