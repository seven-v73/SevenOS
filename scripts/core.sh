#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sevenos"
EVENT_FILE="$STATE_DIR/events.jsonl"
BUS_SCHEMA="$ROOT_DIR/seven-core/bus-schema.json"
DAEMON_MANIFEST="$ROOT_DIR/seven-core/daemon/Cargo.toml"
SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
DAEMON_SERVICE_SOURCE="$ROOT_DIR/systemd/user/seven-daemon.service"
DAEMON_SERVICE_TARGET="$SYSTEMD_USER_DIR/seven-daemon.service"
JSON_OUTPUT=0
ACTION="${1:-status}"

usage() {
  cat <<'EOF'
SevenOS Core

Usage:
  seven core
  seven core status --json
  seven core plan --json
  seven core doctor
  seven core bus --json
  seven core schema --json
  seven core install-service
  seven core start
  seven core stop
  seven core logs
  seven core snapshot --json
  seven core health --json

Seven Core is the system experience layer foundation above Linux and Arch:
contracts, local event bus, daemon scaffold, API handoff and policy surface.
EOF
}

shift || true
for arg in "$@"; do
  case "$arg" in
    --json|json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown core option: $arg"; usage; exit 1 ;;
  esac
done

json_string() {
  python -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))'
}

file_state() {
  [[ -s "$ROOT_DIR/$1" ]] && printf OK || printf MISS
}

exec_state() {
  [[ -x "$ROOT_DIR/$1" ]] && printf OK || printf MISS
}

command_state() {
  command -v "$1" >/dev/null 2>&1 && printf OK || printf MISS
}

service_state() {
  if systemctl --user is-active --quiet seven-daemon.service 2>/dev/null; then
    printf RUN
  elif systemctl --user is-enabled --quiet seven-daemon.service 2>/dev/null; then
    printf READY
  elif [[ -s "$DAEMON_SERVICE_TARGET" ]]; then
    printf INSTALLED
  elif [[ -s "$DAEMON_SERVICE_SOURCE" ]]; then
    printf AVAILABLE
  else
    printf MISS
  fi
}

event_count() {
  if [[ -s "$EVENT_FILE" ]]; then
    wc -l < "$EVENT_FILE" | tr -d ' '
  else
    printf '0'
  fi
}

