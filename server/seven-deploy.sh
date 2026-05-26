#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"
JSON_OUTPUT=0
REQUIRED_PROFILE="forge"
PUBLISH_DOMAIN=""
PUBLISH_PROVIDER="auto"
PUBLISH_TARGET="auto"
PUBLIC_IP=""
TUNNEL_HOSTNAME=""
EXPECTED_IP=""
EXPECTED_CNAME=""
PUBLISH_PORT=""
PUBLISH_BUILD=1
SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
DEPLOY_STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/sevenos/deploy"

usage() {
  cat <<'EOF'
SevenOS Deploy

Usage:
  seven deploy [project]
  seven deploy <action> [project]
  ./server/seven-deploy.sh <action> [project]

Actions:
  plan       Detect stack and write a non-destructive deployment plan
  inspect    Inspect a project and print the natural dev/deploy contract
  dev        Show the natural development loop for a project
  doctor     Check project-specific development/deployment tools
  publish    Build a durable local snapshot and optional public tunnel
  domain     Explain DNS records for tunnel, VPS or public-IP hosting
  dns-check  Check whether DNS currently points to the expected VPS IP or tunnel
  route-check Check local and public reachability for a hosted app or domain
  diagnose   Run one hosting diagnosis for a project or domain
  unpublish  Stop a published project
  start      Start a published project
  stop       Stop a published project
  restart    Restart a published project
  logs       Show a published project logs
  versions   Show published versions for a project
  rollback   Roll back a project to a previous version
  remove     Remove service metadata and snapshots
  services   Show published services
  panel      Show the deployment management panel contract
  detect     Print detected project stack
  status     Show generated deployment plans
  status --json
  logs       Show known deployment log paths

Examples:
  seven deploy ./my-project
  seven deploy plan ./my-project
  seven deploy inspect ./my-project --json
  seven deploy dev .
  seven deploy doctor .
  seven deploy publish . --provider cloudflare
  seven deploy publish . --domain app.example.com
  seven deploy domain app.example.com --target tunnel
  seven deploy domain app.example.com --target vps --public-ip 203.0.113.10
  seven deploy dns-check app.example.com --expected-ip 203.0.113.10
  seven deploy dns-check app.example.com --expected-cname <tunnel-id>.cfargotunnel.com
  seven deploy route-check my-project
  seven deploy route-check app.example.com
  seven deploy diagnose my-project
  seven deploy publish . --no-build
  seven deploy versions my-project
  seven deploy rollback my-project
  seven deploy remove my-project
  seven deploy services --json
  seven deploy detect ./my-project
EOF
}

timestamp_id() {
  date -u +%Y%m%dT%H%M%S%NZ
}

json_string() {
  python -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))'
}

json_array() {
  python -c 'import json,sys; print(json.dumps([line for line in sys.stdin.read().splitlines() if line]))'
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
    printf '{"schema":"sevenos.profile-gate.v1","state":"FORBIDDEN","required_profile":"forge","active_profile":%s,"surface":"deploy","action":%s,"reason":"SevenOS deployment and hosting tools are available only inside the Forge mini OS.","next":[{"command":"seven profile activate forge","reason":"Switch to the Forge development mini OS."},{"command":"seven-terminal forge","reason":"Open a Forge terminal for deployment work."}]}\n' \
      "$(printf '%s' "$profile" | json_string)" \
      "$(printf '%s' "$action" | json_string)"
  else
    log_error "SevenOS Deploy is available only in Forge. Active mini OS: $profile"
    printf 'Switch with: seven profile activate forge\n' >&2
    printf 'Or open:     seven-terminal forge\n' >&2
  fi
  return 1
}

project_name() {
  basename "$(cd -- "$1" && pwd)"
}

project_slug() {
  local name="$1"
  printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g; s/--*/-/g; s/^-//; s/-$//'
}

default_port() {
  local slug="$1"
  SLUG="$slug" python - <<'PY'
import os
print(18000 + (sum(ord(ch) for ch in os.environ["SLUG"]) % 2000))
PY
}

port_available() {
  local port="$1"
  PORT="$port" python - <<'PY'
import os
import socket
import sys

sock = socket.socket()
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
try:
    sock.bind(("127.0.0.1", int(os.environ["PORT"])))
except OSError:
    sys.exit(1)
finally:
    sock.close()
PY
}

free_port() {
  local preferred="$1"
  PORT="$preferred" python - <<'PY'
import os
import socket

start = int(os.environ["PORT"])
for port in range(start, 20000):
    sock = socket.socket()
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        sock.bind(("127.0.0.1", port))
    except OSError:
        sock.close()
        continue
    sock.close()
    print(port)
    break
else:
    print(start)
PY
}

detect_stack() {
  local project_dir="$1"
  local detected=()

  [[ -f "$project_dir/package.json" ]] && detected+=("node")
  [[ -f "$project_dir/go.mod" ]] && detected+=("go")
  [[ -f "$project_dir/composer.json" && -f "$project_dir/artisan" ]] && detected+=("laravel")
  [[ -f "$project_dir/pubspec.yaml" ]] && detected+=("flutter")
  [[ -f "$project_dir/Dockerfile" || -f "$project_dir/Containerfile" || -f "$project_dir/docker-compose.yml" || -f "$project_dir/compose.yaml" ]] && detected+=("container")

  if [[ "${#detected[@]}" -eq 0 ]]; then
    printf 'static'
  else
    printf '%s\n' "${detected[@]}" | paste -sd ',' -
  fi
}

plan_steps() {
  local stack="$1"

  IFS=',' read -ra stacks <<<"$stack"
  for item in "${stacks[@]}"; do
    case "$item" in
      node)
        printf 'npm install\n'
        printf 'npm run build --if-present\n'
        printf 'podman run rootless Node runtime or Caddy static handoff\n'
        ;;
      go)
        printf 'go build ./...\n'
        printf 'install compiled service under user runtime\n'
        ;;
      laravel)
        printf 'composer install --no-dev\n'
        printf 'php artisan config:cache\n'
        printf 'prepare PHP runtime and database variables\n'
        ;;
      flutter)
        printf 'flutter build web\n'
        printf 'serve build/web through Caddy\n'
        ;;
      container)
        printf 'podman build or podman compose up\n'
        printf 'attach logs and health checks\n'
        ;;
      static)
        printf 'serve static directory through Caddy\n'
        ;;
    esac
  done

  printf 'assign local port\n'
  printf 'write Caddy route when enabled\n'
  printf 'register monitoring endpoint\n'
}

