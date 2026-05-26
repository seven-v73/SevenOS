#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

HOST="${SEVENOS_SERVER_HOST:-127.0.0.1}"
PORT="${SEVENOS_SERVER_PORT:-7777}"
ALLOW_UNSAFE_EXPOSE="${SEVENOS_SERVER_EXPOSE_UNSAFE:-0}"
UNIT_DIR="$HOME/.config/systemd/user"
UNIT_FILE="$UNIT_DIR/seven-server.service"
JSON_OUTPUT=0
REQUIRED_PROFILE="forge"

usage() {
  cat <<'EOF'
SevenOS Server

Usage:
  seven server <action>
  ./server/seven-server.sh <action>

Actions:
  status                Show local server and deployment readiness
  status --json         Show machine-readable server readiness
  plan                  Show prioritized local backend actions
  plan --json           Show machine-readable backend action plan
  doctor                Check server dependencies
  serve                 Run the local SevenOS API on 127.0.0.1:7777
  install-user-service  Install a user systemd service for seven-server
  start                 Start the user service
  stop                  Stop the user service
  logs                  Follow user service logs

Environment:
  SEVENOS_SERVER_HOST   Bind host, default 127.0.0.1
  SEVENOS_SERVER_PORT   Bind port, default 7777
  SEVENOS_SERVER_EXPOSE_UNSAFE=1 is required for non-local binds
EOF
}

json_string() {
  python -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))'
}

active_profile() {
  if [[ -n "${SEVENOS_ACTIVE_PROFILE:-}" ]]; then
    printf '%s\n' "$SEVENOS_ACTIVE_PROFILE"
    return 0
  fi
  if [[ -n "${SEVENOS_PROFILE_CONTAINER:-}" ]]; then
    printf '%s\n' "$SEVENOS_PROFILE_CONTAINER"
    return 0
  fi
  if [[ -n "${SEVENOS_EXEC_PROFILE:-}" ]]; then
    printf '%s\n' "$SEVENOS_EXEC_PROFILE"
    return 0
  fi
  local env_file="${XDG_CONFIG_HOME:-$HOME/.config}/sevenos/profile.env"
  if [[ -f "$env_file" ]]; then
    sed -n 's/^SEVENOS_ACTIVE_PROFILE=//p' "$env_file" 2>/dev/null | head -1 | tr -d '"'\'' '
    return 0
  fi
  local json_file="${XDG_CONFIG_HOME:-$HOME/.config}/sevenos/profile.json"
  if [[ -f "$json_file" ]]; then
    python - "$json_file" <<'PY' 2>/dev/null || true
import json, sys
try:
    print(json.load(open(sys.argv[1], encoding="utf-8")).get("key", "equinox"))
except Exception:
    print("equinox")
PY
    return 0
  fi
  printf 'equinox\n'
}

normalize_profile() {
  case "$1" in
    horizon) printf 'forge\n' ;;
    "") printf 'equinox\n' ;;
    *) printf '%s\n' "$1" ;;
  esac
}

require_forge_profile() {
  local action="$1" profile
  profile="$(normalize_profile "$(active_profile)")"
  if [[ "$profile" == "$REQUIRED_PROFILE" ]]; then
    return 0
  fi
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    printf '{"schema":"sevenos.profile-gate.v1","state":"FORBIDDEN","required_profile":"forge","active_profile":%s,"surface":"server","action":%s,"reason":"SevenOS Server runtime and deployment API are available only inside the Forge mini OS.","next":[{"command":"seven profile activate forge","reason":"Switch to the Forge development mini OS."},{"command":"seven-terminal forge","reason":"Open a Forge terminal for server and deployment work."}]}\n' \
      "$(printf '%s' "$profile" | json_string)" \
      "$(printf '%s' "$action" | json_string)"
  else
    log_error "SevenOS Server runtime is available only in Forge. Active mini OS: $profile"
    printf 'Switch with: seven profile activate forge\n' >&2
    printf 'Or open:     seven-terminal forge\n' >&2
  fi
  return 1
}

command_state() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    printf 'OK'
  else
    printf 'MISS'
  fi
}