status_json() {
  local contracts api bus_schema daemon daemon_src daemon_bin daemon_json bus_c bus_c_bin cc_state make_state service rust cargo events state
  contracts=0
  [[ "$(exec_state scripts/state.sh)" == OK ]] && contracts=$((contracts + 1))
  [[ "$(exec_state scripts/control-plane.sh)" == OK ]] && contracts=$((contracts + 1))
  [[ "$(exec_state scripts/events.sh)" == OK ]] && contracts=$((contracts + 1))
  [[ "$(exec_state scripts/insights.sh)" == OK ]] && contracts=$((contracts + 1))
  [[ "$(exec_state scripts/phase-gate.sh)" == OK ]] && contracts=$((contracts + 1))

  api="$(exec_state server/seven-server.sh)"
  bus_schema="$(file_state seven-core/bus-schema.json)"
  daemon="$(file_state seven-core/daemon/Cargo.toml)"
  daemon_src="$(file_state seven-core/daemon/src/main.rs)"
  daemon_bin="$(exec_state bin/seven-daemon)"
  daemon_json="$([[ -s "$DAEMON_MANIFEST" ]] && grep -q 'serde_json' "$DAEMON_MANIFEST" && printf OK || printf MISS)"
  bus_c="$(file_state seven-core/bus-c/src/sevenbus_probe.c)"
  bus_c_bin="$(exec_state bin/sevenbus-probe)"
  cc_state="$(command_state cc)"
  make_state="$(command_state make)"
  service="$(service_state)"
  rust="$(command_state rustc)"
  cargo="$(command_state cargo)"
  events="$(event_count)"

  state="PLANNED"
  if [[ "$contracts" -ge 5 && "$api" == OK && "$bus_schema" == OK && "$daemon" == OK && "$daemon_src" == OK && "$daemon_bin" == OK ]]; then
    state="FOUNDATION"
  fi
  if [[ "$state" == FOUNDATION && "$rust" == OK && "$cargo" == OK ]]; then
    state="READY_FOR_DAEMON"
  fi

  CORE_STATE="$state" CONTRACTS="$contracts" API_STATE="$api" BUS_SCHEMA_STATE="$bus_schema" DAEMON_STATE="$daemon" DAEMON_SRC_STATE="$daemon_src" DAEMON_BIN_STATE="$daemon_bin" DAEMON_JSON_STATE="$daemon_json" BUS_C_STATE="$bus_c" BUS_C_BIN_STATE="$bus_c_bin" CC_STATE="$cc_state" MAKE_STATE="$make_state" DAEMON_SERVICE_STATE="$service" RUST_STATE="$rust" CARGO_STATE="$cargo" EVENT_COUNT="$events" EVENT_FILE="$EVENT_FILE" BUS_SCHEMA="$BUS_SCHEMA" python - <<'PY'
import json
import os

state = os.environ["CORE_STATE"]
contracts = int(os.environ["CONTRACTS"])
runtime_ready = os.environ["RUST_STATE"] == "OK" and os.environ["CARGO_STATE"] == "OK"

components = [
    {"key": "contracts", "title": "Machine contracts", "state": "OK" if contracts >= 5 else "PART", "detail": f"{contracts}/5 core contracts available"},
    {"key": "local_api", "title": "Seven Server handoff", "state": os.environ["API_STATE"], "detail": "Local API can expose Core state to Hub and future Shell."},
    {"key": "sevenbus_schema", "title": "SevenBus schema", "state": os.environ["BUS_SCHEMA_STATE"], "detail": os.environ["BUS_SCHEMA"]},
    {"key": "daemon_scaffold", "title": "Rust daemon scaffold", "state": "OK" if os.environ["DAEMON_STATE"] == "OK" and os.environ["DAEMON_SRC_STATE"] == "OK" else "MISS", "detail": "seven-core/daemon"},
    {"key": "daemon_cli", "title": "Seven daemon CLI", "state": os.environ["DAEMON_BIN_STATE"], "detail": "bin/seven-daemon"},
    {"key": "bus_writer", "title": "Rust SevenBus writer", "state": os.environ["DAEMON_BIN_STATE"], "detail": "seven-daemon emit"},
    {"key": "bus_reader", "title": "Typed SevenBus reader", "state": os.environ["DAEMON_JSON_STATE"], "detail": "serde_json snapshot parser"},
    {"key": "events_reader", "title": "Rust event list reader", "state": os.environ["DAEMON_JSON_STATE"], "detail": "seven-daemon events / summary"},
    {"key": "bus_c_probe", "title": "C SevenBus probe", "state": "OK" if os.environ["BUS_C_STATE"] == "OK" and os.environ["BUS_C_BIN_STATE"] == "OK" else "MISS", "detail": "sevenbus-probe"},
    {"key": "c_toolchain", "title": "C toolchain", "state": "OK" if os.environ["CC_STATE"] == "OK" and os.environ["MAKE_STATE"] == "OK" else "MISS", "detail": "cc + make for low-level IPC probes"},
    {"key": "daemon_service", "title": "Seven daemon service", "state": os.environ["DAEMON_SERVICE_STATE"], "detail": "seven-daemon.service"},
    {"key": "rust_toolchain", "title": "Rust toolchain", "state": "OK" if runtime_ready else "MISS", "detail": "Required before compiling seven-daemon."},
    {"key": "event_journal", "title": "Local event journal", "state": "OK" if int(os.environ["EVENT_COUNT"]) > 0 else "READY", "detail": os.environ["EVENT_FILE"]},
]

print(json.dumps({
    "schema": "sevenos.core.v1",
    "state": state,
    "role": "System Experience Layer foundation above Linux and Arch",
    "bus": {
        "schema": "sevenos.bus.v1",
        "transport": "jsonl-user-state-now, typed-local-ipc-later",
        "low_level_probe": "sevenbus-probe",
        "event_file": os.environ["EVENT_FILE"],
        "event_count": int(os.environ["EVENT_COUNT"]),
    },
    "daemon": {
        "name": "seven-daemon",
        "language": "Rust",
        "state": "scaffold" if os.environ["DAEMON_STATE"] == "OK" else "missing",
        "manifest": "seven-core/daemon/Cargo.toml",
        "command": "seven-daemon",
        "service": os.environ["DAEMON_SERVICE_STATE"],
    },
    "components": components,
    "next_focus": [
        "Keep every system-facing command JSON-clean",
        "Expose Core through Seven Server and Seven Hub Native",
        "Promote SevenBus from JSONL audit trail to typed local IPC",
        "Compile and supervise seven-daemon as a user service",
    ],
}, indent=2))
PY
}