project_contract() {
  local project_dir="$1"
  project_dir="$(cd -- "$project_dir" && pwd)"
  PROJECT_DIR="$project_dir" ROOT_DIR="$ROOT_DIR" python - <<'PY'
import json
import os
import shutil
from pathlib import Path

project = Path(os.environ["PROJECT_DIR"])
root = Path(os.environ["ROOT_DIR"])
name = project.name

def has(path):
    return (project / path).exists()

stacks = []
if has("package.json"):
    stacks.append("node")
if has("go.mod"):
    stacks.append("go")
if has("composer.json") and has("artisan"):
    stacks.append("laravel")
if has("pubspec.yaml"):
    stacks.append("flutter")
if any(has(item) for item in ("Dockerfile", "Containerfile", "docker-compose.yml", "compose.yaml")):
    stacks.append("container")
if not stacks:
    stacks.append("static")

package_scripts = {}
package_manager = ""
if has("package.json"):
    try:
        package = json.loads((project / "package.json").read_text(encoding="utf-8"))
        package_scripts = package.get("scripts", {}) if isinstance(package.get("scripts"), dict) else {}
    except Exception:
        package_scripts = {}
    if has("pnpm-lock.yaml"):
        package_manager = "pnpm"
    elif has("yarn.lock"):
        package_manager = "yarn"
    elif has("bun.lockb") or has("bun.lock"):
        package_manager = "bun"
    else:
        package_manager = "npm"

required = []
dev_commands = []
build_commands = []
preview_commands = []

if "node" in stacks:
    required.append(package_manager or "npm")
    pm = package_manager or "npm"
    install = "install" if pm == "npm" else "install"
    dev_script = "dev" if "dev" in package_scripts else "start" if "start" in package_scripts else ""
    build_script = "build" if "build" in package_scripts else ""
    dev_commands.append(f"{pm} {install}")
    if dev_script:
        dev_commands.append(f"{pm} run {dev_script}" if pm in {"npm", "pnpm", "yarn", "bun"} else f"{pm} {dev_script}")
    if build_script:
        build_commands.append(f"{pm} run {build_script}")
if "go" in stacks:
    required.append("go")
    dev_commands.append("go run .")
    build_commands.append("go build ./...")
if "laravel" in stacks:
    required.extend(["php", "composer"])
    dev_commands.extend(["composer install", "php artisan serve"])
    build_commands.append("php artisan config:cache")
if "flutter" in stacks:
    required.append("flutter")
    dev_commands.append("flutter run -d web-server")
    build_commands.append("flutter build web")
if "container" in stacks:
    required.append("podman")
    if has("compose.yaml") or has("docker-compose.yml"):
        dev_commands.append("podman compose up")
    else:
        build_commands.append("podman build .")
if stacks == ["static"]:
    required.append("python")
    preview_commands.append("python -m http.server 4173")

required.extend(["jq", "caddy"])
seen = set()
required = [item for item in required if not (item in seen or seen.add(item))]
missing = [item for item in required if shutil.which(item) is None]

plan_dir = root / "out" / "deploy" / name
payload = {
    "schema": "sevenos.deploy.project.v1",
    "state": "ready" if not missing else "partial",
    "project": name,
    "path": str(project),
    "stack": ",".join(stacks),
    "stacks": stacks,
    "package_manager": package_manager,
    "package_scripts": sorted(package_scripts.keys()),
    "commands": {
        "dev": dev_commands,
        "build": build_commands,
        "preview": preview_commands,
        "plan": f"seven deploy plan {project}",
        "publish": f"seven deploy publish {project}",
        "doctor": f"seven deploy doctor {project}",
        "status": "seven deploy status --json",
    },
    "tools": [{"key": item, "state": "OK" if item not in missing else "MISS"} for item in required],
    "missing": missing,
    "outputs": {
        "plan_txt": str((plan_dir / "plan.txt").relative_to(root)),
        "plan_json": str((plan_dir / "plan.json").relative_to(root)),
    },
    "server": {
        "local_api": "http://127.0.0.1:7777",
        "status_endpoint": "/deploy/status",
    },
    "next": [] if not missing else [{
        "command": "seven improve deployment --apply --yes",
        "reason": "Install missing deployment tools for this project.",
    }],
}
print(json.dumps(payload, indent=2))
PY
}

write_plan() {
  local project_dir="$1"
  local name stack output_dir plan_file plan_json

  project_dir="$(cd -- "$project_dir" && pwd)"
  name="$(project_name "$project_dir")"
  stack="$(detect_stack "$project_dir")"
  output_dir="$ROOT_DIR/out/deploy/$name"
  plan_file="$output_dir/plan.txt"
  plan_json="$output_dir/plan.json"

  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    project_contract "$project_dir"
    if ! is_dry_run; then
      mkdir -p "$output_dir"
      project_contract "$project_dir" > "$plan_json"
      {
        printf 'project=%s\n' "$name"
        printf 'path=%s\n' "$project_dir"
        printf 'stack=%s\n' "$stack"
        printf 'created=%s\n' "$(date -Iseconds)"
        printf 'plan_json=%s\n' "${plan_json#$ROOT_DIR/}"
        printf '\nsteps:\n'
        plan_steps "$stack" | sed 's/^/- /'
      } > "$plan_file"
    fi
    return 0
  fi

  printf 'SevenOS Deployment Plan\n'
  printf '=======================\n'
  printf 'project: %s\n' "$name"
  printf 'path:    %s\n' "$project_dir"
  printf 'stack:   %s\n\n' "$stack"
  printf 'steps:\n'
  plan_steps "$stack" | sed 's/^/  - /'

  if is_dry_run; then
    printf '\nDry-run: plan would be written to %s\n' "$plan_file"
    return 0
  fi

  mkdir -p "$output_dir"
  {
    printf 'project=%s\n' "$name"
    printf 'path=%s\n' "$project_dir"
    printf 'stack=%s\n' "$stack"
    printf 'created=%s\n' "$(date -Iseconds)"
    printf 'plan_json=%s\n' "${plan_json#$ROOT_DIR/}"
    printf '\nsteps:\n'
    plan_steps "$stack" | sed 's/^/- /'
  } > "$plan_file"
  project_contract "$project_dir" > "$plan_json"

  log_success "Deployment plan written to $plan_file"
}

inspect_project() {
  local project_dir="$1"
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    project_contract "$project_dir"
    return 0
  fi

  PROJECT_JSON="$(project_contract "$project_dir")" python - <<'PY'
import json
import os

data = json.loads(os.environ["PROJECT_JSON"])
print("SevenOS Deploy Inspect")
print("======================")
print(f"Project: {data['project']}")
print(f"Path:    {data['path']}")
print(f"Stack:   {data['stack']}")
print(f"State:   {data['state']}")
print()
print("Natural dev loop:")
for command in data.get("commands", {}).get("dev", []):
    print(f"  - {command}")
for command in data.get("commands", {}).get("build", []):
    print(f"  - {command}")
for command in data.get("commands", {}).get("preview", []):
    print(f"  - {command}")
print()
if data.get("missing"):
    print("Missing tools:")
    for item in data["missing"]:
        print(f"  - {item}")
    print("Fix: seven improve deployment --apply --yes")
else:
    print("Tools: OK")
print()
print(f"Plan: {data['commands']['plan']}")
print(f"API:  {data['server']['local_api']}{data['server']['status_endpoint']}")
PY
}

dev_loop() {
  local project_dir="$1"
  inspect_project "$project_dir"
}

doctor_project() {
  local project_dir="$1"
  local payload missing_count
  payload="$(project_contract "$project_dir")"
  missing_count="$(PAYLOAD="$payload" python - <<'PY'
import json, os
print(len(json.loads(os.environ["PAYLOAD"]).get("missing", [])))
PY
)"

  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    printf '%s\n' "$payload"
  else
    inspect_project "$project_dir"
  fi
  [[ "$missing_count" -eq 0 ]]
}

snapshot_source() {
  local project_dir="$1"
  for candidate in dist build public out; do
    if [[ -d "$project_dir/$candidate" ]]; then
      printf '%s\n' "$project_dir/$candidate"
      return 0
    fi
  done
  printf '%s\n' "$project_dir"
}

