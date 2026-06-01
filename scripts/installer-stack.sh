#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS installer stack

Usage:
  ./scripts/installer-stack.sh [status|install|doctor|plan|guide|release|graphical|runtime|iso-runtime|experience] [--json]

Actions:
  status   Show installer tooling state
  status --json
           Show machine-readable installer tooling state
  install  Install official installer foundation packages
  doctor   Validate SevenOS installer foundation
  plan     Explain Calamares + Archinstall next steps
  plan --json
           Show prioritized installer/ISO productization actions
  guide    Show the normal-user install path SevenOS exposes today
  release  Show public-ISO release readiness checks
  graphical
           Show graphical installer route readiness
  runtime  Show Calamares runtime source/readiness policy
  iso-runtime
           Show or build the Calamares package source used by the ISO
  experience
           Show the public install experience: hardware, GPU, presets and post-install
EOF
}

JSON_OUTPUT=0

state() {
  local command_name="$1"
  command -v "$command_name" >/dev/null 2>&1 && printf OK || printf MISS
}

file_state() {
  local path="$1"
  [[ -s "$ROOT_DIR/$path" ]] && printf OK || printf MISS
}

dir_state() {
  local path="$1"
  [[ -d "$ROOT_DIR/$path" ]] && printf OK || printf MISS
}

contains_state() {
  local path="$1"
  local pattern="$2"
  [[ -s "$ROOT_DIR/$path" ]] && grep -Fq -- "$pattern" "$ROOT_DIR/$path" && printf OK || printf MISS
}

calamares_runtime_json() {
  local calamares_state aur_manifest_state yay_state paru_state pacman_candidate iso_runtime_state
  calamares_state="$(state calamares)"
  aur_manifest_state="$(contains_state scripts/packages-installer-aur.txt "calamares")"
  yay_state="$(state yay)"
  paru_state="$(state paru)"
  iso_runtime_state="$("$ROOT_DIR/scripts/calamares-runtime.sh" status --json 2>/dev/null | python -c 'import json,sys; print(json.load(sys.stdin).get("state","unknown"))' 2>/dev/null || printf unknown)"
  if timeout 4 pacman -Si calamares >/dev/null 2>&1; then
    pacman_candidate="OK"
  else
    pacman_candidate="MISS"
  fi

  CALAMARES_STATE="$calamares_state" AUR_MANIFEST_STATE="$aur_manifest_state" \
  YAY_STATE="$yay_state" PARU_STATE="$paru_state" PACMAN_CANDIDATE="$pacman_candidate" \
  ISO_RUNTIME_STATE="$iso_runtime_state" \
  python - <<'PY'
import json
import os

calamares = os.environ["CALAMARES_STATE"]
aur_manifest = os.environ["AUR_MANIFEST_STATE"]
yay = os.environ["YAY_STATE"]
paru = os.environ["PARU_STATE"]
pacman = os.environ["PACMAN_CANDIDATE"]
iso_runtime = os.environ["ISO_RUNTIME_STATE"]
helper = "yay" if yay == "OK" else "paru" if paru == "OK" else ""

if calamares == "OK":
    state = "installed"
elif iso_runtime == "iso-runtime-ready":
    state = "iso-runtime-ready"
elif pacman == "OK":
    state = "official-candidate"
elif aur_manifest == "OK" and helper:
    state = "aur-candidate"
elif aur_manifest == "OK":
    state = "source-declared"
else:
    state = "missing-source"

if state == "installed":
    route = "graphical-runtime"
    readiness = "ready"
    next_actions = [
        {
            "key": "open-installer",
            "title": "Open SevenOS graphical installer",
            "command": "seven-installer open",
            "impact": "changes",
            "reason": "Calamares is present; destructive disk steps still require installer confirmation.",
        }
    ]
elif state == "official-candidate":
    route = "official-package"
    readiness = "installable"
    next_actions = [
        {
            "key": "install-calamares",
            "title": "Install graphical installer runtime",
            "command": "sudo pacman -S --needed calamares",
            "impact": "packages",
            "reason": "The current package repositories expose Calamares directly.",
        }
    ]
elif state == "iso-runtime-ready":
    route = "archiso-local-repo"
    readiness = "iso-ready"
    next_actions = [
        {
            "key": "build-iso",
            "title": "Build the graphical installer ISO",
            "command": "./install.sh iso --dry-run",
            "impact": "safe",
            "reason": "The archiso profile declares Calamares and the local package repository is ready.",
        }
    ]
elif state == "aur-candidate":
    route = "aur-helper"
    readiness = "source-ready"
    next_actions = [
        {
            "key": "install-calamares-aur",
            "title": "Build graphical installer runtime",
            "command": f"{helper} -S --needed calamares",
            "impact": "packages",
            "reason": "SevenOS has a Calamares AUR manifest and a local AUR helper is available.",
        }
    ]
elif state == "source-declared":
    route = "aur-source"
    readiness = "helper-needed"
    next_actions = [
        {
            "key": "install-aur-helper",
            "title": "Prepare AUR helper route",
            "command": "./install.sh aur-helpers --yes",
            "impact": "packages",
            "reason": "SevenOS has a Calamares source manifest, but no yay/paru helper is available yet.",
        }
    ]
else:
    route = "missing"
    readiness = "blocked"
    next_actions = [
        {
            "key": "declare-calamares-source",
            "title": "Declare graphical installer runtime source",
            "command": "seven installer runtime",
            "impact": "changes",
            "reason": "SevenOS needs an official, downstream or AUR runtime source before graphical release work can continue.",
        }
    ]

print(json.dumps({
    "schema": "sevenos.calamares-runtime.v1",
    "state": state,
    "route": route,
    "readiness": readiness,
    "installed": calamares == "OK",
    "sources": {
        "pacman": pacman,
        "iso_runtime": iso_runtime,
        "aur_manifest": aur_manifest,
        "yay": yay,
        "paru": paru,
        "recommended_helper": helper,
    },
    "policy": [
        "SevenOS does not mark public ISO graphical-ready until calamares is present in the ISO runtime.",
        "Arch hosts may need a trusted downstream repository or AUR build for calamares.",
        "The SevenOS Calamares profile remains in-repo and is validated separately from runtime packaging.",
    ],
    "commands": {
        "status": "seven installer runtime --json",
        "iso_runtime": "seven installer iso-runtime --json",
        "graphical": "seven installer graphical",
        "aur_helpers": "./install.sh aur-helpers --yes",
        "aur_manifest": "scripts/packages-installer-aur.txt",
    },
    "next": next_actions,
}, indent=2))
PY
}

json_string() {
  python -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))'
}