service_state() {
  if systemctl --user is-active --quiet seven-server.service 2>/dev/null; then
    printf 'RUN'
  elif systemctl --user is-enabled --quiet seven-server.service 2>/dev/null; then
    printf 'READY'
  else
    printf 'MISS'
  fi
}

daemon_json() {
  local action="$1"
  if [[ "$JSON_OUTPUT" -eq 1 && -x "$ROOT_DIR/bin/seven-daemon" ]]; then
    exec "$ROOT_DIR/bin/seven-daemon" "$action" --json
  fi
}

status() {
  daemon_json server
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    local service go_state podman_state caddy_state jq_state deploy_state bind_state
    local profile profile_allowed
    service="$(service_state)"
    go_state="$(command_state go)"
    podman_state="$(command_state podman)"
    caddy_state="$(command_state caddy)"
    jq_state="$(command_state jq)"
    deploy_state="$([[ -x "$ROOT_DIR/server/seven-deploy.sh" ]] && printf OK || printf MISS)"
    profile="$(normalize_profile "$(active_profile)")"
    profile_allowed="$([[ "$profile" == "$REQUIRED_PROFILE" ]] && printf true || printf false)"
    bind_state="LOCAL"
    [[ "$HOST" != "127.0.0.1" && "$HOST" != "localhost" ]] && bind_state="EXPOSED"

    printf '{'
    printf '"schema":"sevenos.server.v1",'
    printf '"profile_gate":{"required_profile":"forge","active_profile":%s,"server_runtime_allowed":%s,"deploy_api_allowed":%s,"blocked_contract":"sevenos.profile-gate.v1"},' \
      "$(printf '%s' "$profile" | json_string)" "$profile_allowed" "$profile_allowed"
    printf '"bind":{"host":%s,"port":%s,"state":%s},' \
      "$(printf '%s' "$HOST" | json_string)" \
      "$(printf '%s' "$PORT" | json_string)" \
      "$(printf '%s' "$bind_state" | json_string)"
    printf '"service":{"name":"seven-server.service","state":%s},' "$(printf '%s' "$service" | json_string)"
    printf '"dependencies":['
    printf '{"key":"go","state":%s},' "$(printf '%s' "$go_state" | json_string)"
    printf '{"key":"podman","state":%s},' "$(printf '%s' "$podman_state" | json_string)"
    printf '{"key":"caddy","state":%s},' "$(printf '%s' "$caddy_state" | json_string)"
    printf '{"key":"jq","state":%s},' "$(printf '%s' "$jq_state" | json_string)"
    printf '{"key":"seven-deploy","state":%s}' "$(printf '%s' "$deploy_state" | json_string)"
    printf '],'
    printf '"endpoints":["/health","/state","/status","/welcome","/welcome-plan","/session","/identity","/profiles","/profile-gaps","/profile-plan","/windows","/windows-plan","/installer","/installer-plan","/packages","/packages-plan","/store","/box","/cloud","/flow","/cluster","/monitor/system","/readiness","/manifest","/actions","/stack","/shell","/shell-plan","/core","/core-plan","/core-snapshot","/core-health","/core-observe","/scheduler","/context","/bus","/experience","/shield","/shield-plan","/cyberspace","/cyberspace-plan","/server-plan","/control","/b3","/daily","/events","/insights","/deploy/status","/deploy/inspect","/deploy/doctor","/deploy/services","/deploy/panel","/deploy/domain","/deploy/dns-check","/deploy/route-check","/deploy/diagnose"],'
    printf '"recommendations":['
    local first=1
    if [[ "$service" != "RUN" ]]; then
      printf '{"command":"seven server install-user-service","reason":"Install the local API user service"}'
      first=0
    fi
    if [[ "$service" == "READY" ]]; then
      [[ "$first" -eq 1 ]] || printf ','
      printf '{"command":"seven server start","reason":"Start the local API user service"}'
      first=0
    fi
    if [[ "$go_state" != OK || "$podman_state" != OK || "$caddy_state" != OK || "$jq_state" != OK ]]; then
      [[ "$first" -eq 1 ]] || printf ','
      printf '{"command":"seven improve deployment --apply","reason":"Install server and deployment dependencies"}'
    fi
    printf ']'
    printf '}\n'
    return 0
  fi

  printf 'SevenOS Server Status\n'
  printf '=====================\n'
  printf 'API bind:     %s:%s\n' "$HOST" "$PORT"
  printf 'user service: %s\n' "$(service_state)"
  printf 'go:           %s\n' "$(command_state go)"
  printf 'podman:       %s\n' "$(command_state podman)"
  printf 'caddy:        %s\n' "$(command_state caddy)"
  printf 'jq:           %s\n' "$(command_state jq)"
  printf 'deploy tool:  %s\n' "$([[ -x "$ROOT_DIR/server/seven-deploy.sh" ]] && printf OK || printf MISS)"
  printf '\nSecurity posture:\n'
  printf '  Local-first API. Keep host at 127.0.0.1 until auth/TLS policies are enabled.\n'
}

