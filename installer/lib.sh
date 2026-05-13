#!/usr/bin/env bash

installer_default_plan() {
  target_disk="/dev/sdX"
  hostname="sevenos"
  username="seven"
  luks="yes"
  profiles="dev"
  filesystem="btrfs"
  bootloader="systemd-boot"
  timezone="UTC"
  locale="en_US.UTF-8"
  keymap="us"
  swap="zram"
}

installer_source_plan_or_default() {
  local plan_file="$1"

  if is_dry_run && [[ ! -f "$plan_file" ]]; then
    installer_default_plan
    return 0
  fi

  if [[ ! -f "$plan_file" ]]; then
    log_error "Install plan not found: $plan_file"
    log_info "Create one with: ./install.sh installer-plan"
    exit 1
  fi

  installer_default_plan
  # shellcheck source=/dev/null
  source "$plan_file"
}