release_json() {
  local archinstall_state calamares_state planner_state calamares_settings_state calamares_module_state calamares_shellprocess_state calamares_postinstall_state calamares_iso_config_state
  local archiso_state build_state packages_state repo_injection_state live_cli_state graphical_launcher_state native_launcher_state native_live_ui_state live_desktop_state live_native_state calamares_branding_state installer_portal_state calamares_source_state local_repo_db_state local_repo_pkg_state
  local live_session_state live_autologin_state live_ready_state live_tty_fallback_state live_user_config_state live_network_state live_graphical_target_state
  local live_feedback_state live_services_state live_user_dirs_state live_status_state live_quiet_boot_state live_initramfs_state

  archinstall_state="$(state archinstall)"
  calamares_state="$(state calamares)"
  calamares_source_state="$(calamares_runtime_json | python -c 'import json,sys; print(json.load(sys.stdin).get("state","unknown"))')"
  planner_state="$([[ -x "$ROOT_DIR/installer/plan.sh" ]] && printf OK || printf MISS)"
  calamares_settings_state="$(file_state installer/calamares/settings.conf)"
  calamares_module_state="$(file_state installer/calamares/modules/sevenos.conf)"
  calamares_shellprocess_state="$([[ $(contains_state installer/calamares/settings.conf "- shellprocess") == OK && $(file_state installer/calamares/modules/shellprocess.conf) == OK ]] && printf OK || printf MISS)"
  calamares_postinstall_state="$([[ $(contains_state installer/calamares/modules/shellprocess.conf "/opt/SevenOS/bin/seven-calamares-finalize") == OK && -x "$ROOT_DIR/bin/seven-calamares-finalize" ]] && printf OK || printf MISS)"
  calamares_iso_config_state="$([[ $(contains_state archiso/profile/airootfs/root/customize_airootfs.sh "/etc/calamares/settings.conf") == OK && $(contains_state archiso/profile/airootfs/root/customize_airootfs.sh "/usr/share/calamares/branding/sevenos") == OK && $(contains_state archiso/profile/airootfs/root/customize_airootfs.sh "shellprocess.conf") == OK ]] && printf OK || printf MISS)"
  graphical_launcher_state="$([[ -x "$ROOT_DIR/bin/seven-installer" ]] && printf OK || printf MISS)"
  native_launcher_state="$([[ -x "$ROOT_DIR/bin/seven-installer-native" ]] && printf OK || printf MISS)"
  native_live_ui_state="$([[ $(contains_state bin/seven-installer-native "live-status") == OK && $(contains_state bin/seven-installer-native "status_cards") == OK && $(contains_state bin/seven-installer-native "installer-progress") == OK && $(contains_state bin/seven-installer-native "timeline_card") == OK && $(contains_state bin/seven-installer-native "GLib.timeout_add_seconds") == OK && $(contains_state bin/seven-installer-native "active_step_label") == OK && $(contains_state bin/seven-installer-native "decision_label") == OK && $(contains_state bin/seven-installer-native "attention_label") == OK && $(contains_state bin/seven-installer-native "primary_live_action") == OK && $(contains_state bin/seven-installer-native "secondary_action_buttons") == OK && $(contains_state bin/seven-installer "user_message") == OK && $(contains_state bin/seven-installer "primary_command") == OK && $(contains_state bin/seven-installer "secondary_actions") == OK && $(contains_state bin/seven-installer "attention_items") == OK ]] && printf OK || printf MISS)"
  installer_portal_state="$("$ROOT_DIR/bin/seven-installer" status --json 2>/dev/null | grep -q 'sevenos.installer-portal.v1' && printf OK || printf MISS)"
  live_desktop_state="$(contains_state archiso/profile/airootfs/usr/share/applications/seven-installer.desktop "Exec=seven-installer")"
  calamares_branding_state="$(file_state installer/calamares/branding/sevenos/branding.desc)"
  archiso_state="$(dir_state archiso/profile)"
  build_state="$([[ -x "$ROOT_DIR/scripts/build-iso.sh" ]] && printf OK || printf MISS)"
  packages_state="$(file_state archiso/profile/packages.x86_64)"
  repo_injection_state="$(contains_state scripts/build-iso.sh "sevenos-local")"
  live_cli_state="$(contains_state archiso/profile/airootfs/root/customize_airootfs.sh "/opt/SevenOS/bin/seven")"
  live_native_state="$(contains_state archiso/profile/airootfs/root/customize_airootfs.sh "seven-installer-native")"
  live_session_state="$([[ -x "$ROOT_DIR/archiso/profile/airootfs/usr/local/bin/sevenos-live-session" && $(contains_state archiso/profile/airootfs/etc/systemd/system/sevenos-live-session.service "ExecStart=/usr/local/bin/sevenos-live-session") == OK && $(contains_state archiso/profile/airootfs/root/customize_airootfs.sh "sevenos-live-session.service") == OK ]] && printf OK || printf MISS)"
  live_autologin_state="$([[ $(contains_state archiso/profile/airootfs/etc/systemd/system/sevenos-live-session.service "User=seven") == OK && $(contains_state archiso/profile/airootfs/etc/systemd/system/sevenos-live-session.service "PAMName=login") == OK && $(contains_state archiso/profile/airootfs/etc/systemd/system/sevenos-live-session.service "TTYPath=/dev/tty1") == OK ]] && printf OK || printf MISS)"
  live_ready_state="$([[ -x "$ROOT_DIR/archiso/profile/airootfs/usr/local/bin/sevenos-live-ready" ]] && contains_state archiso/profile/airootfs/root/customize_airootfs.sh "sevenos-live-ready")"
  live_tty_fallback_state="$(contains_state archiso/profile/airootfs/root/customize_airootfs.sh "agetty --autologin seven")"
  live_quiet_boot_state="$([[ $(contains_state archiso/profile/efiboot/loader/entries/01-sevenos-live.conf "quiet splash") == OK && $(contains_state archiso/profile/efiboot/loader/entries/01-sevenos-live.conf "systemd.show_status=false") == OK && $(contains_state archiso/profile/syslinux/archiso_sys-linux.cfg "quiet splash") == OK && $(contains_state archiso/profile/efiboot/loader/entries/03-sevenos-live-safe.conf "Safe Graphics") == OK && $(contains_state archiso/profile/syslinux/archiso_sys-linux.cfg "Safe ^Graphics") == OK ]] && printf OK || printf MISS)"
  live_initramfs_state="$([[ $(contains_state archiso/profile/packages.x86_64 "mkinitcpio-archiso") == OK && $(contains_state archiso/profile/airootfs/etc/mkinitcpio.conf.d/archiso.conf "archiso_loop_mnt") == OK ]] && printf OK || printf MISS)"
  live_user_config_state="$(contains_state archiso/profile/airootfs/root/customize_airootfs.sh "/home/seven/.config/hypr/hyprland.conf")"
  live_network_state="$(contains_state archiso/profile/airootfs/root/customize_airootfs.sh "systemctl enable NetworkManager.service")"
  live_graphical_target_state="$(contains_state archiso/profile/airootfs/root/customize_airootfs.sh "systemctl set-default graphical.target")"
  live_feedback_state="$(contains_state archiso/profile/airootfs/usr/local/bin/sevenos-live-ready "notify-send")"
  live_services_state="$(contains_state archiso/profile/airootfs/usr/local/bin/sevenos-live-ready "sevenos-session.target")"
  live_user_dirs_state="$([[ $(contains_state archiso/profile/packages.x86_64 "xdg-user-dirs") == OK && $(contains_state archiso/profile/airootfs/usr/local/bin/sevenos-live-ready "xdg-user-dirs-update") == OK ]] && printf OK || printf MISS)"
  live_status_state="$("$ROOT_DIR/bin/seven-installer" live-status --json 2>/dev/null | grep -q 'sevenos.installer-live.v1' && printf OK || printf MISS)"
  local live_retry_state live_status_persist_state live_lock_state live_pid_state live_lock_expiry_state live_notify_status_state live_progress_state live_recommended_state live_desktop_i18n_state live_network_status_state live_storage_status_state live_system_status_state live_readiness_summary_state live_process_guard_state live_freshness_state live_timeline_state live_ui_i18n_state
  live_retry_state="$(contains_state bin/seven-installer "live-retry")"
  live_status_persist_state="$(contains_state archiso/profile/airootfs/usr/local/bin/sevenos-live-ready "live-status.json")"
  live_lock_state="$(contains_state archiso/profile/airootfs/usr/local/bin/sevenos-live-ready "live-ready.lock")"
  live_pid_state="$(contains_state archiso/profile/airootfs/usr/local/bin/sevenos-live-ready "installer_pid")"
  live_lock_expiry_state="$(contains_state archiso/profile/airootfs/usr/local/bin/sevenos-live-ready "lock_age")"
  live_notify_status_state="$(contains_state bin/seven-installer "live-notify")"
  live_progress_state="$([[ $(contains_state archiso/profile/airootfs/usr/local/bin/sevenos-live-ready "progress") == OK && $(contains_state bin/seven-installer "progress") == OK ]] && printf OK || printf MISS)"
  live_recommended_state="$(contains_state bin/seven-installer "recommended_action")"
  live_desktop_i18n_state="$(contains_state archiso/profile/airootfs/usr/share/applications/seven-installer.desktop "Name[fr]")"
  live_network_status_state="$([[ $(contains_state bin/seven-installer "NM_STATE") == OK && $(contains_state bin/seven-installer "connect-network") == OK ]] && printf OK || printf MISS)"
  live_storage_status_state="$([[ $(contains_state bin/seven-installer "install_targets") == OK && $(contains_state archiso/profile/packages.x86_64 "gnome-disk-utility") == OK ]] && printf OK || printf MISS)"
  live_system_status_state="$([[ $(contains_state bin/seven-installer "memory_ready") == OK && $(contains_state bin/seven-installer "power_safe") == OK ]] && printf OK || printf MISS)"
  live_readiness_summary_state="$([[ $(contains_state bin/seven-installer "readiness_state") == OK && $(contains_state bin/seven-installer "issues") == OK ]] && printf OK || printf MISS)"
  live_process_guard_state="$([[ $(contains_state archiso/profile/airootfs/usr/local/bin/sevenos-live-ready "confirm_installer_window") == OK && $(contains_state archiso/profile/airootfs/usr/local/bin/sevenos-live-ready "Installer portal closed before it became interactive") == OK ]] && printf OK || printf MISS)"
  live_freshness_state="$([[ $(contains_state bin/seven-installer "status_age_seconds") == OK && $(contains_state bin/seven-installer "live-helper-stale") == OK && $(contains_state archiso/profile/airootfs/usr/local/bin/sevenos-live-ready "elapsed_seconds") == OK ]] && printf OK || printf MISS)"
  live_timeline_state="$([[ $(contains_state bin/seven-installer "timeline_specs") == OK && $(contains_state bin/seven-installer '"timeline": timeline') == OK ]] && printf OK || printf MISS)"
  live_ui_i18n_state="$([[ $(contains_state bin/seven-installer '"ui":') == OK && $(contains_state bin/seven-installer "primary_action_label") == OK && $(contains_state bin/seven-installer "primary_command") == OK && $(contains_state bin/seven-installer "secondary_actions") == OK && $(contains_state bin/seven-installer "attention_items") == OK && $(contains_state bin/seven-installer "Aucun point bloquant détecté") == OK && $(contains_state bin/seven-installer "État détaillé") == OK && $(contains_state bin/seven-installer "Session graphique") == OK && $(contains_state bin/seven-installer "confidence") == OK && $(contains_state bin/seven-installer "next_step") == OK && $(contains_state bin/seven-installer "status_cards") == OK && $(contains_state bin/seven-installer "priority_card") == OK && $(contains_state bin/seven-installer "user_message") == OK && $(contains_state bin/seven-installer "SevenOS est prêt à installer") == OK && $(contains_state bin/seven-installer "can_continue") == OK && $(contains_state bin/seven-installer "safety_level") == OK && $(contains_state bin/seven-installer "pace_state") == OK && $(contains_state bin/seven-installer "estimated_remaining_seconds") == OK && $(contains_state bin/seven-installer "session_id") == OK && $(contains_state archiso/profile/airootfs/usr/local/bin/sevenos-live-ready "uuid.uuid4") == OK ]] && printf OK || printf MISS)"
  local_repo_db_state="$([[ -s "$ROOT_DIR/archiso/localrepo/x86_64/sevenos-local.db.tar.gz" ]] && printf OK || printf MISS)"
  local_repo_pkg_state="$(find "$ROOT_DIR/archiso/localrepo/x86_64" -maxdepth 1 -name 'calamares-*.pkg.tar.*' -print -quit 2>/dev/null | grep -q . && printf OK || printf MISS)"

  ARCHINSTALL_STATE="$archinstall_state" \
  CALAMARES_STATE="$calamares_state" \
  CALAMARES_SOURCE_STATE="$calamares_source_state" \
  PLANNER_STATE="$planner_state" \
  CALAMARES_SETTINGS_STATE="$calamares_settings_state" \
  CALAMARES_MODULE_STATE="$calamares_module_state" \
  CALAMARES_SHELLPROCESS_STATE="$calamares_shellprocess_state" \
  CALAMARES_POSTINSTALL_STATE="$calamares_postinstall_state" \
  CALAMARES_ISO_CONFIG_STATE="$calamares_iso_config_state" \
  GRAPHICAL_LAUNCHER_STATE="$graphical_launcher_state" \
  NATIVE_LAUNCHER_STATE="$native_launcher_state" \
  NATIVE_LIVE_UI_STATE="$native_live_ui_state" \
  INSTALLER_PORTAL_STATE="$installer_portal_state" \
  LIVE_DESKTOP_STATE="$live_desktop_state" \
  LIVE_NATIVE_STATE="$live_native_state" \
  CALAMARES_BRANDING_STATE="$calamares_branding_state" \
  ARCHISO_STATE="$archiso_state" \
  BUILD_STATE="$build_state" \
  PACKAGES_STATE="$packages_state" \
  REPO_INJECTION_STATE="$repo_injection_state" \
  LIVE_CLI_STATE="$live_cli_state" \
  LIVE_SESSION_STATE="$live_session_state" \
  LIVE_AUTOLOGIN_STATE="$live_autologin_state" \
  LIVE_READY_STATE="$live_ready_state" \
  LIVE_TTY_FALLBACK_STATE="$live_tty_fallback_state" \
  LIVE_QUIET_BOOT_STATE="$live_quiet_boot_state" \
  LIVE_INITRAMFS_STATE="$live_initramfs_state" \
  LIVE_USER_CONFIG_STATE="$live_user_config_state" \
  LIVE_NETWORK_STATE="$live_network_state" \
  LIVE_GRAPHICAL_TARGET_STATE="$live_graphical_target_state" \
  LIVE_FEEDBACK_STATE="$live_feedback_state" \
  LIVE_SERVICES_STATE="$live_services_state" \
  LIVE_USER_DIRS_STATE="$live_user_dirs_state" \
  LIVE_STATUS_STATE="$live_status_state" \
  LIVE_RETRY_STATE="$live_retry_state" \
  LIVE_STATUS_PERSIST_STATE="$live_status_persist_state" \
  LIVE_LOCK_STATE="$live_lock_state" \
  LIVE_PID_STATE="$live_pid_state" \
  LIVE_LOCK_EXPIRY_STATE="$live_lock_expiry_state" \
  LIVE_NOTIFY_STATUS_STATE="$live_notify_status_state" \
  LIVE_PROGRESS_STATE="$live_progress_state" \
  LIVE_RECOMMENDED_STATE="$live_recommended_state" \
  LIVE_DESKTOP_I18N_STATE="$live_desktop_i18n_state" \
  LIVE_NETWORK_STATUS_STATE="$live_network_status_state" \
  LIVE_STORAGE_STATUS_STATE="$live_storage_status_state" \
  LIVE_SYSTEM_STATUS_STATE="$live_system_status_state" \
  LIVE_READINESS_SUMMARY_STATE="$live_readiness_summary_state" \
  LIVE_PROCESS_GUARD_STATE="$live_process_guard_state" \
  LIVE_FRESHNESS_STATE="$live_freshness_state" \
  LIVE_TIMELINE_STATE="$live_timeline_state" \
  LIVE_UI_I18N_STATE="$live_ui_i18n_state" \
  LOCAL_REPO_DB_STATE="$local_repo_db_state" \
  LOCAL_REPO_PKG_STATE="$local_repo_pkg_state" \
  python - <<'PY'
import json
import os

checks = [
    {
        "key": "archinstall-runtime",
        "state": os.environ["ARCHINSTALL_STATE"],
        "required": True,
        "title": "Guided TUI backend",
        "command": "seven installer install",
    },
    {
        "key": "calamares-runtime",
        "state": "OK" if os.environ["CALAMARES_STATE"] == "OK" or os.environ["CALAMARES_SOURCE_STATE"] == "iso-runtime-ready" else os.environ["CALAMARES_STATE"],
        "required": False,
        "title": "Graphical installer runtime",
        "command": "seven installer iso-runtime",
        "reason": "Install calamares on the host or provide it through the archiso local package repository.",
    },
    {
        "key": "calamares-iso-runtime",
        "state": "OK" if os.environ["CALAMARES_SOURCE_STATE"] in {"installed", "iso-runtime-ready", "official-candidate"} else "MISS",
        "required": False,
        "title": "Calamares ISO package route",
        "command": "seven installer iso-runtime --json",
        "reason": f"ISO runtime source state: {os.environ['CALAMARES_SOURCE_STATE']}.",
    },
    {
        "key": "calamares-source-policy",
        "state": "OK" if os.environ["CALAMARES_SOURCE_STATE"] in {"installed", "iso-runtime-ready", "official-candidate", "aur-candidate", "source-declared"} else "MISS",
        "required": False,
        "title": "Calamares runtime source policy",
        "command": "seven installer runtime --json",
        "reason": f"Runtime source state: {os.environ['CALAMARES_SOURCE_STATE']}.",
    },
    {
        "key": "installer-planner",
        "state": os.environ["PLANNER_STATE"],
        "required": True,
        "title": "Non-destructive install planner",
        "command": "seven installer doctor",
    },
    {
        "key": "calamares-settings",
        "state": os.environ["CALAMARES_SETTINGS_STATE"],
        "required": True,
        "title": "Calamares module sequence",
        "command": "seven installer doctor",
    },
    {
        "key": "calamares-sevenos-module",
        "state": os.environ["CALAMARES_MODULE_STATE"],
        "required": True,
        "title": "SevenOS Calamares legacy module marker",
        "command": "seven installer doctor",
    },
    {
        "key": "calamares-shellprocess-module",
        "state": os.environ["CALAMARES_SHELLPROCESS_STATE"],
        "required": True,
        "title": "Calamares standard shellprocess hook",
        "command": "seven installer doctor",
        "reason": "SevenOS uses Calamares' built-in shellprocess module so the ISO does not depend on an unpackaged custom plugin.",
    },
    {
        "key": "calamares-postinstall",
        "state": os.environ["CALAMARES_POSTINSTALL_STATE"],
        "required": True,
        "title": "SevenOS base install hook",
        "command": "seven installer doctor",
    },
    {
        "key": "calamares-iso-config",
        "state": os.environ["CALAMARES_ISO_CONFIG_STATE"],
        "required": True,
        "title": "Calamares SevenOS config is installed in live ISO",
        "command": "./install.sh iso --dry-run",
    },
    {
        "key": "graphical-launcher",
        "state": os.environ["GRAPHICAL_LAUNCHER_STATE"],
        "required": True,
        "title": "SevenOS graphical installer launcher",
        "command": "seven installer graphical",
    },
    {
        "key": "native-installer-portal",
        "state": os.environ["NATIVE_LAUNCHER_STATE"],
        "required": True,
        "title": "Native SevenOS installer portal",
        "command": "seven-installer gui",
    },
    {
        "key": "native-installer-live-ui",
        "state": os.environ["NATIVE_LIVE_UI_STATE"],
        "required": True,
        "title": "Native installer consumes live status UI data",
        "command": "seven-installer gui",
    },
    {
        "key": "installer-portal",
        "state": os.environ["INSTALLER_PORTAL_STATE"],
        "required": True,
        "title": "SevenOS installer portal contract",
        "command": "seven-installer status --json",
    },
    {
        "key": "live-desktop-entry",
        "state": os.environ["LIVE_DESKTOP_STATE"],
        "required": True,
        "title": "Live ISO installer desktop entry",
        "command": "seven installer graphical",
    },
    {
        "key": "live-native-portal",
        "state": os.environ["LIVE_NATIVE_STATE"],
        "required": True,
        "title": "Live ISO native installer portal",
        "command": "seven-installer gui",
    },
    {
        "key": "calamares-branding",
        "state": os.environ["CALAMARES_BRANDING_STATE"],
        "required": True,
        "title": "SevenOS Calamares branding",
        "command": "seven installer graphical",
    },
    {
        "key": "archiso-profile",
        "state": os.environ["ARCHISO_STATE"],
        "required": True,
        "title": "Archiso live profile",
        "command": "seven installer doctor",
    },
    {
        "key": "iso-builder",
        "state": os.environ["BUILD_STATE"],
        "required": True,
        "title": "ISO build script",
        "command": "./install.sh iso --dry-run",
    },
    {
        "key": "iso-packages",
        "state": os.environ["PACKAGES_STATE"],
        "required": True,
        "title": "Live ISO package list",
        "command": "seven installer doctor",
    },
    {
        "key": "repo-injection",
        "state": os.environ["REPO_INJECTION_STATE"],
        "required": True,
        "title": "SevenOS repository injection",
        "command": "./install.sh iso --dry-run",
    },
    {
        "key": "local-calamares-package",
        "state": os.environ["LOCAL_REPO_PKG_STATE"],
        "required": True,
        "title": "Local Calamares package for ISO",
        "command": "seven installer iso-runtime --json",
    },
    {
        "key": "local-calamares-repo-db",
        "state": os.environ["LOCAL_REPO_DB_STATE"],
        "required": True,
        "title": "Local ISO repository database",
        "command": "seven installer iso-runtime --json",
    },
    {
        "key": "live-cli",
        "state": os.environ["LIVE_CLI_STATE"],
        "required": True,
        "title": "Live CLI bootstrap",
        "command": "seven installer doctor",
    },
    {
        "key": "live-sevenos-session",
        "state": os.environ["LIVE_SESSION_STATE"],
        "required": True,
        "title": "SevenOS Live Wayland session",
        "command": "./install.sh iso --dry-run",
    },
    {
        "key": "live-autologin",
        "state": os.environ["LIVE_AUTOLOGIN_STATE"],
        "required": True,
        "title": "Direct SevenOS Live autologin without a display-manager stop",
        "command": "./install.sh iso --dry-run",
    },
    {
        "key": "live-first-screen",
        "state": os.environ["LIVE_READY_STATE"],
        "required": True,
        "title": "Graphical first-screen installer portal",
        "command": "./install.sh iso --dry-run",
    },
    {
        "key": "live-tty-fallback",
        "state": os.environ["LIVE_TTY_FALLBACK_STATE"],
        "required": True,
        "title": "TTY fallback starts SevenOS session",
        "command": "./install.sh iso --dry-run",
    },
    {
        "key": "live-quiet-boot",
        "state": os.environ["LIVE_QUIET_BOOT_STATE"],
        "required": True,
        "title": "Live ISO uses quiet SevenOS boot plus a visible Safe Graphics route",
        "command": "./install.sh iso --dry-run",
    },
    {
        "key": "live-archiso-initramfs",
        "state": os.environ["LIVE_INITRAMFS_STATE"],
        "required": True,
        "title": "Live ISO initramfs uses archiso hooks instead of GPT auto-root",
        "command": "./install.sh iso --dry-run",
    },
    {
        "key": "live-user-config",
        "state": os.environ["LIVE_USER_CONFIG_STATE"],
        "required": True,
        "title": "SevenOS user configs preseeded",
        "command": "./install.sh iso --dry-run",
    },
    {
        "key": "live-network",
        "state": os.environ["LIVE_NETWORK_STATE"],
        "required": True,
        "title": "NetworkManager enabled in live ISO",
        "command": "./install.sh iso --dry-run",
    },
    {
        "key": "live-graphical-target",
        "state": os.environ["LIVE_GRAPHICAL_TARGET_STATE"],
        "required": True,
        "title": "Graphical target is default",
        "command": "./install.sh iso --dry-run",
    },
    {
        "key": "live-feedback",
        "state": os.environ["LIVE_FEEDBACK_STATE"],
        "required": True,
        "title": "Live session progress feedback",
        "command": "./install.sh iso --dry-run",
    },
    {
        "key": "live-session-services",
        "state": os.environ["LIVE_SERVICES_STATE"],
        "required": True,
        "title": "SevenOS session services start in live ISO",
        "command": "./install.sh iso --dry-run",
    },
    {
        "key": "live-user-dirs",
        "state": os.environ["LIVE_USER_DIRS_STATE"],
        "required": True,
        "title": "User folders are prepared in live ISO",
        "command": "./install.sh iso --dry-run",
    },
    {
        "key": "live-status-contract",
        "state": os.environ["LIVE_STATUS_STATE"],
        "required": True,
        "title": "Live installer status contract",
        "command": "seven-installer live-status --json",
    },
    {
        "key": "live-status-persistence",
        "state": os.environ["LIVE_STATUS_PERSIST_STATE"],
        "required": True,
        "title": "Live first-screen state persistence",
        "command": "seven-installer live-status --json",
    },
    {
        "key": "live-retry-command",
        "state": os.environ["LIVE_RETRY_STATE"],
        "required": True,
        "title": "Live installer retry command",
        "command": "seven-installer live-retry",
    },
    {
        "key": "live-singleton-lock",
        "state": os.environ["LIVE_LOCK_STATE"],
        "required": True,
        "title": "Live first-screen avoids duplicate launches",
        "command": "./install.sh iso --dry-run",
    },
    {
        "key": "live-installer-process-state",
        "state": os.environ["LIVE_PID_STATE"],
        "required": True,
        "title": "Live installer process state is tracked",
        "command": "seven-installer live-status --json",
    },
    {
        "key": "live-stale-lock-recovery",
        "state": os.environ["LIVE_LOCK_EXPIRY_STATE"],
        "required": True,
        "title": "Live first-screen recovers stale locks",
        "command": "./install.sh iso --dry-run",
    },
    {
        "key": "live-status-notification",
        "state": os.environ["LIVE_NOTIFY_STATUS_STATE"],
        "required": True,
        "title": "Live installer status is visible from desktop actions",
        "command": "seven-installer live-notify",
    },
    {
        "key": "live-progress-state",
        "state": os.environ["LIVE_PROGRESS_STATE"],
        "required": True,
        "title": "Live first-screen exposes progress",
        "command": "seven-installer live-status --json",
    },
    {
        "key": "live-recommended-action",
        "state": os.environ["LIVE_RECOMMENDED_STATE"],
        "required": True,
        "title": "Live first-screen exposes the next action",
        "command": "seven-installer live-status --json",
    },
    {
        "key": "live-desktop-i18n",
        "state": os.environ["LIVE_DESKTOP_I18N_STATE"],
        "required": True,
        "title": "Live installer desktop actions are localized",
        "command": "./install.sh iso --dry-run",
    },
    {
        "key": "live-network-status",
        "state": os.environ["LIVE_NETWORK_STATUS_STATE"],
        "required": True,
        "title": "Live first-screen exposes network readiness",
        "command": "seven-installer live-status --json",
    },
    {
        "key": "live-storage-status",
        "state": os.environ["LIVE_STORAGE_STATUS_STATE"],
        "required": True,
        "title": "Live first-screen exposes storage readiness",
        "command": "seven-installer live-status --json",
    },
    {
        "key": "live-system-status",
        "state": os.environ["LIVE_SYSTEM_STATUS_STATE"],
        "required": True,
        "title": "Live first-screen exposes power and memory readiness",
        "command": "seven-installer live-status --json",
    },
    {
        "key": "live-readiness-summary",
        "state": os.environ["LIVE_READINESS_SUMMARY_STATE"],
        "required": True,
        "title": "Live first-screen exposes a public readiness summary",
        "command": "seven-installer live-status --json",
    },
    {
        "key": "live-process-guard",
        "state": os.environ["LIVE_PROCESS_GUARD_STATE"],
        "required": True,
        "title": "Live first-screen detects installer windows that close too early",
        "command": "seven-installer live-retry",
    },
    {
        "key": "live-freshness",
        "state": os.environ["LIVE_FRESHNESS_STATE"],
        "required": True,
        "title": "Live first-screen exposes elapsed time and stale progress detection",
        "command": "seven-installer live-status --json",
    },
    {
        "key": "live-timeline",
        "state": os.environ["LIVE_TIMELINE_STATE"],
        "required": True,
        "title": "Live first-screen exposes a graphical startup timeline",
        "command": "seven-installer live-status --json",
    },
    {
        "key": "live-ui-i18n",
        "state": os.environ["LIVE_UI_I18N_STATE"],
        "required": True,
        "title": "Live first-screen exposes localized UI labels",
        "command": "seven-installer live-status --json",
    },
]

required = [item for item in checks if item["required"]]
required_ok = sum(1 for item in required if item["state"] == "OK")
optional_ok = sum(1 for item in checks if not item["required"] and item["state"] == "OK")
optional = [item for item in checks if not item["required"]]
score = round(((required_ok / max(len(required), 1)) * 85) + ((optional_ok / max(len(optional), 1)) * 15))
if score >= 95:
    state = "graphical-ready"
elif required_ok == len(required):
    state = "tui-release-ready"
elif score >= 70:
    state = "iso-foundation"
else:
    state = "foundation"

print(json.dumps({
    "schema": "sevenos.installer-release.v1",
    "state": state,
    "score": min(score, 100),
    "required_ready": required_ok,
    "required_total": len(required),
    "optional_ready": optional_ok,
    "optional_total": len(checks) - len(required),
    "calamares_runtime": os.environ["CALAMARES_SOURCE_STATE"],
    "checks": checks,
    "portal": "seven-installer status --json",
}, indent=2))
PY
}