plan_json() {
  if [[ -x "$ROOT_DIR/bin/seven-daemon" ]]; then
    "$ROOT_DIR/bin/seven-daemon" server-plan --json
    return 0
  fi

  local service go_state podman_state caddy_state jq_state deploy_state bind_state
  service="$(service_state)"
  go_state="$(command_state go)"
  podman_state="$(command_state podman)"
  caddy_state="$(command_state caddy)"
  jq_state="$(command_state jq)"
  deploy_state="$([[ -x "$ROOT_DIR/server/seven-deploy.sh" ]] && printf OK || printf MISS)"
  bind_state="LOCAL"
  [[ "$HOST" != "127.0.0.1" && "$HOST" != "localhost" ]] && bind_state="EXPOSED"

  SERVER_ROWS="$(
    printf 'service\t%s\tSeven Server user service\tseven server install-user-service\n' "$([[ "$service" == READY || "$service" == RUN ]] && printf OK || printf MISS)"
    printf 'service-start\t%s\tSeven Server runtime\tseven server start\n' "$([[ "$service" == RUN ]] && printf OK || printf MISS)"
    printf 'go\t%s\tGo runtime for future native backend components\tseven improve deployment --apply\n' "$go_state"
    printf 'podman\t%s\tRootless container runtime for deployment flows\tseven improve deployment --apply\n' "$podman_state"
    printf 'caddy\t%s\tLocal reverse proxy for deployment previews\tseven improve deployment --apply\n' "$caddy_state"
    printf 'jq\t%s\tJSON tooling for scripts and diagnostics\tseven improve deployment --apply\n' "$jq_state"
    printf 'seven-deploy\t%s\tSevenOS deployment planner\tseven deploy status\n' "$deploy_state"
    printf 'bind\t%s\tLocal-only API bind policy\tseven server status\n' "$([[ "$bind_state" == LOCAL ]] && printf OK || printf PART)"
  )" python - <<'PY'
import json
import os

metadata = {
    "service": {
        "title": "Install Seven Server service",
        "severity": "high",
        "impact": "changes",
        "phase": "service",
        "reason": "Seven Hub needs a durable local backend instead of calling scattered scripts directly.",
    },
    "service-start": {
        "title": "Start Seven Server service",
        "severity": "high",
        "impact": "changes",
        "phase": "service",
        "reason": "The local API must run before SevenOS can feel like a connected ecosystem.",
    },
    "go": {
        "title": "Install Go backend toolchain",
        "severity": "medium",
        "impact": "packages",
        "phase": "backend",
        "reason": "Go is the planned low-footprint path for the future seven-server backend.",
    },
    "podman": {
        "title": "Install rootless container runtime",
        "severity": "high",
        "impact": "packages",
        "phase": "deploy",
        "reason": "Seven Deploy needs rootless containers to host apps without exposing the system.",
    },
    "caddy": {
        "title": "Install local reverse proxy",
        "severity": "medium",
        "impact": "packages",
        "phase": "deploy",
        "reason": "Caddy prepares HTTPS/reverse-proxy flows for the personal operating cloud.",
    },
    "jq": {
        "title": "Install JSON diagnostics",
        "severity": "medium",
        "impact": "packages",
        "phase": "contracts",
        "reason": "Machine-readable contracts need reliable JSON tooling for tests and operators.",
    },
    "seven-deploy": {
        "title": "Restore deployment planner",
        "severity": "critical",
        "impact": "changes",
        "phase": "deploy",
        "reason": "Seven Server cannot orchestrate deployments without seven-deploy.",
    },
    "bind": {
        "title": "Keep local API private",
        "severity": "critical",
        "impact": "safe",
        "phase": "trust",
        "reason": "Remote exposure must wait for authentication, TLS and audit policy.",
    },
}

