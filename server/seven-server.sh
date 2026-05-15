#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

HOST="${SEVENOS_SERVER_HOST:-127.0.0.1}"
PORT="${SEVENOS_SERVER_PORT:-7777}"
UNIT_DIR="$HOME/.config/systemd/user"
UNIT_FILE="$UNIT_DIR/seven-server.service"
JSON_OUTPUT=0

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
EOF
}

json_string() {
  python -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))'
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

status() {
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    local service go_state podman_state caddy_state jq_state deploy_state bind_state
    service="$(service_state)"
    go_state="$(command_state go)"
    podman_state="$(command_state podman)"
    caddy_state="$(command_state caddy)"
    jq_state="$(command_state jq)"
    deploy_state="$([[ -x "$ROOT_DIR/server/seven-deploy.sh" ]] && printf OK || printf MISS)"
    bind_state="LOCAL"
    [[ "$HOST" != "127.0.0.1" && "$HOST" != "localhost" ]] && bind_state="EXPOSED"

    printf '{'
    printf '"schema":"sevenos.server.v1",'
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
    printf '"endpoints":["/health","/state","/status","/welcome","/welcome-plan","/session","/identity","/profiles","/profile-gaps","/profile-plan","/windows","/windows-plan","/installer","/installer-plan","/packages","/packages-plan","/monitor/system","/readiness","/manifest","/actions","/stack","/shell","/shell-plan","/core","/core-plan","/core-snapshot","/bus","/experience","/shield","/shield-plan","/server-plan","/control","/events","/insights"],'
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
    printf 'service\t%s\tSeven Server user service\tseven server install-user-service\n' "$service"
    printf 'service-start\t%s\tSeven Server runtime\tseven server start\n' "$([[ "$service" == READY ]] && printf MISS || printf OK)"
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
  export SEVENOS_ROOT="$ROOT_DIR" SEVENOS_SERVER_HOST="$HOST" SEVENOS_SERVER_PORT="$PORT"
  log_info "Starting SevenOS local API at http://$HOST:$PORT"
  python - <<'PY'
import json
import os
import platform
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.environ["SEVENOS_ROOT"]
HOST = os.environ.get("SEVENOS_SERVER_HOST", "127.0.0.1")
PORT = int(os.environ.get("SEVENOS_SERVER_PORT", "7777"))

def command_json(command):
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False)
    if result.returncode != 0:
        return {"ok": False, "error": result.stderr.strip() or result.stdout.strip()}
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return {"ok": True, "output": result.stdout.strip()}

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
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/health":
            self.send_json({"ok": True, "service": "seven-server", "bind": f"{HOST}:{PORT}"})
        elif self.path == "/state":
            self.send_json(command_json([os.path.join(ROOT, "scripts/state.sh"), "--json"]))
        elif self.path == "/status":
            self.send_json(command_json([os.path.join(ROOT, "bin/seven"), "status", "--json"]))
        elif self.path == "/welcome":
            self.send_json(command_json([os.path.join(ROOT, "bin/seven-welcome"), "status", "--json"]))
        elif self.path == "/welcome-plan":
            self.send_json(command_json([os.path.join(ROOT, "bin/seven-welcome"), "plan", "--json"]))
        elif self.path == "/session":
            self.send_json(command_json([os.path.join(ROOT, "bin/seven-session-status"), "--json"]))
        elif self.path == "/identity":
            self.send_json(command_json([os.path.join(ROOT, "scripts/identity.sh"), "--json"]))
        elif self.path == "/profiles":
            self.send_json(command_json([os.path.join(ROOT, "bin/seven"), "profile", "status", "--json"]))
        elif self.path == "/profile-gaps":
            self.send_json(command_json([os.path.join(ROOT, "bin/seven"), "profile", "gaps", "--json"]))
        elif self.path == "/profile-plan":
            self.send_json(command_json([os.path.join(ROOT, "bin/seven"), "profile", "plan", "--json"]))
        elif self.path == "/windows":
            self.send_json(command_json([os.path.join(ROOT, "bin/seven-windows-assistant"), "status", "--json"]))
        elif self.path == "/windows-plan":
            self.send_json(command_json([os.path.join(ROOT, "bin/seven-windows-assistant"), "plan", "--json"]))
        elif self.path == "/installer":
            self.send_json(command_json([os.path.join(ROOT, "scripts/installer-stack.sh"), "status", "--json"]))
        elif self.path == "/installer-plan":
            self.send_json(command_json([os.path.join(ROOT, "scripts/installer-stack.sh"), "plan", "--json"]))
        elif self.path == "/packages":
            self.send_json(command_json([os.path.join(ROOT, "bin/sevenpkg"), "status", "--json"]))
        elif self.path == "/packages-plan":
            self.send_json(command_json([os.path.join(ROOT, "bin/sevenpkg"), "plan", "--json"]))
        elif self.path == "/monitor/system":
            self.send_json({
                "ok": True,
                "hostname": platform.node(),
                "kernel": platform.release(),
                "machine": platform.machine(),
                "loadavg": os.getloadavg(),
                "memory": memory(),
            })
        elif self.path == "/readiness":
            self.send_json(command_json([os.path.join(ROOT, "scripts/readiness.sh"), "--json"]))
        elif self.path == "/manifest":
            self.send_json(command_json([os.path.join(ROOT, "scripts/manifest.sh"), "summary-json"]))
        elif self.path == "/actions":
            self.send_json(command_json([os.path.join(ROOT, "scripts/actions.sh"), "--json"]))
        elif self.path == "/stack":
            self.send_json(command_json([os.path.join(ROOT, "scripts/stack.sh"), "--json"]))
        elif self.path == "/shell":
            self.send_json(command_json([os.path.join(ROOT, "scripts/shell.sh"), "status", "--json"]))
        elif self.path == "/shell-plan":
            self.send_json(command_json([os.path.join(ROOT, "scripts/shell.sh"), "plan", "--json"]))
        elif self.path == "/core":
            self.send_json(command_json([os.path.join(ROOT, "scripts/core.sh"), "status", "--json"]))
        elif self.path == "/core-plan":
            self.send_json(command_json([os.path.join(ROOT, "scripts/core.sh"), "plan", "--json"]))
        elif self.path == "/core-snapshot":
            self.send_json(command_json([os.path.join(ROOT, "scripts/core.sh"), "snapshot", "--json"]))
        elif self.path == "/bus":
            self.send_json(command_json([os.path.join(ROOT, "scripts/core.sh"), "bus", "--json"]))
        elif self.path == "/experience":
            self.send_json(command_json([os.path.join(ROOT, "scripts/experience.sh"), "--json"]))
        elif self.path == "/shield":
            self.send_json(command_json([os.path.join(ROOT, "security/shield-status.sh"), "--json"]))
        elif self.path == "/shield-plan":
            self.send_json(command_json([os.path.join(ROOT, "security/shield-status.sh"), "plan", "--json"]))
        elif self.path == "/server-plan":
            self.send_json(command_json([os.path.join(ROOT, "server/seven-server.sh"), "plan", "--json"]))
        elif self.path == "/control":
            self.send_json(command_json([os.path.join(ROOT, "scripts/control-plane.sh"), "--json"]))
        elif self.path == "/events":
            self.send_json(command_json([os.path.join(ROOT, "scripts/events.sh"), "summary-json"]))
        elif self.path == "/insights":
            self.send_json(command_json([os.path.join(ROOT, "scripts/insights.sh"), "--json"]))
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
