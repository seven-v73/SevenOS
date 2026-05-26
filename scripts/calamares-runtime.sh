#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="${1:-status}"
shift || true

JSON_OUTPUT=0
BUILD=0
YES=0

usage() {
  cat <<'EOF'
SevenOS Calamares ISO runtime

Usage:
  ./scripts/calamares-runtime.sh status [--json]
  ./scripts/calamares-runtime.sh plan [--json]
  ./scripts/calamares-runtime.sh deps [--dry-run] [--yes]
  ./scripts/calamares-runtime.sh build-local-repo [--dry-run] [--yes]

This helper prepares the missing graphical installer runtime for public ISO
builds. SevenOS ships the Calamares profile in-repo; this command prepares the
package source that the archiso profile can consume.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --json|json) JSON_OUTPUT=1 ;;
    --dry-run) export SEVENOS_DRY_RUN=1 ;;
    --yes) YES=1; export SEVENOS_YES=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown Calamares runtime option: $arg"; usage; exit 1 ;;
  esac
done

ARCHISO_PACKAGES="$ROOT_DIR/archiso/profile/packages.x86_64"
ARCHISO_PACMAN="$ROOT_DIR/archiso/profile/pacman.conf"
LOCAL_REPO_DIR="${SEVENOS_CALAMARES_REPO:-$ROOT_DIR/archiso/localrepo/x86_64}"
LOCAL_REPO_DB="$LOCAL_REPO_DIR/sevenos-local.db.tar.gz"
BUILD_DIR="${SEVENOS_CALAMARES_BUILD:-$ROOT_DIR/out/calamares-aur}"
AUR_URL="${SEVENOS_CALAMARES_AUR_URL:-https://aur.archlinux.org/calamares.git}"
CALAMARES_BUILD_DEPS=(
  kcoreaddons
  kpmcore
  libpwquality
  qt6-declarative
  qt6-svg
  yaml-cpp
  extra-cmake-modules
  libglvnd
  ninja
  qt6-tools
  qt6-translations
)

state_command() {
  command -v "$1" >/dev/null 2>&1 && printf OK || printf MISS
}

file_contains() {
  local path="$1"
  local pattern="$2"
  [[ -s "$path" ]] && grep -Fxq "$pattern" "$path" && printf OK || printf MISS
}

repo_has_package() {
  compgen -G "$LOCAL_REPO_DIR/calamares-*.pkg.tar.*" >/dev/null 2>&1 && printf OK || printf MISS
}

repo_db_state() {
  [[ -s "$LOCAL_REPO_DB" ]] && printf OK || printf MISS
}

missing_build_deps() {
  local dep
  for dep in "${CALAMARES_BUILD_DEPS[@]}"; do
    pacman -Qq "$dep" >/dev/null 2>&1 || printf '%s\n' "$dep"
  done
}

