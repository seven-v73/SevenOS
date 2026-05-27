#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

THEME_SRC="$ROOT_DIR/branding/sddm/sevenos"
THEME_DST="/usr/share/sddm/themes/sevenos"
CONF_DIR="/etc/sddm.conf.d"
CONF_FILE="$CONF_DIR/10-sevenos-theme.conf"
GENERATED_CONF="${XDG_CACHE_HOME:-$HOME/.cache}/sevenos/sddm/theme.conf"

usage() {
  cat <<'EOF'
SevenOS login theme

Usage:
  seven login-theme status
  seven login-theme doctor
  seven login-theme apply [--yes]
  seven login-theme theme [--yes]

This installs the SevenOS SDDM login screen used after boot before Hyprland.
It keeps language dynamic through Qt locale and does not change users/passwords.
EOF
}

for option in "$@"; do
  case "$option" in
    --yes|-y) export SEVENOS_YES=1 ;;
    --dry-run) export SEVENOS_DRY_RUN=1 ;;
  esac
done

need_root_command() {
  if is_dry_run; then
    printf '%q' "$(privileged_backend_label)"
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    "$@"
  else
    if [[ -z "$(privileged_backend)" ]]; then
      log_error "Administrator permission is required, but no interactive password prompt is available."
      log_info "Open Seven Terminal and run:"
      log_info "  seven login-theme apply --yes"
      return 1
    fi
    run_privileged_cmd "$@"
  fi
}

active_profile_key() {
  local key="${SEVENOS_ACTIVE_PROFILE:-${SEVENOS_PROFILE:-}}"
  if [[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/sevenos/profile.env" ]]; then
    key="${key:-$(awk -F= '/^SEVENOS_ACTIVE_PROFILE=/{gsub(/["\047]/, "", $2); print tolower($2); exit}' "${XDG_CONFIG_HOME:-$HOME/.config}/sevenos/profile.env" 2>/dev/null || true)}"
  fi
  if [[ -z "$key" && -r "${XDG_CONFIG_HOME:-$HOME/.config}/sevenos/profile-ui.json" ]]; then
    key="$(python - "${XDG_CONFIG_HOME:-$HOME/.config}/sevenos/profile-ui.json" <<'PY' 2>/dev/null || true
import json, sys
from pathlib import Path
data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
print(str(data.get("profile") or "").lower())
PY
)"
  fi
  case "$key" in
    equinox|baobab|forge|shield|studio|windows|pulse) printf '%s\n' "$key" ;;
    *) printf 'equinox\n' ;;
  esac
}

active_profile_title() {
  local key="${1:-$(active_profile_key)}"
  local title=""
  if [[ -z "${SEVENOS_ACTIVE_PROFILE:-${SEVENOS_PROFILE:-}}" && -r "${XDG_CONFIG_HOME:-$HOME/.config}/sevenos/profile.env" ]]; then
    title="$(awk -F= '/^SEVENOS_PROFILE_TITLE=/{gsub(/["\047]/, "", $2); print $2; exit}' "${XDG_CONFIG_HOME:-$HOME/.config}/sevenos/profile.env" 2>/dev/null || true)"
  fi
  if [[ -z "${SEVENOS_ACTIVE_PROFILE:-${SEVENOS_PROFILE:-}}" && -z "$title" && -r "${XDG_CONFIG_HOME:-$HOME/.config}/sevenos/profile-ui.json" ]]; then
    title="$(python - "${XDG_CONFIG_HOME:-$HOME/.config}/sevenos/profile-ui.json" <<'PY' 2>/dev/null || true
import json, sys
from pathlib import Path
data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
print(str(data.get("title") or ""))
PY
)"
  fi
  if [[ -z "$title" && -r "$ROOT_DIR/identity/profile-themes.json" ]]; then
    title="$(python - "$ROOT_DIR/identity/profile-themes.json" "$key" <<'PY' 2>/dev/null || true
import json, sys
from pathlib import Path
data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
key = sys.argv[2]
print(str(data.get("profiles", {}).get(key, {}).get("label") or ""))
PY
)"
  fi
  printf '%s\n' "${title:-Equinox Balance}"
}

active_profile_color() {
  local key="${3:-$(active_profile_key)}"
  local field="$1"
  local fallback="$2"
  local value=""
  if [[ -z "${SEVENOS_ACTIVE_PROFILE:-${SEVENOS_PROFILE:-}}" && -r "${XDG_CONFIG_HOME:-$HOME/.config}/sevenos/profile.env" ]]; then
    case "$field" in
      accent)
        value="$(awk -F= '/^SEVENOS_PROFILE_ACCENT_COLOR=/{gsub(/["\047]/, "", $2); print $2; exit}' "${XDG_CONFIG_HOME:-$HOME/.config}/sevenos/profile.env" 2>/dev/null || true)"
        ;;
      secondary)
        value="$(awk -F= '/^SEVENOS_PROFILE_SECONDARY_COLOR=/{gsub(/["\047]/, "", $2); print $2; exit}' "${XDG_CONFIG_HOME:-$HOME/.config}/sevenos/profile.env" 2>/dev/null || true)"
        ;;
    esac
  fi
  if [[ -z "${SEVENOS_ACTIVE_PROFILE:-${SEVENOS_PROFILE:-}}" && -z "$value" && -r "${XDG_CONFIG_HOME:-$HOME/.config}/sevenos/profile-ui.json" ]]; then
    value="$(python - "${XDG_CONFIG_HOME:-$HOME/.config}/sevenos/profile-ui.json" "$field" <<'PY' 2>/dev/null || true