status() {
  if [[ "$JSON_OUTPUT" -eq 1 && -x "$ROOT_DIR/bin/seven-daemon" ]]; then
    exec "$ROOT_DIR/bin/seven-daemon" installer --json
  fi

  local archinstall_state calamares_state planner_state profile_state archiso_state build_state packages_state
  archinstall_state="$(state archinstall)"
  calamares_state="$(state calamares)"
  planner_state="$([[ -x "$ROOT_DIR/installer/plan.sh" ]] && printf OK || printf MISS)"
  profile_state="$(dir_state installer/calamares)"
  archiso_state="$(dir_state archiso/profile)"
  build_state="$([[ -x "$ROOT_DIR/scripts/build-iso.sh" ]] && printf OK || printf MISS)"
  packages_state="$(file_state archiso/profile/packages.x86_64)"

  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    local release_payload
    release_payload="$(release_json)"
    printf '{'
    printf '"schema":"sevenos.installer.v1",'
    printf '"tooling":['
    printf '{"key":"archinstall","state":%s},' "$(printf '%s' "$archinstall_state" | json_string)"
    printf '{"key":"calamares","state":%s}' "$(printf '%s' "$calamares_state" | json_string)"
    printf '],'
    printf '"foundation":['
    printf '{"key":"planner","state":%s},' "$(printf '%s' "$planner_state" | json_string)"
    printf '{"key":"calamares-profile","state":%s},' "$(printf '%s' "$profile_state" | json_string)"
    printf '{"key":"archiso-profile","state":%s},' "$(printf '%s' "$archiso_state" | json_string)"
    printf '{"key":"iso-builder","state":%s},' "$(printf '%s' "$build_state" | json_string)"
    printf '{"key":"iso-packages","state":%s}' "$(printf '%s' "$packages_state" | json_string)"
    printf '],'
    printf '"ready":%s,' "$([[ "$archinstall_state" == OK && "$planner_state" == OK && "$archiso_state" == OK && "$build_state" == OK ]] && printf true || printf false)"
    printf '"mode":%s,' "$(if [[ "$calamares_state" == OK ]]; then printf graphical | json_string; elif [[ "$archinstall_state" == OK ]]; then printf tui-ready | json_string; else printf foundation | json_string; fi)"
    printf '"consumer_path":%s,' "$(if [[ "$calamares_state" == OK ]]; then printf graphical-calamares | json_string; elif [[ "$archinstall_state" == OK ]]; then printf guided-tui | json_string; else printf planned | json_string; fi)"
    printf '"release":%s,' "$release_payload"
    printf '"commands":{"status":"seven installer status","plan":"seven installer plan","guide":"seven installer guide","doctor":"seven installer doctor"}'
    printf '}\n'
    return 0
  fi

  printf 'SevenOS Installer Stack\n'
  printf '=======================\n'
  printf 'archinstall: %s\n' "$archinstall_state"
  printf 'calamares:   %s\n' "$calamares_state"
  printf 'planner:     %s\n' "$planner_state"
  printf 'profile:     %s\n' "$profile_state"
  printf 'archiso:     %s\n' "$archiso_state"
  printf 'iso builder: %s\n' "$build_state"
  printf 'consumer:    %s\n' "$(if [[ "$calamares_state" == OK ]]; then printf graphical-calamares; elif [[ "$archinstall_state" == OK ]]; then printf guided-tui; else printf planned; fi)"
  printf 'release:     %s\n' "$(release_json | python -c 'import json,sys; print(json.load(sys.stdin)["state"])')"
}