build_project() {
  local project_dir="$1" log_file="$2"
  : > "$log_file"

  if [[ -f "$project_dir/package.json" ]]; then
    PROJECT_DIR="$project_dir" python - <<'PY' > "$log_file.command"
import json
import os
from pathlib import Path

project = Path(os.environ["PROJECT_DIR"])
package = json.loads((project / "package.json").read_text(encoding="utf-8"))
scripts = package.get("scripts", {})
if "build" not in scripts:
    print("")
elif (project / "pnpm-lock.yaml").exists():
    print("pnpm run build")
elif (project / "yarn.lock").exists():
    print("yarn run build")
elif (project / "bun.lockb").exists() or (project / "bun.lock").exists():
    print("bun run build")
else:
    print("npm run build")
PY
    local command_line
    command_line="$(cat "$log_file.command")"
    rm -f "$log_file.command"
    if [[ -n "$command_line" ]]; then
      (cd "$project_dir" && bash -lc "$command_line") >"$log_file" 2>&1
      return $?
    fi
  fi

  if [[ -f "$project_dir/go.mod" ]]; then
    (cd "$project_dir" && go build ./...) >"$log_file" 2>&1
    return $?
  fi

  if [[ -f "$project_dir/pubspec.yaml" ]] && command -v flutter >/dev/null 2>&1; then
    (cd "$project_dir" && flutter build web) >"$log_file" 2>&1
    return $?
  fi

  printf 'No build command detected; snapshot source will be used as-is.\n' > "$log_file"
  return 0
}