import json, sys
from pathlib import Path
data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
field = sys.argv[2]
print(str(data.get("accent" if field == "accent" else "secondary") or ""))
PY
)"
  fi
  if [[ -z "$value" && -r "$ROOT_DIR/identity/profile-themes.json" ]]; then
    value="$(python - "$ROOT_DIR/identity/profile-themes.json" "$key" "$field" <<'PY' 2>/dev/null || true
import json, sys
from pathlib import Path
data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
profile = data.get("profiles", {}).get(sys.argv[2], {})
print(str(profile.get("accent" if sys.argv[3] == "accent" else "secondary") or ""))
PY
)"
  fi
  if [[ "$value" =~ ^#[0-9A-Fa-f]{6}$ ]]; then
    printf '%s\n' "$value"
  else
    printf '%s\n' "$fallback"
  fi
}

generate_theme_config() {
  local profile_title="${1:-$(active_profile_title)}"
  local accent="${2:-$(active_profile_color accent '#8B7CFF')}"
  local secondary="${3:-$(active_profile_color secondary '#5AB8FF')}"
  mkdir -p "$(dirname "$GENERATED_CONF")"
  python - "$THEME_SRC/theme.conf" "$GENERATED_CONF" "$profile_title" "$accent" "$secondary" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1])
target = Path(sys.argv[2])
profile_title = sys.argv[3]
accent = sys.argv[4]
secondary = sys.argv[5]
lines = source.read_text(encoding="utf-8").splitlines()
out = []
seen_title = False
seen_accent = False
seen_secondary = False
for line in lines:
    if line.startswith("miniOsTitle="):
        out.append(f"miniOsTitle={profile_title}")
        seen_title = True
    elif line.startswith("accent="):
        out.append(f"accent={accent}")
        seen_accent = True
    elif line.startswith("accent2="):
        out.append(f"accent2={secondary}")
        seen_secondary = True
    else:
        out.append(line)
if not seen_title:
    out.append(f"miniOsTitle={profile_title}")
if not seen_accent:
    out.append(f"accent={accent}")
if not seen_secondary:
    out.append(f"accent2={secondary}")
target.write_text("\n".join(out).rstrip() + "\n", encoding="utf-8")
PY
  printf '%s\n' "$GENERATED_CONF"
}

install_theme() {
  [[ -d "$THEME_SRC" ]] || { log_error "Missing SDDM theme source: $THEME_SRC"; return 1; }
  local generated_conf profile_title accent secondary
  local profile_key
  profile_key="$(active_profile_key)"
  profile_title="$(active_profile_title "$profile_key")"
  accent="$(active_profile_color accent '#8B7CFF' "$profile_key")"
  secondary="$(active_profile_color secondary '#5AB8FF' "$profile_key")"
  generated_conf="$(generate_theme_config "$profile_title" "$accent" "$secondary")"
  log_info "Installing SevenOS SDDM login theme"
  log_info "Login Mini OS: $profile_title"
  log_info "Login accent: $accent / $secondary"
  need_root_command install -d "$THEME_DST/assets"
  need_root_command install -m 0644 "$THEME_SRC/Main.qml" "$THEME_DST/Main.qml"
  need_root_command install -m 0644 "$generated_conf" "$THEME_DST/theme.conf"
  need_root_command install -m 0644 "$THEME_SRC/metadata.desktop" "$THEME_DST/metadata.desktop"
  need_root_command install -m 0644 "$THEME_SRC/assets/seven-prism.png" "$THEME_DST/assets/seven-prism.png"
}

write_sddm_config() {
  log_info "Selecting SevenOS as the SDDM greeter theme"
  if is_dry_run; then
    printf '%q install -d %q\n' "$(privileged_backend_label)" "$CONF_DIR"
    printf '%q write %q with Current=sevenos\n' "$(privileged_backend_label)" "$CONF_FILE"
    return 0
  fi
  need_root_command install -d "$CONF_DIR"
  [[ -f "$CONF_FILE" ]] && need_root_command cp "$CONF_FILE" "$(backup_path "$CONF_FILE")"
  need_root_command python - "$CONF_FILE" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
path.write_text(
    "[Theme]\n"
    "Current=sevenos\n"
    "\n"
    "[General]\n"
    "DisplayServer=x11\n",
    encoding="utf-8",
)
PY
}