release_status() {
  local release_payload
  release_payload="$(release_json)"
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    printf '%s\n' "$release_payload"
    return 0
  fi
  RELEASE_JSON="$release_payload" python - <<'PY'
import json
import os
import sys

data = json.loads(os.environ["RELEASE_JSON"])
print("SevenOS Installer Release Readiness")
print("====================================")
print(f"State:    {data.get('state')}")
print(f"Score:    {data.get('score')}%")
print(f"Required: {data.get('required_ready')}/{data.get('required_total')}")
print(f"Optional: {data.get('optional_ready')}/{data.get('optional_total')}")
print()
print(f"{'Check':<26} {'State':<5} {'Required'}")
print(f"{'-----':<26} {'-----':<5} {'--------'}")
for item in data.get("checks", []):
    print(f"{item.get('key',''):<26} {item.get('state',''):<5} {'yes' if item.get('required') else 'no'}")
    if item.get("state") != "OK":
        print(f"{'':<26} {'':<5} {item.get('command', '')}")
PY
}

install_stack() {
  install_package_file "$ROOT_DIR/scripts/packages-installer.txt"
}

graphical() {
  local release_payload
  release_payload="$(release_json)"
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    RELEASE_JSON="$release_payload" python - <<'PY'
import json
import os

data = json.loads(os.environ["RELEASE_JSON"])
keys = {
    "calamares-runtime",
    "calamares-settings",
    "calamares-sevenos-module",
    "calamares-shellprocess-module",
    "calamares-postinstall",
    "calamares-iso-config",
    "graphical-launcher",
    "live-desktop-entry",
    "calamares-branding",
}
checks = [item for item in data.get("checks", []) if item.get("key") in keys]
print(json.dumps({
    "schema": "sevenos.installer-graphical.v1",
    "state": "graphical-ready" if all(item.get("state") == "OK" for item in checks) else "graphical-profile-ready",
    "runtime": next((item.get("state") for item in checks if item.get("key") == "calamares-runtime"), "MISS"),
    "checks": checks,
    "command": "seven-installer",
}, indent=2))
PY
    return 0
  fi

  RELEASE_JSON="$release_payload" python - <<'PY'
import json
import os

data = json.loads(os.environ["RELEASE_JSON"])
keys = (
    "calamares-runtime",
    "calamares-settings",
    "calamares-sevenos-module",
    "calamares-shellprocess-module",
    "calamares-postinstall",
    "calamares-iso-config",
    "graphical-launcher",
    "live-desktop-entry",
    "calamares-branding",
)
checks = [item for item in data.get("checks", []) if item.get("key") in keys]
runtime = next((item for item in checks if item.get("key") == "calamares-runtime"), {})
profile_ok = all(item.get("state") == "OK" for item in checks if item.get("key") != "calamares-runtime")
print("SevenOS Graphical Installer Route")
print("=================================")
print(f"State: {'graphical-ready' if profile_ok and runtime.get('state') == 'OK' else 'graphical-profile-ready'}")
print(f"Calamares runtime: {runtime.get('state', 'MISS')}")
if runtime.get("state") != "OK":
    print("Runtime note: Calamares is not in every official Arch repository. SevenOS ships the profile, launcher and branding; the ISO build host must provide the calamares package.")
print()
for item in checks:
    print(f"{item.get('state', 'MISS'):<5} {item.get('key', ''):<24} {item.get('title', '')}")
PY
}

