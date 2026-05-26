#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="status"
JSON_OUTPUT=0
TOOL=""
CATEGORY=""
YES=0

WORKSPACE="${SEVENOS_SHIELD_WORKSPACE:-$HOME/ShieldLab}"
STATE_DIR="$WORKSPACE/.sevenos"
TOOLCHAIN_FILE="$STATE_DIR/toolchain.json"
KALI_HOME="$WORKSPACE/KaliHome"
KALI_IMAGE="${SEVENOS_SHIELD_KALI_IMAGE:-docker.io/kalilinux/kali-rolling:latest}"
KALI_CONTAINER="${SEVENOS_SHIELD_KALI_CONTAINER:-seven-shield-kali}"

usage() {
  cat <<'EOF'
SevenOS Shield Toolchain

Usage:
  seven shield toolchain [--json]
  seven shield toolchain sources [--json]
  seven shield toolchain search <tool> [--json]
  seven shield toolchain install <tool> [--yes]
  seven shield toolchain blackarch-setup --yes
  seven shield toolchain blackarch-full --yes
  seven shield toolchain blackarch-category <category> [--yes]
  seven shield toolchain kali-prepare [--yes]
  seven shield toolchain kali-warmup [--yes]
  seven shield toolchain kali-run [command...]

Shield Toolchain keeps the stable Arch base clean while offering compatibility
with AUR, optional BlackArch categories and an isolated Kali Rolling container.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    status|toolchain) ACTION="status" ;;
    sources|search|install|blackarch-setup|blackarch-full|blackarch-category|kali-prepare|kali-warmup|kali-run)
      ACTION="$1"
      ;;
    --json|json) JSON_OUTPUT=1 ;;
    --dry-run) export SEVENOS_DRY_RUN=1 ;;
    --yes|-y) YES=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *)
      case "$ACTION" in
        search|install) [[ -z "$TOOL" ]] && TOOL="$1" || TOOL="$TOOL $1" ;;
        blackarch-category) [[ -z "$CATEGORY" ]] && CATEGORY="$1" || { log_error "Only one BlackArch category is supported."; exit 1; } ;;
        kali-run) TOOL="${TOOL:+$TOOL }$1" ;;
        *) log_error "Unknown Shield toolchain option: $1"; usage; exit 1 ;;
      esac
      ;;
  esac
  shift
done

command_state() {
  local name="$1"
  command -v "$name" >/dev/null 2>&1 && printf OK || printf MISS
}

repo_state() {
  pacman-conf --repo-list 2>/dev/null | grep -qx 'blackarch' && printf OK || printf MISS
}

container_runtime() {
  if command -v podman >/dev/null 2>&1; then
    printf podman
  elif command -v docker >/dev/null 2>&1; then
    printf docker
  else
    printf ''
  fi
}

official_package_state() {
  local package="$1"
  pacman -Si "$package" >/dev/null 2>&1 && printf OK || printf MISS
}

aur_package_state() {
  local package="$1"
  if command -v yay >/dev/null 2>&1 && yay -Si "$package" >/dev/null 2>&1; then
    printf OK
  elif command -v paru >/dev/null 2>&1 && paru -Si "$package" >/dev/null 2>&1; then
    printf OK
  else
    printf MISS
  fi
}

blackarch_package_state() {
  local package="$1"
  if [[ "$(repo_state)" != OK ]]; then
    printf DISABLED
  elif pacman -Si "$package" >/dev/null 2>&1; then
    printf OK
  else
    printf MISS
  fi
}

