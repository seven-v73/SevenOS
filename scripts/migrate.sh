#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
MANIFEST="${SEVENOS_MANIFEST:-$ROOT_DIR/sevenos.dotinst}"
BACKUP_ROOT="${SEVENOS_MIGRATION_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/sevenos/migrations}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
Usage: seven migrate <command>

Commands:
  plan       Show protected user paths and whether they exist.
  backup     Copy existing protected paths into a timestamped migration backup.
  doctor     Validate manifest and migration prerequisites.

Environment:
  SEVENOS_MIGRATION_DIR  Override migration backup directory.
EOF
}

manifest_paths() {
  python - "$MANIFEST" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    manifest = json.load(handle)

seen = set()
for item in manifest.get("restore", []):
    path = item.get("target") or item.get("source")
    if path and path not in seen:
        seen.add(path)
        print(path)
for path in manifest.get("protected", []):
    if path and path not in seen:
        seen.add(path)
        print(path)
PY
}

expand_user_path() {
  local path="$1"
  case "$path" in
    "~") printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s/%s\n' "$HOME" "${path#~/}" ;;
    *) printf '%s\n' "$path" ;;
  esac
}

relative_backup_path() {
  local path="$1"
  path="${path#"$HOME"/}"
  path="${path#/}"
  printf '%s\n' "$path"
}

doctor() {
  "$ROOT_DIR/scripts/manifest.sh" doctor >/dev/null
  require_command python

  if [[ ! -r "$MANIFEST" ]]; then
    log_error "Manifest not readable: $MANIFEST"
    exit 1
  fi

  log_success "Migration prerequisites OK."
}

plan() {
  doctor >/dev/null
  printf 'SevenOS migration plan\n'
  printf 'Backup root: %s\n\n' "$BACKUP_ROOT"

  local path expanded state
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    expanded="$(expand_user_path "$path")"
    if [[ -e "$expanded" ]]; then
      state="present"
    else
      state="missing"
    fi
    printf '[%s] %s\n' "$state" "$path"
  done < <(manifest_paths)
}

backup() {
  doctor >/dev/null

  local stamp backup_dir path expanded relative target backed_up
  stamp="$(date +%Y%m%d-%H%M%S)"
  backup_dir="$BACKUP_ROOT/$stamp"
  backed_up=0

  log_info "Creating SevenOS migration backup: $backup_dir"

  if is_dry_run; then
    printf 'mkdir -p %q\n' "$backup_dir"
  else
    mkdir -p "$backup_dir"
  fi

  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    expanded="$(expand_user_path "$path")"
    if [[ ! -e "$expanded" ]]; then
      continue
    fi

    relative="$(relative_backup_path "$expanded")"
    target="$backup_dir/$relative"
    if is_dry_run; then
      printf 'mkdir -p %q\n' "$(dirname -- "$target")"
      printf 'cp -a %q %q\n' "$expanded" "$target"
    else
      mkdir -p "$(dirname -- "$target")"
      cp -a "$expanded" "$target"
    fi
    backed_up=$((backed_up + 1))
  done < <(manifest_paths)

  if [[ "$backed_up" -eq 0 ]]; then
    log_warn "No existing protected paths found to back up."
  else
    log_success "Protected paths backed up: $backed_up"
  fi
}

command="${1:-plan}"
case "$command" in
  plan)
    plan
    ;;
  backup)
    backup
    ;;
  doctor)
    doctor
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