rank = {"critical": 0, "high": 1, "medium": 2, "low": 3}
actions = []

for raw in os.environ["SERVER_ROWS"].splitlines():
    key, state, detail, command = raw.split("\t", 3)
    if state == "OK":
        continue
    item = metadata.get(key, {})
    actions.append({
        "key": key,
        "state": state,
        "title": item.get("title", f"Fix {key}"),
        "severity": item.get("severity", "medium"),
        "impact": item.get("impact", "changes"),
        "phase": item.get("phase", "service"),
        "detail": detail,
        "reason": item.get("reason", f"Resolve {key}."),
        "command": command,
    })

actions.sort(key=lambda item: (rank.get(item["severity"], 9), item["key"]))

print(json.dumps({
    "schema": "sevenos.server-plan.v1",
    "summary": {
        "total": len(actions),
        "critical": sum(1 for item in actions if item["severity"] == "critical"),
        "high": sum(1 for item in actions if item["severity"] == "high"),
        "medium": sum(1 for item in actions if item["severity"] == "medium"),
    },
    "next": actions,
}, indent=2))
PY
}

plan() {
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    plan_json
    return 0
  fi

  SERVER_PLAN="$(plan_json)" python - <<'PY'
import json
import os

data = json.loads(os.environ["SERVER_PLAN"])
summary = data.get("summary", {})

print("SevenOS Server Plan")
print("===================")
print(
    f"Open actions: {summary.get('total', 0)} "
    f"({summary.get('critical', 0)} critical, {summary.get('high', 0)} high, {summary.get('medium', 0)} medium)"
)
print()
print(f"{'Severity':<9} {'Phase':<9} {'Command'}")
print(f"{'--------':<9} {'-----':<9} {'-------'}")
for item in data.get("next", []):
    print(f"{item.get('severity',''):<9} {item.get('phase',''):<9} {item.get('command','')}")
    print(f"{'':<9} {'':<9} {item.get('reason','')}")
PY
}

doctor() {
  local missing=0
  local command_name

  printf 'SevenOS Server Doctor\n'
  printf '=====================\n'
  for command_name in go podman caddy jq git rsync ssh; do
    if command -v "$command_name" >/dev/null 2>&1; then
      printf '[OK] %s\n' "$command_name"
    else
      printf '[MISS] %s\n' "$command_name"
      missing=$((missing + 1))
    fi
  done

  [[ -x "$ROOT_DIR/server/seven-deploy.sh" ]] && printf '[OK] seven-deploy\n' || { printf '[MISS] seven-deploy\n'; missing=$((missing + 1)); }

  if [[ "$HOST" != "127.0.0.1" && "$HOST" != "localhost" ]]; then
    log_warn "API is configured for a non-local bind host. Add auth/TLS before exposing it."
  fi

  if [[ "$missing" -gt 0 ]]; then
    log_warn "Install the server profile with: seven improve deployment --apply --yes"
    return 1
  fi

  log_success "Server layer dependencies are ready."
}