plan_json() {
  CORE_STATUS="$(status_json)" python - <<'PY'
import json
import os

status = json.loads(os.environ["CORE_STATUS"])
components = {item["key"]: item for item in status.get("components", [])}
actions = []

def add(key, title, severity, command, reason, impact="safe", phase="core"):
    actions.append({
        "key": key,
        "title": title,
        "severity": severity,
        "impact": impact,
        "phase": phase,
        "command": command,
        "reason": reason,
    })

if components.get("sevenbus_schema", {}).get("state") != "OK":
    add("bus-schema", "Create SevenBus schema", "critical", "git checkout -- seven-core/bus-schema.json", "SevenBus needs a stable event envelope before UI surfaces can trust it.", "changes", "contracts")

if components.get("daemon_scaffold", {}).get("state") != "OK":
    add("daemon-scaffold", "Create seven-daemon scaffold", "high", "seven core doctor", "The future system core needs a compiled daemon target.", "changes", "daemon")

if components.get("rust_toolchain", {}).get("state") != "OK":
    add("rust-toolchain", "Install Rust toolchain", "medium", "sevenpkg install forge", "Rust is needed to compile the future seven-daemon safely.", "packages", "daemon")

if components.get("c_toolchain", {}).get("state") != "OK":
    add("c-toolchain", "Install C build toolchain", "medium", "sudo pacman -S --needed base-devel", "C is reserved for SevenBus IPC probes and future hardware-adjacent components.", "packages", "bus")

if components.get("event_journal", {}).get("state") == "READY":
    add("seed-event", "Record the first Core event", "low", "seven events log --source core --type boot --message 'Seven Core initialized'", "A local event history makes system decisions auditable.", "safe", "bus")

service_state = components.get("daemon_service", {}).get("state")
if service_state in ("MISS", "AVAILABLE"):
    add("daemon-service", "Install seven-daemon user service", "medium", "seven core install-service", "The next step is supervising the daemon through systemd user services.", "changes", "service")
elif service_state in ("INSTALLED", "READY"):
    add("daemon-start", "Start seven-daemon user service", "medium", "seven core start", "Starting the daemon turns Seven Core into a live runtime instead of only a contract.", "changes", "service")

rank = {"critical": 0, "high": 1, "medium": 2, "low": 3}
actions.sort(key=lambda item: (rank.get(item["severity"], 9), item["key"]))

print(json.dumps({
    "schema": "sevenos.core-plan.v1",
    "summary": {
        "total": len(actions),
        "critical": sum(1 for item in actions if item["severity"] == "critical"),
        "high": sum(1 for item in actions if item["severity"] == "high"),
        "medium": sum(1 for item in actions if item["severity"] == "medium"),
        "low": sum(1 for item in actions if item["severity"] == "low"),
    },
    "next": actions,
}, indent=2))
PY
}

status_human() {
  CORE_STATUS="$(status_json)" python - <<'PY'
import json
import os

data = json.loads(os.environ["CORE_STATUS"])
print("SevenOS Core")
print("============")
print(f"State: {data.get('state')}")
print(f"Role:  {data.get('role')}")
print(f"Bus:   {data.get('bus', {}).get('transport')} · {data.get('bus', {}).get('event_count')} events")
print(f"Daemon:{data.get('daemon', {}).get('state')} · {data.get('daemon', {}).get('manifest')}")
print()
print(f"{'State':<8} {'Component':<24} Detail")
print(f"{'-----':<8} {'---------':<24} ------")
for item in data.get("components", []):
    print(f"{item.get('state',''):<8} {item.get('title',''):<24} {item.get('detail','')}")
PY
}

plan_human() {
  CORE_PLAN="$(plan_json)" python - <<'PY'
import json
import os

data = json.loads(os.environ["CORE_PLAN"])
summary = data.get("summary", {})
print("SevenOS Core Plan")
print("=================")
print(f"Open actions: {summary.get('total', 0)}")
print()
for item in data.get("next", []):
    print(f"[{item.get('severity')}] {item.get('title')}")
    print(f"  command: {item.get('command')}")
    print(f"  reason:  {item.get('reason')}")
PY
}

schema_json() {
  if [[ -s "$BUS_SCHEMA" ]]; then
    cat "$BUS_SCHEMA"
  else
    printf '{"schema":"sevenos.bus.v1","state":"MISS"}\n'
  fi
}

