#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

package_file_state() {
  local package_file="$1"
  local installed=0
  local total=0
  local package

  while IFS= read -r package; do
    package="${package%%#*}"
    package="${package//[[:space:]]/}"
    [[ -z "$package" ]] && continue

    total=$((total + 1))
    if pacman -Q "$package" >/dev/null 2>&1; then
      installed=$((installed + 1))
    fi
  done < "$package_file"

  if [[ "$total" -eq 0 ]]; then
    printf 'MISS 0/0'
  elif [[ "$installed" -eq "$total" ]]; then
    printf 'OK %s/%s' "$installed" "$total"
  elif [[ "$installed" -gt 0 ]]; then
    printf 'PART %s/%s' "$installed" "$total"
  else
    printf 'MISS %s/%s' "$installed" "$total"
  fi
}

print_category() {
  local label="$1"
  local file="$2"
  printf '  %-14s %s\n' "$label" "$(package_file_state "$file")"
}

blackarch_state() {
  if pacman-conf --repo-list 2>/dev/null | grep -qx 'blackarch'; then
    printf 'OK'
  elif grep -Eq '^\[blackarch\]' /etc/pacman.conf 2>/dev/null; then
    printf 'PART'
  else
    printf 'MISS'
  fi
}

command_state() {
  local command_name="$1"
  command -v "$command_name" >/dev/null 2>&1 && printf 'OK' || printf 'MISS'
}

printf 'SevenOS Cyber Audit\n\n'

printf 'Official Arch cyber layers:\n'
print_category "core" "$ROOT_DIR/scripts/packages-cybersecurity.txt"
print_category "forensics" "$ROOT_DIR/scripts/packages-cybersecurity-forensics.txt"
print_category "reversing" "$ROOT_DIR/scripts/packages-cybersecurity-reversing.txt"
print_category "wireless" "$ROOT_DIR/scripts/packages-cybersecurity-wireless.txt"
print_category "sandbox" "$ROOT_DIR/scripts/packages-cybersecurity-sandbox.txt"

printf '\nRuntime readiness:\n'
printf '  %-14s %s\n' "blackarch" "$(blackarch_state)"
printf '  %-14s %s\n' "wireshark" "$(id -nG "$USER" 2>/dev/null | tr ' ' '\n' | grep -qx wireshark && printf OK || printf MISS)"
printf '  %-14s %s\n' "firejail" "$(command_state firejail)"
printf '  %-14s %s\n' "bubblewrap" "$(command_state bwrap)"
printf '  %-14s %s\n' "ufw" "$(systemctl is-active --quiet ufw.service 2>/dev/null && printf OK || printf MISS)"

printf '\nGuidance:\n'
printf '  SevenOS installs a broad official Arch cyber base first.\n'
printf '  Use BlackArch only as an optional bridge for specialized tools and categories.\n'
printf '  Run: ./install.sh blackarch-setup --dry-run\n'
