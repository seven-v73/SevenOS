#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"
source "$ROOT_DIR/installer/lib.sh"

PLAN_FILE="$ROOT_DIR/out/installer/sevenos-install-plan.conf"
OUT_DIR="$ROOT_DIR/out/installer"
SCRIPT_FILE="$OUT_DIR/sevenos-install-steps.sh"

usage() {
  cat <<'EOF'
SevenOS install script generator

Usage:
  ./install.sh installer-script [--plan PATH] [--dry-run]

Generates a reviewed installation step script from a plan.
The generated script is intentionally non-destructive: it prints the
planned disk commands instead of executing them.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --plan) PLAN_FILE="${2:-}"; shift 2 ;;
    --dry-run) export SEVENOS_DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) log_error "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if ! is_dry_run || [[ -f "$PLAN_FILE" ]]; then
  "$ROOT_DIR/installer/validate-plan.sh" --plan "$PLAN_FILE"
fi
installer_source_plan_or_default "$PLAN_FILE"

write_script() {
  if is_dry_run; then
    printf 'mkdir -p %q\n' "$OUT_DIR"
    printf 'write install preview script to %q\n' "$SCRIPT_FILE"
    return 0
  fi

  mkdir -p "$OUT_DIR"
  cat > "$SCRIPT_FILE" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail

echo "SevenOS install preview"
echo "Target disk: $target_disk"
echo "Hostname: $hostname"
echo "Username: $username"
echo "LUKS: $luks"
echo "Profiles: $profiles"
echo "Filesystem: $filesystem"
echo "Bootloader: $bootloader"
echo "Timezone: $timezone"
echo "Locale: $locale"
echo "Keymap: $keymap"
echo "Swap: $swap"
echo
echo "This script is non-destructive. It prints the future install steps."
echo

step() {
  printf '\\n== %s ==\\n' "\$*"
}

run_preview() {
  printf 'DRY-RUN: %s\\n' "\$*"
}

step "Disk preparation"
run_preview "wipefs -a $target_disk"
run_preview "partition $target_disk with EFI and root layout"

if [[ "$luks" == "yes" ]]; then
  step "Encryption"
  run_preview "cryptsetup luksFormat <root-partition>"
  run_preview "cryptsetup open <root-partition> sevenos-root"
fi

step "Filesystems"
run_preview "mkfs.fat -F32 <efi-partition>"
if [[ "$filesystem" == "btrfs" ]]; then
  run_preview "mkfs.btrfs -f <root-target>"
  run_preview "create btrfs subvolumes @, @home, @var, @snapshots"
else
  run_preview "mkfs.ext4 <root-target>"
fi

step "Mount"
run_preview "mount <root-target> /mnt"
if [[ "$filesystem" == "btrfs" ]]; then
  run_preview "mount btrfs subvolume @ at /mnt"
  run_preview "mount btrfs subvolumes @home, @var, @snapshots"
fi
run_preview "mount --mkdir <efi-partition> /mnt/boot"

step "Swap"
case "$swap" in
  zram) run_preview "enable zram-generator in target system" ;;
  swapfile) run_preview "create and enable swapfile after root filesystem setup" ;;
  none) run_preview "skip swap configuration" ;;
esac

step "Base install"
base_packages="base linux linux-firmware networkmanager sudo git"
if [[ "$filesystem" == "btrfs" ]]; then
  base_packages="$base_packages btrfs-progs"
fi
if [[ "$swap" == "zram" ]]; then
  base_packages="$base_packages zram-generator"
fi
if [[ "$bootloader" == "grub" ]]; then
  base_packages="$base_packages grub efibootmgr"
fi
run_preview "pacstrap -K /mnt $base_packages"

step "System configuration"
run_preview "genfstab -U /mnt >> /mnt/etc/fstab"
run_preview "arch-chroot /mnt ln -sf /usr/share/zoneinfo/$timezone /etc/localtime"
run_preview "arch-chroot /mnt hwclock --systohc"
run_preview "arch-chroot /mnt localectl set-locale LANG=$locale"
run_preview "arch-chroot /mnt localectl set-keymap $keymap"
run_preview "arch-chroot /mnt hostnamectl hostname $hostname"
run_preview "arch-chroot /mnt useradd -m -G wheel -s /bin/bash $username"

step "SevenOS bootstrap"
run_preview "copy /opt/SevenOS or cloned repository into target"
run_preview "arch-chroot /mnt /opt/SevenOS/install.sh base"
run_preview "arch-chroot /mnt /opt/SevenOS/install.sh theme"

step "Profiles"
IFS=',' read -r -a profile_list <<< "$profiles"
for profile in "\${profile_list[@]}"; do
  if [[ "\$profile" != "base" ]]; then
    run_preview "arch-chroot /mnt /opt/SevenOS/install.sh \$profile"
  fi
done

step "Bootloader"
if [[ "$bootloader" == "systemd-boot" ]]; then
  run_preview "arch-chroot /mnt bootctl install"
  run_preview "write systemd-boot loader entries"
else
  run_preview "arch-chroot /mnt pacman -S --needed grub efibootmgr"
  run_preview "arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=SevenOS"
  run_preview "arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg"
fi

echo
echo "Preview complete. Future destructive mode must require typed confirmation."
EOF
  chmod +x "$SCRIPT_FILE"
}

write_script
log_success "Install preview script generated: $SCRIPT_FILE"