serve() {
  if [[ "$HOST" != "127.0.0.1" && "$HOST" != "localhost" && "$ALLOW_UNSAFE_EXPOSE" != "1" ]]; then
    log_error "Refusing non-local bind without SEVENOS_SERVER_EXPOSE_UNSAFE=1. Seven Server is local-only until auth/TLS policy is enabled."
    return 1
  fi
  export SEVENOS_ROOT="$ROOT_DIR" SEVENOS_SERVER_HOST="$HOST" SEVENOS_SERVER_PORT="$PORT"
  export SEVENOS_SERVER_EXPOSE_UNSAFE="$ALLOW_UNSAFE_EXPOSE"
  log_info "Starting SevenOS local API at http://$HOST:$PORT"
  python - <<'PY'
import json
import os
import platform
import subprocess
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

ROOT = os.environ["SEVENOS_ROOT"]
HOST = os.environ.get("SEVENOS_SERVER_HOST", "127.0.0.1")
PORT = int(os.environ.get("SEVENOS_SERVER_PORT", "7777"))
CACHE_TTL = float(os.environ.get("SEVENOS_SERVER_CACHE_TTL", "2.0"))
COMMAND_TIMEOUT = float(os.environ.get("SEVENOS_SERVER_COMMAND_TIMEOUT", "8.0"))
_CACHE = {}

def command_json(command):
    key = tuple(command)
    now = time.monotonic()
    cached = _CACHE.get(key)
    if cached and now - cached["time"] <= CACHE_TTL:
        payload = dict(cached["payload"])
        payload.setdefault("cached", True)
        return payload
    try:
        result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False, timeout=COMMAND_TIMEOUT)
    except subprocess.TimeoutExpired:
        return {
            "ok": False,
            "schema": "sevenos.server.error.v1",
            "error": "command timeout",
            "command": command,
            "timeout_seconds": COMMAND_TIMEOUT,
        }
    if result.returncode != 0:
        try:
            payload = json.loads(result.stdout)
            if isinstance(payload, dict) and payload.get("schema") == "sevenos.profile-gate.v1":
                return payload
        except json.JSONDecodeError:
            pass
        return {
            "ok": False,
            "schema": "sevenos.server.error.v1",
            "error": result.stderr.strip() or result.stdout.strip(),
            "command": command,
            "returncode": result.returncode,
        }
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        payload = {"ok": True, "schema": "sevenos.server.output.v1", "output": result.stdout.strip(), "command": command}
    _CACHE[key] = {"time": now, "payload": payload}
    return payload

def active_profile():
    for key in ("SEVENOS_ACTIVE_PROFILE", "SEVENOS_PROFILE_CONTAINER", "SEVENOS_EXEC_PROFILE"):
        value = os.environ.get(key, "").strip()
        if value:
            return "forge" if value == "horizon" else value
    env_path = os.path.expanduser("~/.config/sevenos/profile.env")
    try:
        with open(env_path, "r", encoding="utf-8") as handle:
            for line in handle:
                if line.startswith("SEVENOS_ACTIVE_PROFILE="):
                    value = line.split("=", 1)[1].strip().strip("'\"")
                    return "forge" if value == "horizon" else value
    except OSError:
        pass
    json_path = os.path.expanduser("~/.config/sevenos/profile.json")
    try:
        with open(json_path, "r", encoding="utf-8") as handle:
            value = json.load(handle).get("key", "equinox")
            return "forge" if value == "horizon" else value
    except Exception:
        return "equinox"

def forge_gate_payload(path):
    profile = active_profile()
    return {
        "schema": "sevenos.profile-gate.v1",
        "state": "FORBIDDEN",
        "required_profile": "forge",
        "active_profile": profile,
        "surface": "server-api",
        "path": path,
        "reason": "SevenOS deployment and hosting API endpoints are available only inside the Forge mini OS.",
        "next": [
            {"command": "seven profile activate forge", "reason": "Switch to the Forge development mini OS."},
            {"command": "seven-terminal forge", "reason": "Open a Forge terminal for server and deployment work."},
        ],
    }

def forge_allowed():
    return active_profile() == "forge"

def memory():
    data = {}
    with open("/proc/meminfo", "r", encoding="utf-8") as handle:
        for line in handle:
            key, value = line.split(":", 1)
            data[key] = value.strip()
    return data