status_json() {
  local calamares_cmd packages_state repo_pkg_state repo_db git_state makepkg_state repoadd_state pacman_candidate missing_deps
  calamares_cmd="$(state_command calamares)"
  packages_state="$(file_contains "$ARCHISO_PACKAGES" calamares)"
  repo_pkg_state="$(repo_has_package)"
  repo_db="$(repo_db_state)"
  git_state="$(state_command git)"
  makepkg_state="$(state_command makepkg)"
  repoadd_state="$(state_command repo-add)"
  if timeout 4 pacman -Si calamares >/dev/null 2>&1; then
    pacman_candidate="OK"
  else
    pacman_candidate="MISS"
  fi
  missing_deps="$(missing_build_deps | paste -sd ' ' -)"

  CALAMARES_CMD="$calamares_cmd" PACKAGES_STATE="$packages_state" REPO_PKG_STATE="$repo_pkg_state" \
  REPO_DB_STATE="$repo_db" GIT_STATE="$git_state" MAKEPKG_STATE="$makepkg_state" REPOADD_STATE="$repoadd_state" \
  PACMAN_CANDIDATE="$pacman_candidate" LOCAL_REPO_DIR="$LOCAL_REPO_DIR" LOCAL_REPO_DB="$LOCAL_REPO_DB" \
  BUILD_DIR="$BUILD_DIR" AUR_URL="$AUR_URL" MISSING_DEPS="$missing_deps" python - <<'PY'
import json
import os

installed = os.environ["CALAMARES_CMD"] == "OK"
iso_declared = os.environ["PACKAGES_STATE"] == "OK"
repo_ready = os.environ["REPO_PKG_STATE"] == "OK" and os.environ["REPO_DB_STATE"] == "OK"
build_tools = all(os.environ[name] == "OK" for name in ("GIT_STATE", "MAKEPKG_STATE", "REPOADD_STATE"))
pacman_candidate = os.environ["PACMAN_CANDIDATE"] == "OK"
missing_deps = [item for item in os.environ.get("MISSING_DEPS", "").split() if item]

if installed:
    state = "runtime-installed"
elif iso_declared and (repo_ready or pacman_candidate):
    state = "iso-runtime-ready"
elif iso_declared and build_tools:
    state = "iso-source-ready"
elif iso_declared:
    state = "iso-declared"
else:
    state = "missing"

print(json.dumps({
    "schema": "sevenos.calamares-iso-runtime.v1",
    "state": state,
    "installed": installed,
    "iso_declared": iso_declared,
    "pacman_candidate": pacman_candidate,
    "local_repo_ready": repo_ready,
    "local_repo": {
        "path": os.environ["LOCAL_REPO_DIR"],
        "database": os.environ["LOCAL_REPO_DB"],
        "package": os.environ["REPO_PKG_STATE"],
        "database_state": os.environ["REPO_DB_STATE"],
    },
    "build_tools": {
        "git": os.environ["GIT_STATE"],
        "makepkg": os.environ["MAKEPKG_STATE"],
        "repo-add": os.environ["REPOADD_STATE"],
    },
    "build_dependencies": {
        "state": "OK" if not missing_deps else "MISS",
        "missing": missing_deps,
        "command": "seven installer iso-runtime deps --yes",
    },
    "source": {
        "aur_url": os.environ["AUR_URL"],
        "build_dir": os.environ["BUILD_DIR"],
    },
    "commands": {
        "status": "seven installer iso-runtime --json",
        "build_local_repo": "seven installer iso-runtime build-local-repo --yes",
        "install_build_dependencies": "seven installer iso-runtime deps --yes",
        "dry_run": "seven installer iso-runtime build-local-repo --dry-run",
        "iso_build": "./install.sh iso --dry-run",
    },
}, indent=2))
PY
}

plan_json() {
  local payload
  payload="$(status_json)"
  STATUS_JSON="$payload" python - <<'PY'
import json
import os

data = json.loads(os.environ["STATUS_JSON"])
actions = []
if not data.get("iso_declared"):
    actions.append({
        "key": "declare-iso-package",
        "state": "PENDING",
        "title": "Declare calamares in the live ISO package list",
        "command": "edit archiso/profile/packages.x86_64",
    })
if not data.get("local_repo_ready") and not data.get("pacman_candidate"):
    deps = data.get("build_dependencies", {})
    if deps.get("missing"):
        actions.append({
            "key": "install-build-deps",
            "state": "PENDING",
            "title": "Install Calamares build dependencies",
            "command": deps.get("command", "seven installer iso-runtime deps --yes"),
        })
    actions.append({
        "key": "build-local-repo",
        "state": "PENDING",
        "title": "Build a local Calamares package repository for archiso",
        "command": "seven installer iso-runtime build-local-repo --yes",
    })
actions.append({
    "key": "validate-iso",
    "state": "READY",
    "title": "Validate the ISO build route",
    "command": "./install.sh iso --dry-run",
})
actions.append({
    "key": "release-doctor",
    "state": "READY",
    "title": "Re-run public release gates",
    "command": "seven release doctor --json",
})
print(json.dumps({
    "schema": "sevenos.calamares-iso-runtime-plan.v1",
    "state": data.get("state"),
    "actions": actions,
}, indent=2))
PY
}