status_json() {
  local runtime
  runtime="$(container_runtime)"
  mkdir -p "$STATE_DIR"
  SHIELD_RUNTIME="$runtime" SHIELD_KALI_IMAGE="$KALI_IMAGE" SHIELD_KALI_CONTAINER="$KALI_CONTAINER" \
  SHIELD_KALI_HOME="$KALI_HOME" BLACKARCH_REPO="$(repo_state)" YAY_STATE="$(command_state yay)" PARU_STATE="$(command_state paru)" \
  PODMAN_STATE="$(command_state podman)" DOCKER_STATE="$(command_state docker)" python - <<'PY'
import json
import os

runtime = os.environ["SHIELD_RUNTIME"]
sources = [
    {
        "key": "arch",
        "title": "Arch official repositories",
        "state": "OK",
        "role": "stable baseline",
        "install": "seven store install-app pacman <tool>",
    },
    {
        "key": "aur",
        "title": "AUR advanced tools",
        "state": "OK" if os.environ["YAY_STATE"] == "OK" or os.environ["PARU_STATE"] == "OK" else "MISS",
        "role": "reviewed large or specialist tools",
        "install": "seven store install-app aur <tool>",
    },
    {
        "key": "blackarch",
        "title": "BlackArch optional repository",
        "state": os.environ["BLACKARCH_REPO"],
        "role": "huge Arch-native security catalog",
        "install": "seven shield toolchain blackarch-setup --yes",
        "install_full": "seven shield toolchain blackarch-full --yes",
    },
    {
        "key": "kali-container",
        "title": "Kali Rolling isolated container",
        "state": "OK" if runtime else "MISS",
        "role": "maximum Kali compatibility without changing host packages",
        "install": "seven shield toolchain kali-prepare --yes",
    },
]
missing = [item for item in sources if item["state"] not in ("OK",)]
payload = {
    "schema": "sevenos.shield-toolchain.v1",
    "state": "OK" if len(missing) <= 1 else "PART",
    "sources": sources,
    "runtime": runtime or None,
    "kali": {
        "image": os.environ["SHIELD_KALI_IMAGE"],
        "container": os.environ["SHIELD_KALI_CONTAINER"],
        "home": os.environ["SHIELD_KALI_HOME"],
        "command": "seven shield toolchain kali-run",
    },
    "policy": [
        "official Arch packages first",
        "AUR tools require user review",
        "BlackArch repository is opt-in",
        "Kali compatibility runs isolated through container runtime",
        "authorized scope is still required for intrusive workflows",
    ],
}
print(json.dumps(payload, indent=2))
PY
}

status_human() {
  status_json | python -c 'import json,sys
data=json.load(sys.stdin)
print("SevenOS Shield Toolchain")
print("========================")
print("State: {}".format(data.get("state")))
print("Runtime: {}".format(data.get("runtime") or "none"))
print()
for item in data.get("sources", []):
    print("  {state:<8} {key:<16} {title}".format(**item))
print()
print("Kali: {}".format(data.get("kali", {}).get("command")))
print("BlackArch setup: seven shield toolchain blackarch-setup --yes")
print("BlackArch full:  seven shield toolchain blackarch-full --yes")'
}

sources_json() {
  status_json | python -c 'import json,sys; data=json.load(sys.stdin); print(json.dumps({"schema":"sevenos.shield-toolchain-sources.v1","sources":data["sources"],"policy":data["policy"]}, indent=2))'
}

search_tool() {
  [[ -n "$TOOL" ]] || { log_error "Missing tool name."; exit 1; }
  local official aur blackarch installed
  command -v "$TOOL" >/dev/null 2>&1 && installed=OK || installed=MISS
  official="$(official_package_state "$TOOL")"
  aur="$(aur_package_state "$TOOL")"
  blackarch="$(blackarch_package_state "$TOOL")"
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    TOOL="$TOOL" INSTALLED="$installed" OFFICIAL="$official" AUR="$aur" BLACKARCH="$blackarch" python - <<'PY'
import json
import os
tool = os.environ["TOOL"]
sources = [
    {"source": "installed", "state": os.environ["INSTALLED"], "command": tool},
    {"source": "pacman", "state": os.environ["OFFICIAL"], "command": f"seven store install-app pacman {tool}"},
    {"source": "aur", "state": os.environ["AUR"], "command": f"seven store install-app aur {tool}"},
    {"source": "blackarch", "state": os.environ["BLACKARCH"], "command": f"seven shield toolchain install {tool} --yes"},
    {"source": "kali-container", "state": "AVAILABLE", "command": f"seven shield toolchain kali-run {tool} --help"},
]
print(json.dumps({"schema":"sevenos.shield-tool-search.v1","tool":tool,"sources":sources}, indent=2))
PY
  else
    printf 'SevenOS Shield Tool Search: %s\n' "$TOOL"
    printf '  installed      %s\n' "$installed"
    printf '  pacman         %s\n' "$official"
    printf '  aur            %s\n' "$aur"
    printf '  blackarch      %s\n' "$blackarch"
    printf '  kali-container AVAILABLE\n'
  fi
}

install_tool() {
  [[ -n "$TOOL" ]] || { log_error "Missing tool name."; exit 1; }
  [[ "$YES" -eq 1 || "${SEVENOS_YES:-0}" == "1" ]] || {
    log_error "Toolchain installs require explicit consent."
    log_info "Run: seven shield toolchain install $TOOL --yes"
    exit 1
  }

  if [[ "$(official_package_state "$TOOL")" == OK ]]; then
    "$ROOT_DIR/scripts/store.sh" install-app pacman "$TOOL"
  elif [[ "$(aur_package_state "$TOOL")" == OK ]]; then
    "$ROOT_DIR/scripts/store.sh" install-app aur "$TOOL"
  elif [[ "$(blackarch_package_state "$TOOL")" == OK ]]; then
    "$ROOT_DIR/security/blackarch.sh" tool "$TOOL"
  else
    log_warn "Tool was not found locally in pacman/AUR/BlackArch metadata."
    log_info "Use Kali compatibility instead: seven shield toolchain kali-run $TOOL --help"
  fi
}