write_metadata() {
  local metadata_file="$1" name="$2" slug="$3" project_dir="$4" snapshot_dir="$5" port="$6" provider="$7" domain="$8" state="$9" public_url="${10:-}" domain_config="${11:-}" build_state="${12:-skipped}" build_log="${13:-}" version_id="${14:-current}" dns_plan="${15:-}"
  python - "$metadata_file" "$name" "$slug" "$project_dir" "$snapshot_dir" "$port" "$provider" "$domain" "$state" "$public_url" "$domain_config" "$build_state" "$build_log" "$version_id" "$dns_plan" <<'PY'
import json
import sys
from datetime import datetime, timezone

metadata_file, name, slug, project_dir, snapshot_dir, port, provider, domain, state, public_url, domain_config, build_state, build_log, version_id, dns_plan = sys.argv[1:]
payload = {
    "schema": "sevenos.deploy.service.v1",
    "name": name,
    "slug": slug,
    "project": project_dir,
    "snapshot": snapshot_dir,
    "artifact": snapshot_dir,
    "version": version_id,
    "port": int(port),
    "provider": provider,
    "domain": domain,
    "state": state,
    "local_url": f"http://127.0.0.1:{port}",
    "public_url": public_url,
    "domain_config": domain_config,
    "dns_plan": dns_plan,
    "build": {
        "state": build_state,
        "log": build_log,
    },
    "app_unit": f"seven-deploy-{slug}.service",
    "tunnel_unit": f"seven-deploy-{slug}-tunnel.service",
    "actions": {
        "start": f"seven deploy start {slug}",
        "stop": f"seven deploy stop {slug}",
        "restart": f"seven deploy restart {slug}",
        "logs": f"seven deploy logs {slug}",
        "versions": f"seven deploy versions {slug}",
        "rollback": f"seven deploy rollback {slug} <version>",
        "unpublish": f"seven deploy unpublish {slug}",
        "remove": f"seven deploy remove {slug}",
    },
    "next": [],
    "updated": datetime.now(timezone.utc).isoformat(),
}
if state == "local-missing-tunnel":
    payload["next"].append({
        "command": "seven improve deployment --apply --yes",
        "reason": "Install cloudflared to generate a public URL without a custom domain.",
    })
elif state == "domain-ready-local":
    payload["next"].append({
        "command": f"configure DNS/tunnel for {domain}",
        "reason": "The local service is durable; attach the domain through your DNS/tunnel policy.",
    })
with open(metadata_file, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
    handle.write("\n")
print(json.dumps(payload, indent=2))
PY
}

cloudflared_url() {
  local unit="$1"
  journalctl --user -u "$unit" -n 160 --no-pager 2>/dev/null |
    sed -n 's/.*https:\\/\\/\\([^ ]*trycloudflare.com\\).*/https:\\/\\/\\1/p' |
    tail -n 1
}

wait_local_url() {
  local port="$1"
  PORT="$port" python - <<'PY'
import os
import time
import urllib.request
import sys

url = f"http://127.0.0.1:{os.environ['PORT']}/"
for _ in range(30):
    try:
        with urllib.request.urlopen(url, timeout=0.5) as response:
            if 200 <= response.status < 500:
                sys.exit(0)
    except Exception:
        time.sleep(0.1)
sys.exit(1)
PY
}

domain_plan_json() {
  local domain="$1" target="$2" public_ip="$3" tunnel_hostname="$4"
  DOMAIN="$domain" TARGET="$target" PUBLIC_IP="$public_ip" TUNNEL_HOSTNAME="$tunnel_hostname" python - <<'PY'
import json
import os

domain = os.environ["DOMAIN"].strip().rstrip(".")
target = os.environ["TARGET"] or "auto"
public_ip = os.environ["PUBLIC_IP"].strip()
tunnel_hostname = os.environ["TUNNEL_HOSTNAME"].strip().rstrip(".")

if target == "auto":
    target = "tunnel" if not public_ip else "vps"

records = []
next_steps = []
warnings = []
state = "ready"

if not domain:
    state = "missing-domain"
    warnings.append("Provide a domain, for example: seven deploy domain app.example.com --target tunnel")
elif target in {"vps", "public-ip"}:
    if public_ip:
        records.append({
            "type": "A" if ":" not in public_ip else "AAAA",
            "name": domain,
            "value": public_ip,
            "ttl": "auto",
            "purpose": "Point the purchased domain to the VPS or public SevenOS host.",
        })
        next_steps.extend([
            f"Open ports 80 and 443 on the target host for {domain}.",
            f"Run: seven deploy publish . --domain {domain} --target {target}",
            "Let Caddy or the SevenOS web gateway issue TLS for the domain.",
        ])
    else:
        state = "needs-public-ip"
        next_steps.append(f"Find your VPS public IP, then run: seven deploy domain {domain} --target {target} --public-ip <ip>")
        warnings.append("A domain cannot point to a VPS without the VPS public IPv4/IPv6 address.")
elif target in {"tunnel", "cloudflare"}:
    if tunnel_hostname:
        records.append({
            "type": "CNAME",
            "name": domain,
            "value": tunnel_hostname,
            "ttl": "auto",
            "purpose": "Point the purchased domain to the tunnel hostname.",
        })
        next_steps.extend([
            f"Create the CNAME at your DNS provider for {domain}.",
            f"Run: seven deploy publish . --domain {domain} --provider cloudflare",
        ])
    else:
        state = "needs-tunnel-hostname"
        next_steps.extend([
            "Use Cloudflare Tunnel for a personal SevenOS machine without fixed public IP.",
            "For a stable purchased domain, create/use a named tunnel and get its CNAME target.",
            f"Then run: seven deploy domain {domain} --target tunnel --tunnel-hostname <tunnel-id>.cfargotunnel.com",
        ])
        warnings.append("A random trycloudflare.com quick tunnel is useful for preview links, but a purchased domain should use a stable named tunnel/CNAME target.")
else:
    state = "unknown-target"
    warnings.append(f"Unknown target: {target}. Use tunnel, vps or public-ip.")

print(json.dumps({
    "schema": "sevenos.deploy.domain.v1",
    "state": state,
    "domain": domain,
    "target": target,
    "records": records,
    "next": next_steps,
    "warnings": warnings,
    "examples": {
        "personal_machine": f"seven deploy domain {domain or 'app.example.com'} --target tunnel --tunnel-hostname <tunnel-id>.cfargotunnel.com",
        "vps": f"seven deploy domain {domain or 'app.example.com'} --target vps --public-ip 203.0.113.10",
        "publish": f"seven deploy publish . --domain {domain or 'app.example.com'}",
    },
}, indent=2))
PY
}

show_domain_plan() {
  local domain="$1"
  local target="$PUBLISH_TARGET"
  [[ "$target" == "auto" && "$PUBLISH_PROVIDER" != "auto" ]] && target="$PUBLISH_PROVIDER"
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    domain_plan_json "$domain" "$target" "$PUBLIC_IP" "$TUNNEL_HOSTNAME"
    return 0
  fi
  DOMAIN_PLAN_JSON="$(domain_plan_json "$domain" "$target" "$PUBLIC_IP" "$TUNNEL_HOSTNAME")" python - <<'PY'
import json, os
data = json.loads(os.environ["DOMAIN_PLAN_JSON"])
print("SevenOS Domain Plan")
print("===================")
print(f"Domain: {data.get('domain') or '<missing>'}")
print(f"Target: {data.get('target')}")
print(f"State:  {data.get('state')}")
if data.get("records"):
    print()
    print("DNS records:")
    for record in data["records"]:
        print(f"  {record['type']:<5} {record['name']} -> {record['value']}")
if data.get("warnings"):
    print()
    print("Warnings:")
    for item in data["warnings"]:
        print(f"  - {item}")
if data.get("next"):
    print()
    print("Next:")
    for item in data["next"]:
        print(f"  - {item}")
PY
}

dns_check_json() {
  local domain="$1" expected_ip="$2" expected_cname="$3"
  DOMAIN="$domain" EXPECTED_IP="$expected_ip" EXPECTED_CNAME="$expected_cname" python - <<'PY'
import json
import os
import shutil
import socket
import subprocess

domain = os.environ["DOMAIN"].strip().rstrip(".")
expected_ip = os.environ["EXPECTED_IP"].strip()
expected_cname = os.environ["EXPECTED_CNAME"].strip().rstrip(".")
records = {"A": [], "AAAA": [], "CNAME": []}
warnings = []
next_steps = []

def dig(record_type):
    if not shutil.which("dig"):
        return []
    result = subprocess.run(
        ["dig", "+short", record_type, domain],
        text=True,
        capture_output=True,
        check=False,
        timeout=4,
    )
    values = []
    for raw in result.stdout.splitlines():
        value = raw.strip().rstrip(".")
        if value:
            values.append(value)
    return values

if domain:
    records["A"] = dig("A")
    records["AAAA"] = dig("AAAA")
    records["CNAME"] = dig("CNAME")
    if not shutil.which("dig"):
        warnings.append("dig is not installed; SevenOS used socket resolution and cannot verify CNAME.")
        try:
            infos = socket.getaddrinfo(domain, None)
            ips = sorted({item[4][0] for item in infos})
            records["A"] = [ip for ip in ips if ":" not in ip]
            records["AAAA"] = [ip for ip in ips if ":" in ip]
        except socket.gaierror:
            pass
else:
    warnings.append("Provide a domain, for example: seven deploy dns-check app.example.com --expected-ip 203.0.113.10")

matches = []
if expected_ip:
    matches.append(expected_ip in records["A"] or expected_ip in records["AAAA"])
if expected_cname:
    cname_values = {value.rstrip(".") for value in records["CNAME"]}
    matches.append(expected_cname in cname_values)

if not domain:
    state = "missing-domain"
elif matches and all(matches):
    state = "ready"
elif expected_ip or expected_cname:
    state = "mismatch"
    if expected_ip:
        next_steps.append(f"Create or update A/AAAA for {domain} to {expected_ip}.")
    if expected_cname:
        next_steps.append(f"Create or update CNAME for {domain} to {expected_cname}.")
    next_steps.append("DNS propagation can take a few minutes depending on TTL and provider cache.")
elif any(records.values()):
    state = "resolved"
else:
    state = "empty"
    next_steps.append("Create DNS records first, then run this check again.")

print(json.dumps({
    "schema": "sevenos.deploy.dns-check.v1",
    "state": state,
    "domain": domain,
    "expected": {
        "ip": expected_ip,
        "cname": expected_cname,
    },
    "records": records,
    "warnings": warnings,
    "next": next_steps,
}, indent=2))
PY
}

show_dns_check() {
  local domain="$1"
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    dns_check_json "$domain" "$EXPECTED_IP" "$EXPECTED_CNAME"
    return 0
  fi
  DNS_CHECK_JSON="$(dns_check_json "$domain" "$EXPECTED_IP" "$EXPECTED_CNAME")" python - <<'PY'
import json, os
data = json.loads(os.environ["DNS_CHECK_JSON"])
print("SevenOS DNS Check")
print("=================")
print(f"Domain: {data.get('domain') or '<missing>'}")
print(f"State:  {data.get('state')}")
records = data.get("records", {})
for key in ("A", "AAAA", "CNAME"):
    values = records.get(key) or []
    if values:
        print(f"{key}:")
        for value in values:
            print(f"  - {value}")
if data.get("warnings"):
    print()
    print("Warnings:")
    for item in data["warnings"]:
        print(f"  - {item}")
if data.get("next"):
    print()
    print("Next:")
    for item in data["next"]:
        print(f"  - {item}")
PY
}

route_check_json() {
  local subject="$1"
  SUBJECT="$subject" DEPLOY_STATE_DIR="$DEPLOY_STATE_DIR" EXPECTED_IP="$EXPECTED_IP" EXPECTED_CNAME="$EXPECTED_CNAME" python - <<'PY'
import json
import os
import shutil
import socket
import ssl
import subprocess
import urllib.error
import urllib.request
from pathlib import Path

subject = os.environ["SUBJECT"].strip().rstrip(".")
base = Path(os.environ["DEPLOY_STATE_DIR"])
expected_ip = os.environ["EXPECTED_IP"].strip()
expected_cname = os.environ["EXPECTED_CNAME"].strip().rstrip(".")

def load_service():
    if not base.is_dir():
        return {}
    for metadata in sorted(base.glob("*/service.json")):
        try:
            item = json.loads(metadata.read_text(encoding="utf-8"))
        except Exception:
            continue
        keys = {
            str(item.get("slug", "")).rstrip("."),
            str(item.get("name", "")).rstrip("."),
            str(item.get("domain", "")).rstrip("."),
        }
        if subject in keys:
            return item
    return {}

def dig(record_type, domain):
    if not domain or not shutil.which("dig"):
        return []
    try:
        result = subprocess.run(
            ["dig", "+short", record_type, domain],
            text=True,
            capture_output=True,
            check=False,
            timeout=4,
        )
    except Exception:
        return []
    return [line.strip().rstrip(".") for line in result.stdout.splitlines() if line.strip()]

def resolve(domain):
    records = {"A": dig("A", domain), "AAAA": dig("AAAA", domain), "CNAME": dig("CNAME", domain)}
    if not shutil.which("dig") and domain:
        try:
            infos = socket.getaddrinfo(domain, None)
            ips = sorted({item[4][0] for item in infos})
            records["A"] = [ip for ip in ips if ":" not in ip]
            records["AAAA"] = [ip for ip in ips if ":" in ip]
        except socket.gaierror:
            pass
    return records

def check_url(url):
    if not url:
        return {"url": url, "ok": False, "status": 0, "error": "missing-url"}
    request = urllib.request.Request(url, method="GET", headers={"User-Agent": "SevenOS-Deploy-RouteCheck/1"})
    try:
        context = ssl.create_default_context()
        with urllib.request.urlopen(request, timeout=5, context=context) as response:
            return {"url": url, "ok": 200 <= response.status < 500, "status": response.status, "error": ""}
    except urllib.error.HTTPError as exc:
        return {"url": url, "ok": 200 <= exc.code < 500, "status": exc.code, "error": ""}
    except Exception as exc:
        return {"url": url, "ok": False, "status": 0, "error": str(exc)}

service = load_service()
domain = str(service.get("domain") or ("" if service else subject)).rstrip(".")
local_url = service.get("local_url", "")
public_url = service.get("public_url", "")
if not public_url and domain and "." in domain:
    public_url = f"https://{domain}"

records = resolve(domain if "." in domain else "")
checks = {
    "local": check_url(local_url) if local_url else {"url": "", "ok": False, "status": 0, "error": "no-local-service-metadata"},
    "public_https": check_url(public_url) if public_url else {"url": "", "ok": False, "status": 0, "error": "no-public-url"},
}
if public_url.startswith("https://"):
    checks["public_http"] = check_url("http://" + public_url.removeprefix("https://"))

dns_matches = []
if expected_ip:
    dns_matches.append(expected_ip in records["A"] or expected_ip in records["AAAA"])
if expected_cname:
    dns_matches.append(expected_cname in {value.rstrip(".") for value in records["CNAME"]})

warnings = []
next_steps = []
if expected_ip or expected_cname:
    if not dns_matches or not all(dns_matches):
        next_steps.append("Fix DNS first, then run route-check again.")
if service and local_url and not checks["local"]["ok"]:
    next_steps.append(f"Restart local service: seven deploy restart {service.get('slug')}")
if public_url and not checks["public_https"]["ok"]:
    next_steps.append("Verify DNS, tunnel/VPS firewall, and HTTPS gateway for the domain.")
if not service:
    warnings.append("No SevenOS service metadata matched this subject; route-check tested the domain only.")

if not subject:
    state = "missing-subject"
elif service and checks["local"]["ok"] and (not public_url or checks["public_https"]["ok"]):
    state = "ready"
elif public_url and checks["public_https"]["ok"] and (not service or checks["local"]["ok"]):
    state = "ready"
elif service and not checks["local"]["ok"]:
    state = "local-unreachable"
elif public_url and not checks["public_https"]["ok"]:
    state = "public-unreachable"
else:
    state = "unknown"

print(json.dumps({
    "schema": "sevenos.deploy.route-check.v1",
    "state": state,
    "subject": subject,
    "domain": domain if "." in domain else "",
    "service": service,
    "records": records,
    "expected": {"ip": expected_ip, "cname": expected_cname},
    "checks": checks,
    "warnings": warnings,
    "next": next_steps,
}, indent=2))
PY
}

show_route_check() {
  local subject="$1"
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    route_check_json "$subject"
    return 0
  fi
  ROUTE_CHECK_JSON="$(route_check_json "$subject")" python - <<'PY'
import json, os
data = json.loads(os.environ["ROUTE_CHECK_JSON"])
print("SevenOS Route Check")
print("===================")
print(f"Subject: {data.get('subject') or '<missing>'}")
if data.get("domain"):
    print(f"Domain:  {data['domain']}")
print(f"State:   {data.get('state')}")
checks = data.get("checks", {})
for name, item in checks.items():
    if item.get("url"):
        marker = "OK" if item.get("ok") else "FAIL"
        status = item.get("status") or "-"
        print(f"{name}: {marker} {status} {item.get('url')}")
if data.get("warnings"):
    print()
    print("Warnings:")
    for item in data["warnings"]:
        print(f"  - {item}")
if data.get("next"):
    print()
    print("Next:")
    for item in data["next"]:
        print(f"  - {item}")
PY
}

diagnose_json() {
  local subject="$1"
  local route_payload services_payload versions_payload dns_payload
  route_payload="$(route_check_json "$subject")"
  services_payload="$(services_json)"
  versions_payload="$(versions_json "$subject" 2>/dev/null || printf '{}')"
  dns_payload="{}"
  local domain
  domain="$(ROUTE_CHECK_JSON="$route_payload" python - <<'PY'
import json, os
try:
    print(json.loads(os.environ["ROUTE_CHECK_JSON"]).get("domain", ""))
except Exception:
    print("")
PY
)"
  if [[ -n "$domain" ]]; then
    dns_payload="$(dns_check_json "$domain" "$EXPECTED_IP" "$EXPECTED_CNAME")"
  fi
  SUBJECT="$subject" ROUTE_CHECK_JSON="$route_payload" SERVICES_JSON="$services_payload" VERSIONS_JSON="$versions_payload" DNS_CHECK_JSON="$dns_payload" python - <<'PY'
import json
import os

subject = os.environ["SUBJECT"]

def load_env(name):
    try:
        return json.loads(os.environ.get(name) or "{}")
    except Exception:
        return {}

route = load_env("ROUTE_CHECK_JSON")
services = load_env("SERVICES_JSON")
versions = load_env("VERSIONS_JSON")
dns = load_env("DNS_CHECK_JSON")

score = 100
next_steps = []
warnings = []

route_state = route.get("state", "unknown")
dns_state = dns.get("state", "")
service = route.get("service") or {}

if route_state not in {"ready"}:
    score -= 35
    next_steps.extend(route.get("next", []))
if dns_state and dns_state not in {"ready", "resolved"}:
    score -= 20
    next_steps.extend(dns.get("next", []))
if not service:
    score -= 10
    warnings.append("No local SevenOS hosting service matched this subject.")
else:
    if not service.get("app_active", True) and service.get("runtime_state") == "stopped":
        score -= 20
        next_steps.append(f"Start service: seven deploy start {service.get('slug')}")
if versions.get("state") == "empty":
    score -= 5
    warnings.append("No saved publish version was found for this subject.")

for item in route.get("warnings", []):
    if item not in warnings:
        warnings.append(item)
for item in dns.get("warnings", []):
    if item not in warnings:
        warnings.append(item)

dedup_next = []
for item in next_steps:
    if item and item not in dedup_next:
        dedup_next.append(item)

score = max(0, min(100, score))
if score >= 90:
    state = "ready"
elif score >= 65:
    state = "attention"
else:
    state = "blocked"

print(json.dumps({
    "schema": "sevenos.deploy.diagnose.v1",
    "state": state,
    "score": score,
    "subject": subject,
    "summary": {
        "route": route_state,
        "dns": dns_state or "not-applicable",
        "services": services.get("count", 0),
        "versions": len(versions.get("versions", [])),
    },
    "route": route,
    "dns": dns,
    "versions": versions,
    "warnings": warnings,
    "next": dedup_next,
}, indent=2))
PY
}