snapshot_json() {
  if [[ -x "$ROOT_DIR/bin/seven-daemon" ]]; then
    "$ROOT_DIR/bin/seven-daemon" snapshot --json
  else
    printf '{"schema":"sevenos.daemon.snapshot.v1","state":"MISS","event_count":0}\n'
  fi
}

health_json() {
  if [[ -x "$ROOT_DIR/bin/seven-daemon" ]]; then
    "$ROOT_DIR/bin/seven-daemon" health --json
  else
    printf '{"schema":"sevenos.daemon.health.v1","state":"MISS","checks":[]}\n'
  fi
}

doctor() {
  local missing=0
  printf 'SevenOS Core Doctor\n'
  printf '===================\n'
  for path in scripts/state.sh scripts/control-plane.sh scripts/events.sh scripts/insights.sh scripts/phase-gate.sh server/seven-server.sh bin/seven-daemon bin/sevenbus-probe systemd/user/seven-daemon.service seven-core/README.md seven-core/bus-schema.json seven-core/daemon/Cargo.toml seven-core/daemon/src/main.rs seven-core/bus-c/README.md seven-core/bus-c/Makefile seven-core/bus-c/src/sevenbus_probe.c; do
    if [[ -s "$ROOT_DIR/$path" ]]; then
      printf '[OK] %s\n' "$path"
    else
      printf '[MISS] %s\n' "$path"
      missing=$((missing + 1))
    fi
  done

  if command -v cargo >/dev/null 2>&1; then
    if cargo check --manifest-path "$DAEMON_MANIFEST" >/dev/null 2>&1; then
      printf '[OK] seven-daemon cargo check\n'
    else
      printf '[WARN] seven-daemon cargo check failed\n'
    fi
  else
    printf '[WARN] cargo missing; install Rust before compiling seven-daemon\n'
  fi

  if command -v make >/dev/null 2>&1 && command -v cc >/dev/null 2>&1; then
    if make -C "$ROOT_DIR/seven-core/bus-c" >/dev/null 2>&1; then
      printf '[OK] sevenbus-probe C build\n'
    else
      printf '[WARN] sevenbus-probe C build failed\n'
    fi
  else
    printf '[WARN] C compiler or make missing; install base-devel before building C bus probes\n'
  fi

  if [[ "$missing" -gt 0 ]]; then
    log_error "Seven Core foundation is incomplete."
    return 1
  fi
  log_success "Seven Core foundation is ready."
}

install_service() {
  log_info "Installing seven-daemon user service..."
  if is_dry_run; then
    printf 'mkdir -p %q\n' "$SYSTEMD_USER_DIR"
    printf 'cp %q %q\n' "$DAEMON_SERVICE_SOURCE" "$DAEMON_SERVICE_TARGET"
    printf 'systemctl --user daemon-reload\n'
    printf 'systemctl --user enable seven-daemon.service\n'
    return 0
  fi

  mkdir -p "$SYSTEMD_USER_DIR"
  cp "$DAEMON_SERVICE_SOURCE" "$DAEMON_SERVICE_TARGET"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    systemctl --user enable seven-daemon.service >/dev/null 2>&1 || true
  fi
  log_success "seven-daemon user service installed."
}

case "$ACTION" in
  status)
    [[ "$JSON_OUTPUT" -eq 1 ]] && status_json || status_human
    ;;
  --json|json)
    status_json
    ;;
  plan)
    [[ "$JSON_OUTPUT" -eq 1 ]] && plan_json || plan_human
    ;;
  doctor)
    doctor
    ;;
  install-service)
    install_service
    ;;
  start)
    run_cmd systemctl --user start seven-daemon.service
    ;;
  stop)
    run_cmd systemctl --user stop seven-daemon.service
    ;;
  logs)
    run_cmd journalctl --user -u seven-daemon.service -f
    ;;
  bus|schema)
    [[ "$JSON_OUTPUT" -eq 1 ]] && schema_json || { printf 'SevenBus schema: %s\n' "$BUS_SCHEMA"; }
    ;;
  snapshot)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      snapshot_json
    else
      snapshot_json | python -m json.tool
    fi
    ;;
  health)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then
      health_json
    else
      health_json | python -m json.tool
    fi
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    log_error "Unknown core action: $ACTION"
    usage
    exit 1
    ;;
esac