blackarch_setup() {
  [[ "$YES" -eq 1 || "${SEVENOS_YES:-0}" == "1" ]] || {
    log_error "BlackArch setup requires explicit consent."
    log_info "Preview first: ./install.sh blackarch-setup --dry-run"
    exit 1
  }
  "$ROOT_DIR/security/blackarch.sh" setup --yes
}

blackarch_category() {
  [[ -n "$CATEGORY" ]] || { log_error "Missing BlackArch category."; exit 1; }
  [[ "$YES" -eq 1 || "${SEVENOS_YES:-0}" == "1" ]] || {
    log_error "BlackArch category install requires explicit consent."
    log_info "Run: seven shield toolchain blackarch-category $CATEGORY --yes"
    exit 1
  }
  "$ROOT_DIR/security/blackarch.sh" category "$CATEGORY"
}

blackarch_full() {
  [[ "$YES" -eq 1 || "${SEVENOS_YES:-0}" == "1" || "${SEVENOS_DRY_RUN:-0}" == "1" ]] || {
    log_error "Full BlackArch install requires explicit consent."
    log_info "Preview first: seven shield toolchain blackarch-full --dry-run"
    log_info "Then run: seven shield toolchain blackarch-full --yes"
    exit 1
  }
  "$ROOT_DIR/security/blackarch.sh" full --yes
}

kali_prepare() {
  local runtime
  runtime="$(container_runtime)"
  [[ -n "$runtime" ]] || { log_error "Kali compatibility needs podman or docker."; exit 1; }
  [[ "$YES" -eq 1 || "${SEVENOS_YES:-0}" == "1" ]] || {
    log_error "Kali container preparation requires explicit consent."
    log_info "Run: seven shield toolchain kali-prepare --yes"
    exit 1
  }
  mkdir -p "$KALI_HOME"
  if [[ "$runtime" == podman ]]; then
    run_cmd podman pull "$KALI_IMAGE"
  else
    run_cmd docker pull "$KALI_IMAGE"
  fi
}

kali_image_ready() {
  local runtime
  runtime="$(container_runtime)"
  [[ -n "$runtime" ]] || return 1
  if [[ "$runtime" == podman ]]; then
    podman image exists "$KALI_IMAGE" >/dev/null 2>&1
  else
    docker image inspect "$KALI_IMAGE" >/dev/null 2>&1
  fi
}

kali_warmup() {
  if ! kali_image_ready; then
    kali_prepare
  fi
  log_success "Kali compatibility image is ready."
}

kali_run() {
  local runtime command_text
  runtime="$(container_runtime)"
  [[ -n "$runtime" ]] || { log_error "Kali compatibility needs podman or docker."; exit 1; }
  mkdir -p "$KALI_HOME"
  command_text="${TOOL:-bash}"
  if [[ "$runtime" == podman ]]; then
    exec podman run --rm -it \
      --name "$KALI_CONTAINER" \
      --hostname seven-shield-kali \
      --userns keep-id \
      -v "$KALI_HOME:/root:Z" \
      -v "$WORKSPACE:/ShieldLab:Z" \
      -w /ShieldLab \
      "$KALI_IMAGE" bash -lc "$command_text"
  fi
  exec docker run --rm -it \
    --name "$KALI_CONTAINER" \
    --hostname seven-shield-kali \
    -v "$KALI_HOME:/root" \
    -v "$WORKSPACE:/ShieldLab" \
    -w /ShieldLab \
    "$KALI_IMAGE" bash -lc "$command_text"
}

case "$ACTION" in
  status)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then status_json; else status_human; fi
    ;;
  sources)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then sources_json; else status_human; fi
    ;;
  search)
    search_tool
    ;;
  install)
    install_tool
    ;;
  blackarch-setup)
    blackarch_setup
    ;;
  blackarch-full)
    blackarch_full
    ;;
  blackarch-category)
    blackarch_category
    ;;
  kali-prepare)
    kali_prepare
    ;;
  kali-warmup)
    kali_warmup
    ;;
  kali-run)
    kali_run
    ;;
esac
