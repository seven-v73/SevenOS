#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sevenos"
PLAN="$STATE_DIR/system-repair-required.sh"

usage() {
  cat <<'EOF'
SevenOS system repair

Usage:
  ./scripts/system-repair.sh plan
  ./scripts/system-repair.sh apply

This repair handles host-level services that require root privileges. If sudo
is not already unlocked, SevenOS writes a precise repair script to:
  ~/.config/sevenos/system-repair-required.sh
EOF
}

write_plan() {
  mkdir -p "$STATE_DIR"
  cat >"$PLAN" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

echo "[SevenOS] Repairing host-level service state..."

if systemctl list-unit-files mongodb.service >/dev/null 2>&1; then
  # MongoDB is a Forge DevOps capability, not a base Equinox boot service.
  sudo systemctl disable --now mongodb.service || true
fi

if systemctl list-unit-files systemd-networkd-wait-online.service >/dev/null 2>&1; then
  # SevenOS uses NetworkManager by default; networkd wait-online can stall/dirty boot.
  sudo systemctl disable --now systemd-networkd-wait-online.service || true
fi

sudo systemctl reset-failed mongodb.service systemd-networkd-wait-online.service 'polkit-agent-helper@*.service' || true
sudo systemctl reset-failed || true

if systemctl --user list-unit-files sevenos-polkit-agent.service >/dev/null 2>&1; then
  systemctl --user daemon-reload || true
  systemctl --user enable --now sevenos-polkit-agent.service || true
  if ! pgrep -u "$USER" -f '^/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1($| )|^/usr/lib/polkit-kde-authentication-agent-1($| )|lxqt-policykit-agent|mate-polkit' >/dev/null 2>&1; then
    systemctl --user restart sevenos-polkit-agent.service || true
  fi
fi

if systemctl is-active --quiet ufw.service 2>/dev/null; then
  rm -f "${XDG_STATE_HOME:-$HOME/.local/state}/sevenos/security/ufw-degraded"
fi

echo "[SevenOS] Host service repair completed."
systemctl --failed --plain --no-legend || true
EOF
  chmod +x "$PLAN"
  log_warn "Root privileges are required for host service repair."
  log_info "Run when ready: $PLAN"
}

apply_repair() {
  mkdir -p "$STATE_DIR"
  if systemctl is-active --quiet ufw.service 2>/dev/null; then
    rm -f "${XDG_STATE_HOME:-$HOME/.local/state}/sevenos/security/ufw-degraded"
  fi

  if ! sudo -n true 2>/dev/null; then
    write_plan
    return 2
  fi

  if systemctl list-unit-files mongodb.service >/dev/null 2>&1; then
    sudo systemctl disable --now mongodb.service || true
  fi
  if systemctl list-unit-files systemd-networkd-wait-online.service >/dev/null 2>&1; then
    sudo systemctl disable --now systemd-networkd-wait-online.service || true
  fi
  sudo systemctl reset-failed mongodb.service systemd-networkd-wait-online.service 'polkit-agent-helper@*.service' || true
  sudo systemctl reset-failed || true
  if systemctl --user list-unit-files sevenos-polkit-agent.service >/dev/null 2>&1; then
    systemctl --user daemon-reload || true
    systemctl --user enable --now sevenos-polkit-agent.service || true
    if ! pgrep -u "$USER" -f '^/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1($| )|^/usr/lib/polkit-kde-authentication-agent-1($| )|lxqt-policykit-agent|mate-polkit' >/dev/null 2>&1; then
      systemctl --user restart sevenos-polkit-agent.service || true
    fi
  fi
  rm -f "$PLAN"
  log_success "Host service repair applied."
}

case "${1:-plan}" in
  plan) write_plan ;;
  apply) apply_repair ;;
  status)
    if [[ -x "$PLAN" ]]; then
      printf 'PENDING\t%s\n' "$PLAN"
    else
      printf 'OK\tno root repair plan pending\n'
    fi
    ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown system repair action: $1"; usage; exit 1 ;;
esac