class Handler(BaseHTTPRequestHandler):
    def send_json(self, payload, status=200):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("X-SevenOS-Policy", "local-only")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)

        if path.startswith("/deploy/") and not forge_allowed():
            self.send_json(forge_gate_payload(path), status=403)
            return

        def project_path():
            return query.get("path", [ROOT])[0]

        def query_value(name, default=""):
            return query.get(name, [default])[0]

        def deploy_command(action, subject, *extra):
            command = [os.path.join(ROOT, "server/seven-deploy.sh"), action, subject]
            command.extend(item for item in extra if item)
            command.append("--json")
            return command

        if path == "/health":
            self.send_json({"ok": True, "service": "seven-server", "bind": f"{HOST}:{PORT}"})
        elif path == "/state":
            self.send_json(command_json([os.path.join(ROOT, "scripts/state.sh"), "--json"]))
        elif path == "/status":
            self.send_json(command_json([os.path.join(ROOT, "bin/seven"), "status", "--json"]))
        elif path == "/welcome":
            self.send_json(command_json([os.path.join(ROOT, "bin/seven-welcome"), "status", "--json"]))
        elif path == "/welcome-plan":
            self.send_json(command_json([os.path.join(ROOT, "bin/seven-welcome"), "plan", "--json"]))
        elif path == "/session":
            self.send_json(command_json([os.path.join(ROOT, "bin/seven-session-status"), "--json"]))
        elif path == "/identity":
            self.send_json(command_json([os.path.join(ROOT, "scripts/identity.sh"), "--json"]))
        elif path == "/profiles":
            self.send_json(command_json([os.path.join(ROOT, "bin/seven"), "profile", "status", "--json"]))
        elif path == "/profile-gaps":
            self.send_json(command_json([os.path.join(ROOT, "bin/seven"), "profile", "gaps", "--json"]))
        elif path == "/profile-plan":
            self.send_json(command_json([os.path.join(ROOT, "bin/seven"), "profile", "plan", "--json"]))
        elif path == "/windows":
            self.send_json(command_json([os.path.join(ROOT, "bin/seven-windows-assistant"), "status", "--json"]))
        elif path == "/windows-plan":
            self.send_json(command_json([os.path.join(ROOT, "bin/seven-windows-assistant"), "plan", "--json"]))
        elif path == "/installer":
            self.send_json(command_json([os.path.join(ROOT, "scripts/installer-stack.sh"), "status", "--json"]))
        elif path == "/installer-plan":
            self.send_json(command_json([os.path.join(ROOT, "scripts/installer-stack.sh"), "plan", "--json"]))
        elif path == "/packages":
            self.send_json(command_json([os.path.join(ROOT, "bin/sevenpkg"), "status", "--json"]))
        elif path == "/packages-plan":
            self.send_json(command_json([os.path.join(ROOT, "bin/sevenpkg"), "plan", "--json"]))
        elif path == "/store":
            self.send_json(command_json([os.path.join(ROOT, "scripts/store.sh"), "json"]))
        elif path == "/box":
            self.send_json(command_json([os.path.join(ROOT, "scripts/box.sh"), "json"]))
        elif path == "/cloud":
            self.send_json(command_json([os.path.join(ROOT, "scripts/cloud.sh"), "json"]))
        elif path == "/flow":
            self.send_json(command_json([os.path.join(ROOT, "scripts/flow.sh"), "json"]))
        elif path == "/cluster":
            self.send_json(command_json([os.path.join(ROOT, "scripts/cluster.sh"), "json"]))
        elif path == "/monitor/system":
            self.send_json({
                "ok": True,
                "hostname": platform.node(),
                "kernel": platform.release(),
                "machine": platform.machine(),
                "loadavg": os.getloadavg(),
                "memory": memory(),
            })
        elif path == "/readiness":
            self.send_json(command_json([os.path.join(ROOT, "scripts/readiness.sh"), "--json"]))
        elif path == "/manifest":
            self.send_json(command_json([os.path.join(ROOT, "scripts/manifest.sh"), "summary-json"]))
        elif path == "/actions":
            self.send_json(command_json([os.path.join(ROOT, "scripts/actions.sh"), "--json"]))
        elif path == "/stack":
            self.send_json(command_json([os.path.join(ROOT, "scripts/stack.sh"), "--json"]))
        elif path == "/shell":
            self.send_json(command_json([os.path.join(ROOT, "scripts/shell.sh"), "status", "--json"]))
        elif path == "/shell-plan":
            self.send_json(command_json([os.path.join(ROOT, "scripts/shell.sh"), "plan", "--json"]))
        elif path == "/core":
            self.send_json(command_json([os.path.join(ROOT, "scripts/core.sh"), "status", "--json"]))
        elif path == "/core-plan":
            self.send_json(command_json([os.path.join(ROOT, "scripts/core.sh"), "plan", "--json"]))
        elif path == "/core-snapshot":
            self.send_json(command_json([os.path.join(ROOT, "scripts/core.sh"), "snapshot", "--json"]))
        elif path == "/core-health":
            self.send_json(command_json([os.path.join(ROOT, "scripts/core.sh"), "health", "--json"]))
        elif path == "/core-observe":
            self.send_json(command_json([os.path.join(ROOT, "scripts/core.sh"), "observe", "--json"]))
        elif path == "/scheduler":
            self.send_json(command_json([os.path.join(ROOT, "scripts/scheduler.sh"), "status", "--json"]))
        elif path == "/context":
            self.send_json(command_json([os.path.join(ROOT, "scripts/context.sh"), "status", "--json"]))
        elif path == "/bus":
            self.send_json(command_json([os.path.join(ROOT, "scripts/core.sh"), "bus", "--json"]))
        elif path == "/experience":
            self.send_json(command_json([os.path.join(ROOT, "scripts/experience.sh"), "--json"]))
        elif path == "/shield":
            self.send_json(command_json([os.path.join(ROOT, "security/shield-status.sh"), "--json"]))
        elif path == "/shield-plan":
            self.send_json(command_json([os.path.join(ROOT, "security/shield-status.sh"), "plan", "--json"]))
        elif path == "/cyberspace":
            self.send_json(command_json([os.path.join(ROOT, "security/cyberspace.sh"), "mode", "--json"]))
        elif path == "/cyberspace-plan":
            self.send_json(command_json([os.path.join(ROOT, "bin/seven-daemon"), "cyberspace-plan", "--json"]))
        elif path == "/server-plan":
            self.send_json(command_json([os.path.join(ROOT, "server/seven-server.sh"), "plan", "--json"]))
        elif path == "/control":
            self.send_json(command_json([os.path.join(ROOT, "scripts/control-plane.sh"), "--json"]))
        elif path == "/b3":
            self.send_json(command_json([os.path.join(ROOT, "scripts/b3.sh"), "plan", "--json"]))
        elif path == "/daily":
            self.send_json(command_json([os.path.join(ROOT, "scripts/daily-driver.sh"), "status", "--json"]))
        elif path == "/events":
            self.send_json(command_json([os.path.join(ROOT, "scripts/events.sh"), "summary-json"]))
        elif path == "/insights":
            self.send_json(command_json([os.path.join(ROOT, "scripts/insights.sh"), "--json"]))
        elif path == "/deploy/status":
            self.send_json(command_json([os.path.join(ROOT, "server/seven-deploy.sh"), "status", "--json"]))
        elif path == "/deploy/inspect":
            self.send_json(command_json([os.path.join(ROOT, "server/seven-deploy.sh"), "inspect", project_path(), "--json"]))
        elif path == "/deploy/doctor":
            self.send_json(command_json([os.path.join(ROOT, "server/seven-deploy.sh"), "doctor", project_path(), "--json"]))
        elif path == "/deploy/services":
            self.send_json(command_json([os.path.join(ROOT, "server/seven-deploy.sh"), "services", "--json"]))
        elif path == "/deploy/panel":
            self.send_json(command_json([os.path.join(ROOT, "server/seven-deploy.sh"), "panel", "--json"]))
        elif path == "/deploy/domain":
            domain = query_value("domain", query_value("subject", "app.example.com"))
            target = query_value("target", "auto")
            public_ip = query_value("public_ip", query_value("public-ip", ""))
            tunnel_hostname = query_value("tunnel_hostname", query_value("tunnel-hostname", ""))
            extra = ["--target", target]
            if public_ip:
                extra.extend(["--public-ip", public_ip])
            if tunnel_hostname:
                extra.extend(["--tunnel-hostname", tunnel_hostname])
            self.send_json(command_json(deploy_command("domain", domain, *extra)))
        elif path == "/deploy/dns-check":
            domain = query_value("domain", query_value("subject", ""))
            expected_ip = query_value("expected_ip", query_value("expected-ip", ""))
            expected_cname = query_value("expected_cname", query_value("expected-cname", ""))
            extra = []
            if expected_ip:
                extra.extend(["--expected-ip", expected_ip])
            if expected_cname:
                extra.extend(["--expected-cname", expected_cname])
            self.send_json(command_json(deploy_command("dns-check", domain, *extra)))
        elif path == "/deploy/route-check":
            subject = query_value("subject", query_value("domain", query_value("project", "")))
            expected_ip = query_value("expected_ip", query_value("expected-ip", ""))
            expected_cname = query_value("expected_cname", query_value("expected-cname", ""))
            extra = []
            if expected_ip:
                extra.extend(["--expected-ip", expected_ip])
            if expected_cname:
                extra.extend(["--expected-cname", expected_cname])
            self.send_json(command_json(deploy_command("route-check", subject, *extra)))
        elif path == "/deploy/diagnose":
            subject = query_value("subject", query_value("domain", query_value("project", "")))
            expected_ip = query_value("expected_ip", query_value("expected-ip", ""))
            expected_cname = query_value("expected_cname", query_value("expected-cname", ""))
            extra = []
            if expected_ip:
                extra.extend(["--expected-ip", expected_ip])
            if expected_cname:
                extra.extend(["--expected-cname", expected_cname])
            self.send_json(command_json(deploy_command("diagnose", subject, *extra)))
        else:
            self.send_json({"ok": False, "error": "not found"}, status=404)

    def log_message(self, fmt, *args):
        print("seven-server:", fmt % args)

ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
PY
}