runtime() {
  local payload
  payload="$(calamares_runtime_json)"
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    printf '%s\n' "$payload"
    return 0
  fi
  CALAMARES_RUNTIME_JSON="$payload" python - <<'PY'
import json
import os

data = json.loads(os.environ["CALAMARES_RUNTIME_JSON"])
sources = data.get("sources", {})
print("SevenOS Calamares Runtime")
print("=========================")
print(f"State: {data.get('state')}")
print(f"Installed: {str(data.get('installed')).lower()}")
print(f"Pacman candidate: {sources.get('pacman')}")
print(f"AUR manifest: {sources.get('aur_manifest')}")
print(f"yay: {sources.get('yay')} · paru: {sources.get('paru')}")
print()
for item in data.get("policy", []):
    print(f"- {item}")
PY
}

iso_runtime() {
  local runtime_args=()
  local item
  for item in "$@"; do
    case "$item" in
      --json|json) ;;
      *) runtime_args+=("$item") ;;
    esac
  done
  if [[ "${#runtime_args[@]}" -eq 0 ]]; then
    runtime_args=(status)
  fi
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    runtime_args+=(--json)
  fi
  exec "$ROOT_DIR/scripts/calamares-runtime.sh" "${runtime_args[@]}"
}

guide() {
  cat <<'EOF'
SevenOS install guide
=====================

Current user path:
  1. Start from the SevenOS live or test environment.
  2. Run `seven installer plan` to preview disk, user, locale, boot and profile choices.
  3. Run `seven installer doctor` before any destructive install step.
  4. Use Archinstall as the guided TUI backend today.
  5. Keep Calamares as the graphical installer target for public ISO builds.

Graphical path:
  - SevenOS already ships the Calamares profile, launcher, branding and live
    desktop entry.
  - The remaining runtime dependency is the `calamares` package on the ISO
    build host. Some Arch setups need an AUR/downstream Calamares package.
  - `seven installer graphical --json` exposes this as a product contract
    instead of hiding it behind a generic MISS.

Design rule:
  SevenOS must keep destructive disk operations behind explicit confirmation.
  Settings and Hub may show installer status, but they should not silently format
  disks or rewrite bootloaders.
EOF
}