show_diagnose() {
  local subject="$1"
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    diagnose_json "$subject"
    return 0
  fi
  DIAGNOSE_JSON="$(diagnose_json "$subject")" python - <<'PY'
import json, os
data = json.loads(os.environ["DIAGNOSE_JSON"])
print("SevenOS Deploy Diagnose")
print("=======================")
print(f"Subject: {data.get('subject') or '<missing>'}")
print(f"State:   {data.get('state')}")
print(f"Score:   {data.get('score')}%")
summary = data.get("summary", {})
print(f"Route:   {summary.get('route')}")
print(f"DNS:     {summary.get('dns')}")
print(f"Versions:{summary.get('versions')}")
if data.get("warnings"):
    print()
    print("Warnings:")
    for item in data["warnings"]:
        print(f"  - {item}")
if data.get("next"):
    print()
    print("Next:")
    for item in data["next"]:
        print(f"  - {item}")
PY
}

publish_project() {
  local project_dir="$1"
  local name slug port service_dir snapshot_dir source_dir runner app_unit tunnel_unit metadata provider domain public_url state domain_config dns_plan
  local version_id version_dir versions_dir current_link existing_port

  project_dir="$(cd -- "$project_dir" && pwd)"
  name="$(project_name "$project_dir")"
  slug="$(project_slug "$name")"
  service_dir="$DEPLOY_STATE_DIR/$slug"
  versions_dir="$service_dir/versions"
  metadata="$service_dir/service.json"
  existing_port=""
  if [[ -f "$metadata" ]]; then
    existing_port="$(python - "$metadata" <<'PY'
import json
import sys
try:
    print(json.load(open(sys.argv[1], encoding="utf-8")).get("port", ""))
except Exception:
    print("")
PY
)"
  fi
  port="${PUBLISH_PORT:-${existing_port:-$(default_port "$slug")}}"
  if [[ -n "$existing_port" && "$port" == "$existing_port" ]]; then
    if ! port_available "$port" && ! systemctl --user is-active --quiet "seven-deploy-$slug.service" 2>/dev/null; then
      log_error "Port already in use by another process: $port"
      return 1
    fi
  elif [[ -z "$PUBLISH_PORT" ]]; then
    port="$(free_port "$port")"
  elif ! port_available "$port"; then
    log_error "Port already in use: $port"
    return 1
  fi
  provider="$PUBLISH_PROVIDER"
  domain="$PUBLISH_DOMAIN"
  [[ "$provider" == "auto" && -n "$domain" ]] && provider="domain"
  [[ "$provider" == "auto" && -z "$domain" ]] && provider="cloudflare"
  [[ -n "$domain" && "$provider" != "cloudflare" ]] && provider="domain"
  if [[ "$PUBLISH_TARGET" == "tunnel" || "$PUBLISH_TARGET" == "cloudflare" ]]; then
    provider="cloudflare"
  elif [[ "$PUBLISH_TARGET" == "vps" || "$PUBLISH_TARGET" == "public-ip" ]]; then
    provider="domain"
  fi

  version_id="$(timestamp_id)"
  version_dir="$versions_dir/$version_id"
  current_link="$service_dir/current"
  snapshot_dir="$current_link"
  source_dir="$(snapshot_source "$project_dir")"
  runner="$service_dir/run-static.sh"
  app_unit="seven-deploy-$slug.service"
  tunnel_unit="seven-deploy-$slug-tunnel.service"
  domain_config=""
  dns_plan=""

  mkdir -p "$service_dir" "$versions_dir" "$version_dir" "$SYSTEMD_USER_DIR"
  local build_state build_log
  build_state="skipped"
  build_log="$service_dir/build.log"
  if [[ "$PUBLISH_BUILD" == "1" ]]; then
    if build_project "$project_dir" "$build_log"; then
      build_state="ok"
    else
      build_state="failed"
      state="build-failed"
      if [[ "$JSON_OUTPUT" -eq 1 ]]; then
        write_metadata "$metadata" "$name" "$slug" "$project_dir" "$snapshot_dir" "$port" "$provider" "$domain" "$state" "" "" "$build_state" "$build_log" "$version_id" ""
      else
        log_error "Build failed. See: $build_log"
      fi
      return 1
    fi
  fi
  source_dir="$(snapshot_source "$project_dir")"
  rsync -a --delete \
    --exclude '.git' --exclude 'node_modules' --exclude '.venv' --exclude 'venv' \
    --exclude 'target' --exclude '.next/cache' --exclude '__pycache__' \
    "$source_dir"/ "$version_dir"/
  ln -sfn "$version_dir" "$current_link"

  cat > "$runner" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