install_user_service() {
  log_info "Installing user service: $UNIT_FILE"
  if is_dry_run; then
    printf 'mkdir -p %q\n' "$UNIT_DIR"
    printf 'write %q\n' "$UNIT_FILE"
    printf 'systemctl --user daemon-reload\n'
    printf 'systemctl --user enable seven-server.service\n'
    return 0
  fi

  mkdir -p "$UNIT_DIR"
  cat > "$UNIT_FILE" <<EOF
[Unit]
Description=SevenOS local server API
After=network-online.target

[Service]
Type=simple
Environment=SEVENOS_ROOT=$ROOT_DIR
Environment=SEVENOS_SERVER_HOST=$HOST
Environment=SEVENOS_SERVER_PORT=$PORT
Environment=SEVENOS_SERVER_EXPOSE_UNSAFE=$ALLOW_UNSAFE_EXPOSE
PassEnvironment=WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE
ExecStart=$ROOT_DIR/server/seven-server.sh serve
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
EOF
  systemctl --user daemon-reload
  systemctl --user enable seven-server.service
  log_success "User service installed. Start it with: seven server start"
  log_warn "If systemd user services are unavailable, log out and back in, then retry."
}

action="${1:-status}"
shift || true
for arg in "$@"; do
  case "$arg" in
    --json|json) JSON_OUTPUT=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown server option: $arg"; usage; exit 1 ;;
  esac
done
case "$action" in
  serve|install-user-service|start|stop|logs)
    require_forge_profile "$action" || exit 1
    ;;
esac

case "$action" in
  status) status ;;
  plan) plan ;;
  doctor) doctor ;;
  serve) serve ;;
  install-user-service) install_user_service ;;
  start) run_cmd systemctl --user start seven-server.service ;;
  stop) run_cmd systemctl --user stop seven-server.service ;;
  logs) run_cmd journalctl --user -u seven-server.service -f ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown server action: $action"; usage; exit 1 ;;
esac