print_status_human() {
  STATUS_JSON="$1" python - <<'PY'
import json
import os

data = json.loads(os.environ["STATUS_JSON"])
repo = data.get("local_repo", {})
tools = data.get("build_tools", {})
deps = data.get("build_dependencies", {})
print("SevenOS Calamares ISO Runtime")
print("=============================")
print(f"State:            {data.get('state')}")
print(f"Installed:        {str(data.get('installed')).lower()}")
print(f"ISO package list: {'OK' if data.get('iso_declared') else 'MISS'}")
print(f"Pacman candidate: {'OK' if data.get('pacman_candidate') else 'MISS'}")
print(f"Local repo:       {'OK' if data.get('local_repo_ready') else 'MISS'}")
print(f"Repo path:        {repo.get('path')}")
print(f"Tools:            git={tools.get('git')} makepkg={tools.get('makepkg')} repo-add={tools.get('repo-add')}")
missing = deps.get("missing") or []
if missing:
    print(f"Missing deps:     {' '.join(missing)}")
    print(f"Deps command:     {deps.get('command')}")
PY
}

install_deps() {
  local missing=()
  mapfile -t missing < <(missing_build_deps)
  if [[ "${#missing[@]}" -eq 0 ]]; then
    log_success "Calamares build dependencies are already installed."
    return 0
  fi
  if [[ "$YES" -ne 1 && ! is_dry_run ]]; then
    log_error "Installing Calamares build dependencies needs explicit consent."
    log_info "Preview: seven installer iso-runtime deps --dry-run"
    log_info "Apply:   seven installer iso-runtime deps --yes"
    log_info "Missing: ${missing[*]}"
    exit 1
  fi
  require_command pacman
  log_info "Installing Calamares build dependencies: ${missing[*]}"
  if assume_yes; then
    run_privileged_cmd pacman -S --needed --noconfirm "${missing[@]}"
  else
    run_privileged_cmd pacman -S --needed "${missing[@]}"
  fi
}

build_local_repo() {
  if [[ "$YES" -ne 1 && ! is_dry_run ]]; then
    log_error "Building the Calamares ISO repo needs explicit consent."
    log_info "Preview first: seven installer iso-runtime build-local-repo --dry-run"
    log_info "Apply:         seven installer iso-runtime build-local-repo --yes"
    exit 1
  fi

  require_command git
  require_command makepkg
  require_command repo-add
  local missing=()
  mapfile -t missing < <(missing_build_deps)
  if [[ "${#missing[@]}" -gt 0 && ! is_dry_run ]]; then
    log_error "Calamares build dependencies are missing: ${missing[*]}"
    log_info "Install them first: seven installer iso-runtime deps --yes"
    exit 1
  fi

  log_info "Preparing Calamares local repository for archiso."
  run_cmd mkdir -p "$BUILD_DIR" "$LOCAL_REPO_DIR"
  if [[ ! -d "$BUILD_DIR/calamares/.git" ]]; then
    run_cmd git clone "$AUR_URL" "$BUILD_DIR/calamares"
  else
    run_cmd git -C "$BUILD_DIR/calamares" pull --ff-only
  fi
  run_cmd bash -lc "cd $(printf '%q' "$BUILD_DIR/calamares") && makepkg -s --noconfirm"
  run_cmd bash -lc "cp $(printf '%q' "$BUILD_DIR/calamares")/calamares-*.pkg.tar.* $(printf '%q' "$LOCAL_REPO_DIR")/"
  run_cmd bash -lc "repo-add $(printf '%q' "$LOCAL_REPO_DB") $(printf '%q' "$LOCAL_REPO_DIR")/*.pkg.tar.*"
  if is_dry_run; then
    log_success "Calamares local repository preview complete."
  else
    log_success "Calamares local repository ready: $LOCAL_REPO_DIR"
  fi
}

case "$ACTION" in
  status|json)
    payload="$(status_json)"
    if [[ "$JSON_OUTPUT" -eq 1 || "$ACTION" == "json" ]]; then
      printf '%s\n' "$payload"
    else
      print_status_human "$payload"
    fi
    ;;
  plan)
    payload="$(plan_json)"
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      printf '%s\n' "$payload"
    else
      PLAN_JSON="$payload" python - <<'PY'
import json
import os
data = json.loads(os.environ["PLAN_JSON"])
print("SevenOS Calamares ISO Runtime Plan")
print("==================================")
for item in data.get("actions", []):
    print(f"- {item.get('state'):<8} {item.get('title')}")
    print(f"  {item.get('command')}")
PY
    fi
    ;;
  build-local-repo|build)
    build_local_repo
    ;;
  deps|dependencies)
    install_deps
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    log_error "Unknown Calamares runtime action: $ACTION"
    usage
    exit 1
    ;;
esac