exec python -m http.server "$port" --bind 127.0.0.1 --directory "$snapshot_dir"
EOF
  chmod +x "$runner"

  cat > "$SYSTEMD_USER_DIR/$app_unit" <<EOF
[Unit]
Description=SevenOS deployed web service: $name
After=network-online.target

[Service]
Type=simple
ExecStart=$runner
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF

  state="local"
  public_url=""
  if [[ "$provider" == "cloudflare" ]]; then
    if command -v cloudflared >/dev/null 2>&1; then
      cat > "$SYSTEMD_USER_DIR/$tunnel_unit" <<EOF
[Unit]
Description=SevenOS public tunnel for $name
After=$app_unit network-online.target
Requires=$app_unit

[Service]
Type=simple
ExecStart=$(command -v cloudflared) tunnel --url http://127.0.0.1:$port
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF
      state="public-pending"
    else
      state="local-missing-tunnel"
    fi
  elif [[ "$provider" == "domain" ]]; then
    public_url="https://$domain"
    state="domain-ready-local"
    domain_config="$service_dir/Caddyfile"
    dns_plan="$service_dir/dns.json"
    cat > "$domain_config" <<EOF
$domain {
  reverse_proxy 127.0.0.1:$port
}
EOF
    domain_plan_json "$domain" "$PUBLISH_TARGET" "$PUBLIC_IP" "$TUNNEL_HOSTNAME" > "$dns_plan"
  fi

  systemctl --user daemon-reload >/dev/null 2>&1 || true
  systemctl --user enable --now "$app_unit" >/dev/null 2>&1 || true
  wait_local_url "$port" >/dev/null 2>&1 || true
  if [[ "$provider" == "cloudflare" && -s "$SYSTEMD_USER_DIR/$tunnel_unit" ]]; then
    systemctl --user enable --now "$tunnel_unit" >/dev/null 2>&1 || true
    sleep 1
    public_url="$(cloudflared_url "$tunnel_unit")"
    [[ -n "$public_url" ]] && state="public"
  fi

  write_metadata "$metadata" "$name" "$slug" "$project_dir" "$snapshot_dir" "$port" "$provider" "$domain" "$state" "$public_url" "$domain_config" "$build_state" "$build_log" "$version_id" "$dns_plan" > "$service_dir/.last-publish.json"

  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    cat "$service_dir/.last-publish.json"
  else
    SERVICE_JSON="$(cat "$service_dir/.last-publish.json")" python - <<'PY'
import json, os
data = json.loads(os.environ["SERVICE_JSON"])
print("SevenOS Publish")
print("===============")
print(f"Project:    {data['name']}")
print(f"State:      {data['state']}")
print(f"Local:      {data['local_url']}")
if data.get("public_url"):
    print(f"Public:     {data['public_url']}")
elif data.get("provider") == "cloudflare":
    print("Public:     pending, check: seven deploy services")
if data.get("domain"):
    print(f"Domain:     {data['domain']}")
print(f"Snapshot:   {data['snapshot']}")
print(f"App unit:   {data['app_unit']}")
print(f"Tunnel:     {data['tunnel_unit']}")
PY
  fi
}

unpublish_project() {
  local project="$1" name slug service_dir app_unit tunnel_unit
  if [[ -d "$project" ]]; then
    name="$(project_name "$(cd -- "$project" && pwd)")"
  else
    name="$project"
  fi
  slug="$(project_slug "$name")"
  service_dir="$DEPLOY_STATE_DIR/$slug"
  app_unit="seven-deploy-$slug.service"
  tunnel_unit="seven-deploy-$slug-tunnel.service"
  systemctl --user disable --now "$tunnel_unit" >/dev/null 2>&1 || true
  systemctl --user disable --now "$app_unit" >/dev/null 2>&1 || true
  rm -f "$SYSTEMD_USER_DIR/$tunnel_unit" "$SYSTEMD_USER_DIR/$app_unit"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  if [[ -f "$service_dir/service.json" ]]; then
    python - "$service_dir/service.json" <<'PY'
import json, sys
path = sys.argv[1]
data = json.load(open(path, encoding="utf-8"))
data["state"] = "stopped"
json.dump(data, open(path, "w", encoding="utf-8"), indent=2)
print()
PY
  fi
  log_success "Unpublished $slug"
}