status() {
  printf 'SevenOS Login Theme\n'
  printf 'Theme source: %s\n' "$([[ -d "$THEME_SRC" ]] && printf OK || printf MISS)"
  printf 'Theme asset:  %s\n' "$([[ -s "$THEME_SRC/assets/seven-prism.png" ]] && printf OK || printf MISS)"
  local profile_key
  profile_key="$(active_profile_key)"
  printf 'Mini OS:      %s\n' "$(active_profile_title "$profile_key")"
  printf 'Accent:       %s / %s\n' "$(active_profile_color accent '#8B7CFF' "$profile_key")" "$(active_profile_color secondary '#5AB8FF' "$profile_key")"
  printf 'SDDM:         %s\n' "$(command -v sddm >/dev/null 2>&1 && printf OK || printf MISS)"
  printf 'Installed:    %s\n' "$([[ -s "$THEME_DST/Main.qml" ]] && printf OK || printf MISS)"
  printf 'Active theme: '
  if [[ -r "$CONF_FILE" ]]; then
    awk -F= '/^Current=/{print $2; found=1} END{if(!found) print "unknown"}' "$CONF_FILE"
  else
    printf 'unknown\n'
  fi
  printf 'Config file:  %s\n' "$CONF_FILE"
}

doctor_check_file() {
  local label="$1"
  local path="$2"
  if [[ -s "$path" ]]; then
    printf '[OK] %s\n' "$label"
    return 0
  fi
  printf '[FAIL] %s: missing %s\n' "$label" "$path" >&2
  return 1
}

doctor_check_text() {
  local label="$1"
  local pattern="$2"
  local path="$3"
  if grep -q -- "$pattern" "$path" 2>/dev/null; then
    printf '[OK] %s\n' "$label"
    return 0
  fi
  printf '[FAIL] %s: expected %s in %s\n' "$label" "$pattern" "$path" >&2
  return 1
}

doctor() {
  local failed=0
  printf 'SevenOS Login Theme Doctor\n'
  doctor_check_file "SDDM theme QML" "$THEME_SRC/Main.qml" || failed=1
  doctor_check_file "SDDM theme metadata" "$THEME_SRC/metadata.desktop" || failed=1
  doctor_check_file "SDDM theme config" "$THEME_SRC/theme.conf" || failed=1
  doctor_check_file "Seven Prism login asset" "$THEME_SRC/assets/seven-prism.png" || failed=1
  doctor_check_text "Theme keeps SevenOS as login brand" 'SevenOS' "$THEME_SRC/Main.qml" || failed=1
  doctor_check_text "Theme exposes French login text" 'Connexion SevenOS' "$THEME_SRC/Main.qml" || failed=1
  doctor_check_text "Theme exposes English login text" 'SevenOS Sign In' "$THEME_SRC/Main.qml" || failed=1
  doctor_check_text "Theme uses Qt locale for language" 'Qt.locale' "$THEME_SRC/Main.qml" || failed=1
  doctor_check_text "Theme keeps Hyprland identity visible" 'Hyprland' "$THEME_SRC/Main.qml" || failed=1
  doctor_check_text "Theme uses Prism asset" 'seven-prism.png' "$THEME_SRC/Main.qml" || failed=1
  doctor_check_text "Theme exposes active Mini OS chip" 'miniOsTitle' "$THEME_SRC/Main.qml" || failed=1
  doctor_check_text "Theme styles login fields with profile accent" 'focusColor: accent2' "$THEME_SRC/Main.qml" || failed=1
  doctor_check_text "Theme avoids default white input fields" 'color: "#141B2D"' "$THEME_SRC/Main.qml" || failed=1
  doctor_check_text "Installer detects active profile key" 'active_profile_key' "$0" || failed=1
  doctor_check_text "Installer injects active profile colors" 'active_profile_color' "$0" || failed=1
  doctor_check_text "Installer generates active Mini OS config" 'generate_theme_config' "$0" || failed=1
  doctor_check_text "Installer selects sevenos theme" 'Current=sevenos' "$0" || failed=1

  if command -v qmllint >/dev/null 2>&1; then
    if qmllint -I /usr/lib/qt/qml -I /usr/lib/qt6/qml "$THEME_SRC/Main.qml" >/tmp/sevenos-login-qmllint.log 2>&1; then
      printf '[OK] QML lint accepts SevenOS login theme\n'
    else
      printf '[WARN] QML lint reported issues; inspect /tmp/sevenos-login-qmllint.log\n'
    fi
  else
    printf '[OK] qmllint not installed; static login theme checks passed\n'
  fi

  if command -v sddm >/dev/null 2>&1; then
    printf '[OK] SDDM is installed\n'
  else
    printf '[WARN] SDDM is not installed on this machine; install sddm before applying the login theme\n'
  fi

  if (( failed )); then
    return 1
  fi
  log_success "SevenOS login theme contract is complete"
}

apply() {
  install_theme
  write_sddm_config
  log_success "SevenOS login theme configured. Log out or reboot to see it."
}

action="${1:-status}"
shift || true
case "$action" in
  status) status ;;
  doctor) doctor ;;
  theme) install_theme ;;
  apply) apply ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown login-theme action: $action"; usage; exit 1 ;;
esac