doctor() {
  local failures=0
  local path

  status
  printf '\nFoundation files:\n'
  for path in \
    "installer/README.md" \
    "installer/plan.sh" \
    "installer/validate-plan.sh" \
    "installer/generate-script.sh" \
    "installer/calamares/settings.conf" \
    "installer/calamares/modules/shellprocess.conf" \
    "installer/calamares/modules/sevenos.conf" \
    "scripts/packages-installer.txt" \
    "scripts/packages-installer-aur.txt"; do
    if [[ -s "$ROOT_DIR/$path" ]]; then
      printf '[OK] %s\n' "$path"
    else
      printf '[MISS] %s\n' "$path"
      failures=$((failures + 1))
    fi
  done

  for path in \
    "bin/seven-installer" \
    "archiso/profile/airootfs/usr/share/applications/seven-installer.desktop" \
    "installer/calamares/branding/sevenos/branding.desc"; do
    if [[ -s "$ROOT_DIR/$path" ]]; then
      printf '[OK] %s\n' "$path"
    else
      printf '[MISS] %s\n' "$path"
      failures=$((failures + 1))
    fi
  done

  if [[ "$failures" -gt 0 ]]; then
    log_error "Installer stack has $failures issue(s)."
    return 1
  fi

  log_success "Installer stack foundation is coherent."
}