remove_project() {
  local project="$1" slug
  slug="$(service_slug "$project")"
  unpublish_project "$slug" >/dev/null 2>&1 || true
  rm -rf "$DEPLOY_STATE_DIR/$slug"
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    printf '{"schema":"sevenos.deploy.remove.v1","state":"OK","slug":%s}\n' "$(printf '%s' "$slug" | json_string)"
  else
    log_success "Removed $slug deploy state"
  fi
}

service_slug() {
  local project="$1"
  if [[ -d "$project" ]]; then
    project_name "$(cd -- "$project" && pwd)" | while read -r name; do project_slug "$name"; done
  else
    project_slug "$project"
  fi
}

service_action() {
  local verb="$1" project="$2" slug app_unit tunnel_unit
  slug="$(service_slug "$project")"
  app_unit="seven-deploy-$slug.service"
  tunnel_unit="seven-deploy-$slug-tunnel.service"

  case "$verb" in
    start)
      systemctl --user start "$app_unit" >/dev/null 2>&1 || true
      systemctl --user start "$tunnel_unit" >/dev/null 2>&1 || true
      ;;
    stop)
      systemctl --user stop "$tunnel_unit" >/dev/null 2>&1 || true
      systemctl --user stop "$app_unit" >/dev/null 2>&1 || true
      ;;
    restart)
      systemctl --user restart "$app_unit" >/dev/null 2>&1 || true
      systemctl --user restart "$tunnel_unit" >/dev/null 2>&1 || true
      ;;
    logs)
      journalctl --user -u "$app_unit" -u "$tunnel_unit" -n 120 --no-pager
      return 0
      ;;
  esac

  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    services_json
  else
    log_success "$verb $slug"
  fi
}

versions_json() {
  local project="$1" slug service_dir
  slug="$(service_slug "$project")"
  service_dir="$DEPLOY_STATE_DIR/$slug"
  SLUG="$slug" SERVICE_DIR="$service_dir" python - <<'PY'
import json
import os
from pathlib import Path

slug = os.environ["SLUG"]
service_dir = Path(os.environ["SERVICE_DIR"])
versions_dir = service_dir / "versions"
current = ""
current_path = service_dir / "current"
if current_path.is_symlink():
    current = Path(os.readlink(current_path)).name
versions = []
if versions_dir.is_dir():
    for path in sorted(versions_dir.iterdir(), reverse=True):
        if path.is_dir():
            versions.append({
                "id": path.name,
                "path": str(path),
                "current": path.name == current,
            })
print(json.dumps({
    "schema": "sevenos.deploy.versions.v1",
    "slug": slug,
    "state": "ready" if versions else "empty",
    "current": current,
    "versions": versions,
}, indent=2))
PY
}

show_versions() {
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    versions_json "$project"
    return 0
  fi
  VERSIONS_JSON="$(versions_json "$project")" python - <<'PY'
import json, os
data = json.loads(os.environ["VERSIONS_JSON"])
print("SevenOS Deploy Versions")
print("=======================")
print(f"Project: {data.get('slug')}")
if not data.get("versions"):
    print("No versions yet.")
for item in data.get("versions", []):
    marker = "*" if item.get("current") else " "
    print(f"{marker} {item['id']}  {item['path']}")
PY
}

rollback_project() {
  local project="$1" version="${2:-}" slug service_dir version_dir current_link
  slug="$(service_slug "$project")"
  service_dir="$DEPLOY_STATE_DIR/$slug"
  current_link="$service_dir/current"
  if [[ -z "$version" ]]; then
    local versions_payload
    versions_payload="$(versions_json "$slug")"
    version="$(VERSIONS_JSON="$versions_payload" python - <<'PY'
import json, os
data = json.loads(os.environ["VERSIONS_JSON"])
versions = [item["id"] for item in data.get("versions", []) if not item.get("current")]
print(versions[0] if versions else "")
PY
)"
  fi
  version_dir="$service_dir/versions/$version"
  if [[ -z "$version" || ! -d "$version_dir" ]]; then
    log_error "Rollback version not found for $slug: ${version:-<auto>}"
    return 1
  fi
  ln -sfn "$version_dir" "$current_link"
  service_action restart "$slug" >/dev/null 2>&1 || true
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    versions_json "$slug"
  else
    log_success "Rolled back $slug to $version"
  fi
}

services_json() {
  DEPLOY_STATE_DIR="$DEPLOY_STATE_DIR" python - <<'PY'
import json
import os
import subprocess
import urllib.request
from pathlib import Path

base = Path(os.environ["DEPLOY_STATE_DIR"])
services = []

def active(unit):
    result = subprocess.run(["systemctl", "--user", "is-active", "--quiet", unit], check=False)
    return result.returncode == 0

def reachable(url):
    try:
        with urllib.request.urlopen(url, timeout=1.2) as response:
            return 200 <= response.status < 500
    except Exception:
        return False

def tunnel_url(unit):
    result = subprocess.run(["journalctl", "--user", "-u", unit, "-n", "160", "--no-pager"], text=True, capture_output=True, check=False)
    for line in reversed(result.stdout.splitlines()):
        marker = "https://"
        if marker in line and "trycloudflare.com" in line:
            start = line.find(marker)
            tail = line[start:].split()[0].strip()
            return tail.rstrip(".,")
    return ""

if base.is_dir():
    for metadata in sorted(base.glob("*/service.json")):
        try:
            item = json.loads(metadata.read_text(encoding="utf-8"))
        except Exception:
            continue
        item["app_active"] = active(item.get("app_unit", ""))
        item["tunnel_active"] = active(item.get("tunnel_unit", ""))
        item["local_reachable"] = reachable(item.get("local_url", ""))
        if item.get("provider") == "cloudflare":
            public = tunnel_url(item.get("tunnel_unit", ""))
            if public:
                item["public_url"] = public
                item["state"] = "public"
        if not item["app_active"]:
            item["runtime_state"] = "stopped"
        elif item.get("public_url"):
            item["runtime_state"] = "public"
        else:
            item["runtime_state"] = "local"
        services.append(item)
print(json.dumps({
    "schema": "sevenos.deploy.services.v1",
    "state": "ready" if services else "empty",
    "count": len(services),
    "services": services,
}, indent=2))
PY
}

show_services() {
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    services_json
    return 0
  fi
  SERVICES_JSON="$(services_json)" python - <<'PY'
import json, os
data = json.loads(os.environ["SERVICES_JSON"])
print("SevenOS Deploy Services")
print("=======================")
if not data.get("services"):
    print("No published services yet.")
for item in data.get("services", []):
    print(f"{item['slug']:<24} {item.get('state',''):<20} {item.get('local_url','')}")
    if item.get("public_url"):
        print(f"{'':<24} public: {item['public_url']}")
PY
}

