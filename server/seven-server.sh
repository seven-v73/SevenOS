#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

HOST="${SEVENOS_SERVER_HOST:-127.0.0.1}"
PORT="${SEVENOS_SERVER_PORT:-7777}"
UNIT_DIR="$HOME/.config/systemd/user"
UNIT_FILE="$UNIT_DIR/seven-server.service"

usage() {
  cat <<'EOF'
SevenOS Server

Usage:
  seven server <action>
  ./server/seven-server.sh <action>

Actions:
  status                Show local server and deployment readiness
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
}

action="${1:-status}"
case "$action" in
  status) status ;;
  doctor) doctor ;;
  serve) serve ;;
  install-user-service) install_user_service ;;
  start) run_cmd systemctl --user start seven-server.service ;;
  stop) run_cmd systemctl --user stop seven-server.service ;;
  logs) run_cmd journalctl --user -u seven-server.service -f ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown server action: $action"; usage; exit 1 ;;
esac