plan() {
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    if [[ -x "$ROOT_DIR/bin/seven-daemon" ]]; then
      exec "$ROOT_DIR/bin/seven-daemon" installer-plan --json
    fi
    INSTALLER_STATUS="$(JSON_OUTPUT=1 status)" python - <<'PY'
import json
import os

status = json.loads(os.environ["INSTALLER_STATUS"])
states = {item["key"]: item["state"] for item in status.get("tooling", []) + status.get("foundation", [])}
release = status.get("release", {})

metadata = {
    "archinstall": {
        "title": "Install Archinstall automation",
        "severity": "high",
        "impact": "packages",
        "phase": "automation",
        "command": "seven installer install",
        "reason": "Archinstall gives SevenOS an official automation backend before destructive disk flows are enabled.",
    },
    "calamares": {
        "title": "Package Calamares installer",
        "severity": "medium",
        "impact": "packages",
        "phase": "gui",
        "command": "seven installer plan",
        "reason": "Calamares is the graphical path for public ISO installation, but packaging remains a downstream step.",
    },
    "planner": {
        "title": "Restore installer planner",
        "severity": "critical",
        "impact": "changes",
        "phase": "planner",
        "command": "seven installer doctor",
        "reason": "SevenOS needs a non-destructive install plan before generating disk steps.",
    },
    "calamares-profile": {
        "title": "Restore Calamares profile",
        "severity": "high",
        "impact": "changes",
        "phase": "gui",
        "command": "seven installer doctor",
        "reason": "The graphical installer profile must travel with the ISO.",
    },
    "archiso-profile": {
        "title": "Restore Archiso profile",
        "severity": "critical",
        "impact": "changes",
        "phase": "iso",
        "command": "seven installer doctor",
        "reason": "SevenOS cannot produce a live ISO without an Archiso profile.",
    },
    "iso-builder": {
        "title": "Restore ISO build script",
        "severity": "critical",
        "impact": "changes",
        "phase": "iso",
        "command": "seven installer doctor",
        "reason": "The ISO builder is the bridge from repository to bootable SevenOS media.",
    },
    "iso-packages": {
        "title": "Restore ISO package list",
        "severity": "high",
        "impact": "changes",
        "phase": "iso",
        "command": "seven installer doctor",
        "reason": "The live image needs an explicit package set for repeatable builds.",
    },
    "graphical-launcher": {
        "title": "Restore graphical installer launcher",
        "severity": "high",
        "impact": "changes",
        "phase": "gui",
        "command": "seven installer graphical",
        "reason": "The live ISO needs a user-facing Install SevenOS entrypoint.",
    },
    "live-desktop-entry": {
        "title": "Restore live installer desktop entry",
        "severity": "high",
        "impact": "changes",
        "phase": "gui",
        "command": "seven installer graphical",
        "reason": "Normal users need a visible graphical installer launcher in the live session.",
    },
    "calamares-branding": {
        "title": "Restore SevenOS installer branding",
        "severity": "medium",
        "impact": "changes",
        "phase": "gui",
        "command": "seven installer graphical",
        "reason": "The graphical installer should identify itself as SevenOS instead of a generic Calamares flow.",
    },
}

rank = {"critical": 0, "high": 1, "medium": 2, "low": 3}
actions = []
for key, state in states.items():
    if state == "OK":
        continue
    item = metadata[key]
    actions.append({
        "key": key,
        "state": state,
        "title": item["title"],
        "severity": item["severity"],
        "impact": item["impact"],
        "phase": item["phase"],
        "reason": item["reason"],
        "command": item["command"],
    })

actions.append({
    "key": "dry-run-iso",
    "state": "READY",
    "title": "Validate ISO dry-run",
    "severity": "medium",
    "impact": "safe",
    "phase": "iso",
    "reason": "Before moving to a public ISO, SevenOS should prove the build path without touching the host.",
    "command": "./install.sh iso --dry-run",
})

for check in release.get("checks", []):
    if check.get("state") == "OK":
        continue
    if check.get("key") in states:
        continue
    if check.get("key") == "calamares-runtime" and "calamares" in states:
        continue
    actions.append({
        "key": check.get("key", "release-check"),
        "state": check.get("state", "MISS"),
        "title": check.get("title", "Resolve installer release check"),
        "severity": "high" if check.get("required") else "medium",
        "impact": "safe" if check.get("command", "").endswith("--dry-run") else "changes",
        "phase": "release",
        "reason": "Public ISO readiness requires this installer release check to pass.",
        "command": check.get("command", "seven installer release"),
    })

actions.sort(key=lambda item: (rank.get(item["severity"], 9), item["phase"], item["key"]))

print(json.dumps({
    "schema": "sevenos.installer-plan.v1",
    "mode": status.get("mode", "foundation"),
    "ready": bool(status.get("ready")),
    "release": release,
    "summary": {
        "total": len(actions),
        "critical": sum(1 for item in actions if item["severity"] == "critical"),
        "high": sum(1 for item in actions if item["severity"] == "high"),
        "medium": sum(1 for item in actions if item["severity"] == "medium"),
    },
    "next": actions,
}, indent=2))
PY
    return 0
  fi

  cat <<'EOF'
SevenOS installer direction
===========================

Primary path:
  1. Use Calamares for the graphical installer experience.
  2. Use the existing SevenOS install plan as the source of truth.
  3. Use Archinstall only as a secondary/automation backend where useful.

Why:
  - Calamares unlocks non-technical users.
  - Archinstall gives an official Arch automation path.
  - SevenOS keeps destructive disk steps behind explicit confirmation.

Next engineering steps:
  - package or source Calamares for the live ISO
  - map installer/plan.sh fields to Calamares modules
  - add a SevenOS post-install module that runs /opt/SevenOS/install.sh base
  - keep a dry-run installer script for development safety
EOF
}

action="${1:-status}"
shift || true
PASSTHROUGH_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --json|json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *)
      if [[ "$action" == "iso-runtime" || "$action" == "calamares-iso" || "$action" == "experience" || "$action" == "modern" || "$action" == "hardware" || "$action" == "profiles" || "$action" == "post-install" ]]; then
        PASSTHROUGH_ARGS+=("$arg")
      else
        log_error "Unknown installer option: $arg"; usage; exit 1
      fi
      ;;
  esac
done
case "$action" in
  status) status ;;
  install) install_stack ;;
  doctor) doctor ;;
  plan) plan ;;
  guide) guide ;;
  release) release_status ;;
  graphical) graphical ;;
  runtime|calamares) runtime ;;
  iso-runtime|calamares-iso) iso_runtime "${PASSTHROUGH_ARGS[@]}" ;;
  experience|modern|hardware|profiles|post-install)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      "$ROOT_DIR/scripts/installer-experience.sh" "${PASSTHROUGH_ARGS[@]}" --json
    else
      "$ROOT_DIR/scripts/installer-experience.sh" "${PASSTHROUGH_ARGS[@]}"
    fi
    ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown installer stack action: $action"; usage; exit 1 ;;
esac