panel_json() {
  SERVICES_JSON="$(services_json)" SERVER_JSON="$("$ROOT_DIR/server/seven-server.sh" status --json 2>/dev/null || printf '{}')" python - <<'PY'
import json, os
services = json.loads(os.environ["SERVICES_JSON"])
server = json.loads(os.environ["SERVER_JSON"] or "{}")
print(json.dumps({
    "schema": "sevenos.deploy.panel.v1",
    "state": "ready",
    "server": server,
    "services": services,
    "commands": {
        "publish": "seven deploy publish .",
        "publish_public": "seven deploy publish . --provider cloudflare",
        "publish_domain": "seven deploy publish . --domain app.example.com",
        "domain_tunnel": "seven deploy domain app.example.com --target tunnel",
        "domain_vps": "seven deploy domain app.example.com --target vps --public-ip 203.0.113.10",
        "dns_check_ip": "seven deploy dns-check app.example.com --expected-ip 203.0.113.10",
        "dns_check_tunnel": "seven deploy dns-check app.example.com --expected-cname <tunnel-id>.cfargotunnel.com",
        "route_check": "seven deploy route-check <project-or-domain>",
        "diagnose": "seven deploy diagnose <project-or-domain>",
        "api_domain": "/deploy/domain?domain=app.example.com&target=vps&public_ip=203.0.113.10",
        "api_dns_check": "/deploy/dns-check?domain=app.example.com&expected_ip=203.0.113.10",
        "api_route_check": "/deploy/route-check?subject=app.example.com",
        "api_diagnose": "/deploy/diagnose?subject=app.example.com",
        "services": "seven deploy services --json",
        "start": "seven deploy start <project>",
        "stop": "seven deploy stop <project>",
        "restart": "seven deploy restart <project>",
        "logs": "seven deploy logs <project>",
        "versions": "seven deploy versions <project>",
        "rollback": "seven deploy rollback <project> [version]",
        "unpublish": "seven deploy unpublish <project>",
        "remove": "seven deploy remove <project>",
    },
}, indent=2))
PY
}

show_panel() {
  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    panel_json
    return 0
  fi
  PANEL_JSON="$(panel_json)" python - <<'PY'
import json, os
data = json.loads(os.environ["PANEL_JSON"])
services = data.get("services", {}).get("services", [])
print("SevenOS Hosting Panel")
print("=====================")
print(f"Server:   {data.get('server', {}).get('state', 'unknown')}")
print(f"Services: {len(services)}")
for item in services:
    print(f"- {item['slug']}: {item.get('state')} · {item.get('local_url')}")
    if item.get("public_url"):
        print(f"  {item['public_url']}")
print()
print("Commands:")
for command in data.get("commands", {}).values():
    print(f"  {command}")
PY
}

show_status() {
  local deploy_dir="$ROOT_DIR/out/deploy"

  if [[ "$JSON_OUTPUT" -eq 1 ]]; then
    DEPLOY_DIR="$deploy_dir" ROOT_DIR="$ROOT_DIR" python - <<'PY'
import json
import os
from pathlib import Path

root = Path(os.environ["ROOT_DIR"])
deploy_dir = Path(os.environ["DEPLOY_DIR"])
plans = []

if deploy_dir.is_dir():
    for plan in sorted(deploy_dir.glob("*/plan.txt")):
        data = {"file": str(plan.relative_to(root))}
        for raw in plan.read_text(encoding="utf-8", errors="replace").splitlines():
            if "=" in raw:
                key, value = raw.split("=", 1)
                if key in {"project", "path", "stack", "created"}:
                    data[key] = value
        plan_json = plan.with_name("plan.json")
        if plan_json.is_file():
            data["contract"] = str(plan_json.relative_to(root))
        plans.append(data)

print(json.dumps({
    "schema": "sevenos.deploy.status.v1",
    "state": "ready" if plans else "empty",
    "plan_count": len(plans),
    "plans": plans,
    "next": [] if plans else [{"command": "seven deploy ./my-project", "reason": "Create the first deployment plan."}],
}, indent=2))
PY
    return 0
  fi

  printf 'SevenOS Deploy Status\n'
  printf '=====================\n'
  if [[ ! -d "$deploy_dir" ]]; then
    printf 'No deployment plans yet.\n'
    printf 'Create one with: seven deploy ./my-project\n'
    return 0
  fi

  find "$deploy_dir" -maxdepth 2 -name plan.txt -print | sort | while IFS= read -r plan; do
    printf '\n%s\n' "${plan#$ROOT_DIR/}"
    sed -n '1,4p' "$plan" | sed 's/^/  /'
  done
}

show_logs() {
  printf 'SevenOS Deploy Logs\n'
  printf '===================\n'
  printf 'Phase 1 writes deployment plans under out/deploy/<project>/plan.txt.\n'
  printf 'Runtime logs will be attached when container execution is enabled.\n'
}

args=()
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --json|json) JSON_OUTPUT=1 ;;
    --domain) PUBLISH_DOMAIN="${2:-}"; shift ;;
    --provider) PUBLISH_PROVIDER="${2:-auto}"; shift ;;
    --target) PUBLISH_TARGET="${2:-auto}"; shift ;;
    --public-ip) PUBLIC_IP="${2:-}"; shift ;;
    --tunnel-hostname) TUNNEL_HOSTNAME="${2:-}"; shift ;;
    --expected-ip) EXPECTED_IP="${2:-}"; shift ;;
    --expected-cname) EXPECTED_CNAME="${2:-}"; shift ;;
    --port) PUBLISH_PORT="${2:-}"; shift ;;
    --build) PUBLISH_BUILD=1 ;;
    --no-build) PUBLISH_BUILD=0 ;;
    *) args+=("$1") ;;
  esac
  shift || true
done
set -- "${args[@]}"
action="${1:-plan}"
project="${2:-.}"

if [[ "$action" != "plan" && "$action" != "inspect" && "$action" != "dev" && "$action" != "doctor" && "$action" != "publish" && "$action" != "domain" && "$action" != "dns" && "$action" != "dns-check" && "$action" != "route-check" && "$action" != "diagnose" && "$action" != "unpublish" && "$action" != "remove" && "$action" != "start" && "$action" != "stop" && "$action" != "restart" && "$action" != "versions" && "$action" != "rollback" && "$action" != "services" && "$action" != "panel" && "$action" != "detect" && "$action" != "status" && "$action" != "logs" && "$action" != "-h" && "$action" != "--help" && "$action" != "help" ]]; then
  project="$action"
  action="plan"
fi

case "$action" in
  -h|--help|help)
    ;;
  *)
    require_forge_profile "$action" || exit 1
    ;;
esac

case "$action" in
  plan)
    [[ -d "$project" ]] || { log_error "Project directory not found: $project"; exit 1; }
    write_plan "$project"
    ;;
  inspect)
    [[ -d "$project" ]] || { log_error "Project directory not found: $project"; exit 1; }
    inspect_project "$project"
    ;;
  dev)
    [[ -d "$project" ]] || { log_error "Project directory not found: $project"; exit 1; }
    dev_loop "$project"
    ;;
  doctor)
    [[ -d "$project" ]] || { log_error "Project directory not found: $project"; exit 1; }
    doctor_project "$project"
    ;;
  publish)
    [[ -d "$project" ]] || { log_error "Project directory not found: $project"; exit 1; }
    publish_project "$project"
    ;;
  domain|dns)
    show_domain_plan "$project"
    ;;
  dns-check)
    show_dns_check "$project"
    ;;
  route-check)
    show_route_check "$project"
    ;;
  diagnose)
    show_diagnose "$project"
    ;;
  unpublish)
    unpublish_project "$project"
    ;;
  remove)
    remove_project "$project"
    ;;
  start|stop|restart)
    service_action "$action" "$project"
    ;;
  versions)
    show_versions
    ;;
  rollback)
    rollback_project "$project" "${3:-}"
    ;;
  services) show_services ;;
  panel) show_panel ;;
  detect)
    [[ -d "$project" ]] || { log_error "Project directory not found: $project"; exit 1; }
    detect_stack "$project"
    printf '\n'
    ;;
  status) show_status ;;
  logs)
    if [[ $# -gt 1 ]]; then
      service_action logs "$project"
    else
      show_logs
    fi
    ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown deploy action: $action"; usage; exit 1 ;;
esac
