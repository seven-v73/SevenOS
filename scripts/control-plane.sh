#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="plan"
JSON_OUTPUT=0
APPLY=0
YES=0
SAFE_ONLY=0
LIMIT=6
REFRESH_CACHE="${SEVENOS_CONTROL_REFRESH:-0}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sevenos"
CONTROL_CACHE="$CACHE_DIR/control-plane.json"
CONTROL_CACHE_TTL="${SEVENOS_CONTROL_CACHE_TTL:-300}"

usage() {
  cat <<'EOF'
SevenOS Control Plane

Usage:
  seven control
  seven control --json
  seven control apply [--limit N] [--safe-only] [--apply] [--yes]
  ./scripts/control-plane.sh [plan|apply] [--json]

Builds a single prioritized OS action plan from readiness, experience,
Shield, Server, profiles and registered actions. This is the decision contract
for Seven Hub and future Seven Server orchestration.
EOF
}

while [[ "$#" -gt 0 ]]; do
  arg="$1"
  case "$arg" in
    plan|apply) ACTION="$arg" ;;
    --json|json) JSON_OUTPUT=1 ;;
    --refresh|--no-cache) REFRESH_CACHE=1 ;;
    --apply) APPLY=1 ;;
    --yes) YES=1 ;;
    --safe-only) SAFE_ONLY=1 ;;
    --limit)
      shift
      LIMIT="${1:-}"
      [[ "$LIMIT" =~ ^[0-9]+$ ]] || { log_error "--limit expects a number."; exit 1; }
      ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown control option: $arg"; usage; exit 1 ;;
  esac
  shift
done

if [[ "$YES" -eq 1 ]]; then
  export SEVENOS_YES=1
fi

payload() {
  SEVENOS_ROOT="$ROOT_DIR" python - <<'PY'
import json
import os
import subprocess

ROOT = os.environ["SEVENOS_ROOT"]

def command_json(command, fallback):
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False)
    if result.returncode != 0 or not result.stdout.strip():
        return fallback
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return fallback

readiness = command_json([os.path.join(ROOT, "scripts/readiness.sh"), "--json"], {"percent": 0, "recommendations": []})
welcome_plan = command_json([os.path.join(ROOT, "bin/seven-welcome"), "plan", "--json"], {"next": []})
experience = command_json([os.path.join(ROOT, "scripts/experience.sh"), "--json"], {"percent": 0, "checks": [], "recommendations": []})
shield = command_json([os.path.join(ROOT, "security/shield-status.sh"), "--json"], {"posture": "unknown", "percent": 0, "checks": [], "recommendations": []})
shield_plan = command_json([os.path.join(ROOT, "security/shield-status.sh"), "plan", "--json"], {"next": []})
server = command_json([os.path.join(ROOT, "server/seven-server.sh"), "status", "--json"], {"service": {"state": "MISS"}, "recommendations": []})
server_plan = command_json([os.path.join(ROOT, "server/seven-server.sh"), "plan", "--json"], {"next": []})
atlas = command_json([os.path.join(ROOT, "bin/seven"), "atlas", "status", "--json"], {"state": "unknown", "missing_required": []})
atlas_plan = command_json([os.path.join(ROOT, "bin/seven-profile-requirements"), "status", "atlas", "--json"], {"next": []})
installer = command_json([os.path.join(ROOT, "scripts/installer-stack.sh"), "status", "--json"], {"ready": False, "mode": "foundation"})
installer_plan = command_json([os.path.join(ROOT, "scripts/installer-stack.sh"), "plan", "--json"], {"next": []})
packages_plan = command_json([os.path.join(ROOT, "bin/sevenpkg"), "plan", "--json"], {"next": []})
public_quality = command_json([os.path.join(ROOT, "scripts/public-experience.sh"), "doctor", "--json", "--refresh"], {"score": 0, "daily_quality_ready": False, "public_quality_ready": False, "gates": []})
profile_health = command_json([os.path.join(ROOT, "bin/seven"), "profile", "health", "--json"], {"summary": {}})
store = command_json([os.path.join(ROOT, "scripts/store.sh"), "json"], {"summary": {}, "modules": []})
box = command_json([os.path.join(ROOT, "scripts/box.sh"), "json"], {"summary": {}, "checks": []})
cloud = command_json([os.path.join(ROOT, "scripts/cloud.sh"), "json"], {"summary": {}, "targets": []})
flow = command_json([os.path.join(ROOT, "scripts/flow.sh"), "json"], {"summary": {}, "recipes": []})
cluster = command_json([os.path.join(ROOT, "scripts/cluster.sh"), "json"], {"summary": {}, "actions": []})
ecosystem = command_json([os.path.join(ROOT, "scripts/ecosystem.sh"), "json"], {"modules": [], "processes": []})
profiles = command_json([os.path.join(ROOT, "bin/seven"), "profile", "status", "--json"], [])
profile_plan = command_json([os.path.join(ROOT, "bin/seven"), "profile", "plan", "--json"], {"next": []})
actions = command_json([os.path.join(ROOT, "scripts/actions.sh"), "--json"], {"actions": []})
daily = command_json([os.path.join(ROOT, "scripts/daily-driver.sh"), "status", "--json"], {"decision": "unknown", "blockers": [], "warnings": []})

actions_by_command = {item.get("command"): item for item in actions.get("actions", [])}
public_gates = {item.get("key"): item for item in public_quality.get("gates", []) if isinstance(item, dict)}
public_daily_ready = bool(public_quality.get("daily_quality_ready")) or int(public_quality.get("score", 0) or 0) >= 95
public_quality_ready = bool(public_quality.get("public_quality_ready"))
profile_summary = profile_health.get("summary") if isinstance(profile_health.get("summary"), dict) else {}
profiles_ready = bool(
    profile_summary.get("ready") == profile_summary.get("total")
    and int(profile_summary.get("needs_install", 0) or 0) == 0
    and int(profile_summary.get("needs_bootstrap", 0) or 0) == 0
)
installer_ready = bool(installer.get("ready")) or installer.get("state") == "graphical-ready" or installer.get("mode") in {"graphical-ready", "graphical"}

def action_id_for(command):
    item = actions_by_command.get(command)
    return item.get("id") if item else None

items = []
seen = set()

def add(source, severity, title, command, reason, impact="safe"):
    key = command
    if key in seen:
        return
    seen.add(key)
    items.append({
        "source": source,
        "severity": severity,
        "title": title,
        "command": command,
        "action_id": action_id_for(command),
        "impact": impact,
        "reason": reason,
    })

for check in experience.get("checks", []):
    state = check.get("state")
    if state == "OK":
        continue
    category = str(check.get("category", ""))
    if public_daily_ready and category in {"Shell", "Profiles", "Theme", "Installer"}:
        continue
    if check.get("category") == "Security" and shield.get("percent", 0) >= 90:
        continue
    command = check.get("command", "seven experience")
    severity = "high" if state == "MISS" else "medium"
    add("experience", severity, f"Fix {check.get('category', 'Experience')}", command, check.get("detail", "Improve SevenOS coherence"), "changes")

for item in welcome_plan.get("next", []):
    if item.get("state") == "READY":
        continue
    add(
        "first-run",
        item.get("severity", "high"),
        item.get("title", "Complete first-run setup"),
        item.get("command", "seven welcome plan"),
        item.get("reason", item.get("detail", "Complete SevenOS onboarding")),
        item.get("impact", "changes"),
    )

for item in shield_plan.get("next", []):
    if item.get("key") == "firewall" and shield.get("percent", 0) >= 90:
        continue
    severity = item.get("severity", "high")
    if item.get("key") in {"scope", "engagement", "authorization"} and shield.get("percent", 0) >= 90:
        severity = "medium"
    add(
        "shield",
        severity,
        item.get("title", f"Secure {item.get('key', 'Shield')}"),
        item.get("command", "seven shield plan"),
        item.get("reason", item.get("detail", "Improve Shield posture")),
        item.get("impact", "changes"),
    )

for item in server_plan.get("next", []):
    add(
        "server",
        item.get("severity", "medium"),
        item.get("title", "Prepare Seven Server"),
        item.get("command", "seven server plan"),
        item.get("reason", "Improve local API readiness"),
        item.get("impact", "changes"),
    )

server_runtime_ready = bool(server.get("runtime_ready")) or (server.get("service") or {}).get("state") in ("READY", "RUN")
if shield.get("percent", 0) < 70 or not server_runtime_ready:
    add(
        "b3",
        "critical",
        "Run B3 consolidation path",
        "seven b3 plan",
        "Use the ordered B3 path for trust, backend, profiles, shell and installer instead of scattered fixes.",
        "safe",
    )

for item in daily.get("blockers", []):
    if public_daily_ready:
        continue
    add(
        "daily",
        "critical",
        item.get("title", "Resolve daily driver blocker"),
        item.get("command", "seven daily"),
        item.get("reason", "SevenOS is not ready for a primary PC."),
        "packages" if "--apply" in item.get("command", "") else "safe",
    )

for item in daily.get("warnings", []):
    if public_daily_ready:
        continue
    add(
        "daily",
        "high",
        item.get("title", "Resolve daily driver warning"),
        item.get("command", "seven daily"),
        item.get("reason", "SevenOS daily-driver gate has a warning."),
        "changes",
    )

for rec in readiness.get("recommendations", []):
    reason = str(rec.get("reason", ""))
    if public_daily_ready and any(token in reason for token in ("role workspaces", "deployment workspace", "daily")):
        continue
    add("readiness", "medium", "Improve Readiness", rec.get("command", "seven readiness"), rec.get("reason", "Improve SevenOS readiness"), "changes")

for item in atlas_plan.get("next", []):
    add(
        "atlas",
        item.get("severity", "medium"),
        item.get("title", "Complete Atlas Explorer"),
        item.get("command", "seven atlas status"),
        item.get("reason", "Improve Atlas Explorer readiness"),
        item.get("impact", "changes"),
    )

for item in installer_plan.get("next", []):
    if installer_ready:
        continue
    add(
        "installer",
        item.get("severity", "medium"),
        item.get("title", "Prepare installer"),
        item.get("command", "seven installer plan"),
        item.get("reason", "Improve installer readiness"),
        item.get("impact", "safe"),
    )

for item in packages_plan.get("next", []):
    command = str(item.get("command", ""))
    reason = str(item.get("reason", ""))
    if profiles_ready and ("equinox" in command or "Equinox" in reason):
        continue
    if public_daily_ready and ("server" in command or "Server" in reason):
        continue
    add(
        "packages",
        item.get("severity", "medium"),
        item.get("title", "Complete software layer"),
        item.get("command", "sevenpkg plan"),
        item.get("reason", "Improve software readiness"),
        item.get("impact", "packages"),
    )

store_summary = store.get("summary") or {}
box_summary = box.get("summary") or {}
cloud_summary = cloud.get("summary") or {}
flow_summary = flow.get("summary") or {}
cluster_summary = cluster.get("summary") or {}

store_public_ready = bool(
    public_daily_ready
    and int(store_summary.get("catalog_apps", 0) or 0) > 0
    and int(store_summary.get("rootfs_ready", 0) or 0) >= int(store_summary.get("rootfs_total", 0) or 0) > 0
)
if store_summary and not store_public_ready and store_summary.get("modules_ready", 0) < max(store_summary.get("modules", 0) - store_summary.get("optional_modules", 0), 0):
    add(
        "ecosystem",
        "medium",
        "Complete SevenStore required modules",
        "seven store modules",
        "SevenStore should show all required SevenOS modules as ready before it becomes a primary app surface.",
        "safe",
    )

if box_summary and box_summary.get("ready", 0) < box_summary.get("total", 0):
    add(
        "ecosystem",
        "medium",
        "Complete SevenBox isolation runtime",
        "seven box doctor",
        "SevenBox needs container and sandbox runtimes before it can safely host workflows.",
        "packages",
    )

if cloud_summary and cloud_summary.get("tools_ready", 0) < cloud_summary.get("tools_total", 0):
    add(
        "ecosystem",
        "medium",
        "Prepare SevenCloud protection tools",
        "seven cloud doctor",
        "SevenCloud needs rsync, encryption and versioning tools before backups become actionable.",
        "packages",
    )

if flow_summary and flow_summary.get("ready", 0) < flow_summary.get("recipes", 0):
    add(
        "ecosystem",
        "medium",
        "Resolve SevenFlow recipe gaps",
        "seven flow doctor",
        "SevenFlow recipes must resolve to concrete action registry commands before automation can be trusted.",
        "safe",
    )

if cluster_summary and cluster_summary.get("tools_ready", 0) < cluster_summary.get("tools_total", 0):
    add(
        "ecosystem",
        "medium",
        "Prepare SevenCluster private mesh tools",
        "seven cluster doctor",
        "SevenCluster needs SSH, rsync, Podman and local routing before private multi-machine workflows are safe.",
        "packages",
    )

for profile in profile_plan.get("next", []):
    if profiles_ready:
        continue
    key = profile.get("key", "profile")
    title = profile.get("title", key.title())
    severity = "critical" if profile.get("priority") == "critical" else "high" if profile.get("priority") == "high" else "medium"
    add(
        "profiles",
        severity,
        f"Complete {title}",
        profile.get("command", f"seven profile install {key}"),
        profile.get("reason", f"{title} workspace is {profile.get('state', 'partial')}"),
        "packages",
    )

scores = {
    "readiness": readiness.get("percent", 0),
    "experience": experience.get("percent", 0),
    "shield": shield.get("percent", 0),
    "server": 100 if bool(server.get("deployment_stack_ready")) else 75 if bool(server.get("runtime_ready")) else 50 if server.get("service", {}).get("state") == "READY" else 0,
    "atlas": 100 if not atlas.get("missing_required") else 70,
    "installer": 100 if installer.get("ready") else 60 if installer.get("mode") in ("tui-ready", "graphical") else 35,
    "b3": round((shield.get("percent", 0) * 0.45) + ((100 if bool(server.get("deployment_stack_ready")) else 75 if bool(server.get("runtime_ready")) else 60 if server.get("service", {}).get("state") == "READY" else 0) * 0.35) + ((100 if installer.get("ready") else 35) * 0.2)),
}
ecosystem_modules = ecosystem.get("modules") or []
ecosystem_maturity_payload = ecosystem.get("maturity") or {}
ecosystem_maturity_summary = ecosystem_maturity_payload.get("summary") or {}
ecosystem_maturity_modules = ecosystem_maturity_payload.get("modules") or []
planned_modules = sum(1 for item in ecosystem_modules if item.get("state") == "planned")
preview_modules = sum(1 for item in ecosystem_modules if item.get("state") == "preview")
active_modules = sum(1 for item in ecosystem_modules if item.get("state") == "active")
ecosystem_total = len(ecosystem_modules) or 1
store_score = 100 if not store_summary else round((store_summary.get("modules_ready", 0) / max(store_summary.get("modules", 1), 1)) * 100)
box_score = 100 if not box_summary else round((box_summary.get("ready", 0) / max(box_summary.get("total", 1), 1)) * 100)
cloud_score = 100 if not cloud_summary else round((cloud_summary.get("tools_ready", 0) / max(cloud_summary.get("tools_total", 1), 1)) * 100)
flow_score = 100 if not flow_summary else round((flow_summary.get("ready", 0) / max(flow_summary.get("recipes", 1), 1)) * 100)
cluster_score = 100 if not cluster_summary else round((cluster_summary.get("tools_ready", 0) / max(cluster_summary.get("tools_total", 1), 1)) * 100)
ecosystem_maturity = round(((active_modules + preview_modules * 0.85) / ecosystem_total) * 100)
product_maturity = ecosystem_maturity_summary.get("average", ecosystem_maturity)
scores["ecosystem"] = round((product_maturity * 0.35) + (store_score * 0.13) + (box_score * 0.13) + (cloud_score * 0.13) + (flow_score * 0.13) + (cluster_score * 0.13))
overall = round((scores["readiness"] * 0.22) + (scores["experience"] * 0.22) + (scores["shield"] * 0.18) + (scores["server"] * 0.13) + (scores["atlas"] * 0.13) + (scores["installer"] * 0.12))
overall = round((overall * 0.85) + (scores["ecosystem"] * 0.15))

for module in ecosystem_maturity_modules[:3]:
    if module.get("state") != "preview":
        continue
    if int(module.get("score", 0) or 0) >= 85:
        continue
    add(
        "ecosystem",
        "medium",
        f"Harden {module.get('name', 'preview module')}",
        "seven ecosystem maturity",
        module.get("next", "Move this preview toward a product-ready surface."),
        "safe",
    )

severity_rank = {"critical": 0, "high": 1, "medium": 2, "low": 3}
items.sort(key=lambda item: (severity_rank.get(item["severity"], 9), item["source"], item["command"]))

print(json.dumps({
    "schema": "sevenos.control.v1",
    "root": os.path.abspath(ROOT),
    "overall": overall,
    "scores": scores,
    "ecosystem": {
        "active": active_modules,
        "preview": preview_modules,
        "planned": planned_modules,
        "maturity": ecosystem_maturity_summary,
        "store": store_summary,
        "box": box_summary,
        "cloud": cloud_summary,
        "flow": flow_summary,
        "cluster": cluster_summary,
    },
    "summary": {
        "critical": sum(1 for item in items if item["severity"] == "critical"),
        "high": sum(1 for item in items if item["severity"] == "high"),
        "medium": sum(1 for item in items if item["severity"] == "medium"),
        "total": len(items),
    },
    "actions": items[:12],
}, indent=2))
PY
}

json_cache_valid() {
  python - "$1" "$ROOT_DIR" >/dev/null 2>&1 <<'PY'
import json
import sys
from pathlib import Path

try:
    data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
except Exception:
    raise SystemExit(1)
if data.get("root") != str(Path(sys.argv[2]).resolve()):
    raise SystemExit(1)
raise SystemExit(0)
PY
}

cache_is_fresh() {
  local path="$1" ttl="$2" now mtime
  [[ "$REFRESH_CACHE" == 1 ]] && return 1
  [[ -s "$path" ]] || return 1
  json_cache_valid "$path" || return 1
  now="$(date +%s)"
  mtime="$(stat -c %Y "$path" 2>/dev/null || printf 0)"
  [[ $(( now - mtime )) -lt "$ttl" ]]
}

write_json_cache() {
  local path="$1" tmp
  mkdir -p "$(dirname "$path")"
  tmp="$path.tmp.$$"
  cat >"$tmp"
  if json_cache_valid "$tmp"; then
    mv -f "$tmp" "$path"
  else
    rm -f "$tmp"
    return 1
  fi
}

control_payload() {
  local data
  if [[ "$ACTION" != "apply" || "$APPLY" -eq 0 ]] && cache_is_fresh "$CONTROL_CACHE" "$CONTROL_CACHE_TTL"; then
    cat "$CONTROL_CACHE"
    return 0
  fi
  data="$(payload)"
  if [[ "$ACTION" != "apply" || "$APPLY" -eq 0 ]]; then
    printf '%s\n' "$data" | write_json_cache "$CONTROL_CACHE" || true
  fi
  printf '%s\n' "$data"
}

if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  control_payload
  exit 0
fi

execute_plan() {
  local control_payload command_count=0
  control_payload="$(control_payload)"

  printf 'SevenOS Control Apply\n'
  printf '=====================\n'
  if [[ "$APPLY" -eq 1 ]]; then
    log_warn "Apply mode enabled. SevenOS will run prioritized actions."
    [[ "$YES" -eq 1 ]] && log_warn "Non-interactive package install mode enabled where supported."
  else
    printf 'Preview only. Add --apply to execute.\n'
  fi
  [[ "$SAFE_ONLY" -eq 1 ]] && printf 'Safe-only mode: skipping package and system-changing actions.\n'
  printf '\n'

  if [[ "$APPLY" -eq 1 && "$SAFE_ONLY" -ne 1 ]] && ! is_dry_run && ! sudo -n true 2>/dev/null; then
    log_error "Control apply needs an active sudo session for prioritized system changes."
    log_info "Run 'sudo -v' first, or preview with: seven control apply --limit $LIMIT"
    exit 1
  fi

  "$ROOT_DIR/scripts/events.sh" log \
    --source control \
    --type "$([[ "$APPLY" -eq 1 ]] && printf apply || printf preview)" \
    --state "$([[ "$APPLY" -eq 1 ]] && printf WARN || printf OK)" \
    --message "Control plane $([[ "$APPLY" -eq 1 ]] && printf apply || printf preview) requested with limit $LIMIT" \
    --command "seven control apply --limit $LIMIT$([[ "$SAFE_ONLY" -eq 1 ]] && printf ' --safe-only')$([[ "$APPLY" -eq 1 ]] && printf ' --apply')" >/dev/null

  while IFS=$'\t' read -r severity impact command reason; do
    [[ -n "${command:-}" ]] || continue
    command_count=$((command_count + 1))
    printf '%-9s %-9s %s\n' "$severity" "$impact" "$command"
    printf '%-9s %-9s %s\n' "" "" "$reason"

    if [[ "$APPLY" -eq 1 ]] && ! is_dry_run; then
      bash -lc "cd '$ROOT_DIR' && $command"
    else
      printf '          DRY-RUN > %s\n' "$command"
    fi
    printf '\n'
  done < <(
    CONTROL_PAYLOAD="$control_payload" SAFE_ONLY="$SAFE_ONLY" LIMIT="$LIMIT" python - <<'PY'
import json
import os

data = json.loads(os.environ["CONTROL_PAYLOAD"])
safe_only = os.environ.get("SAFE_ONLY") == "1"
limit = int(os.environ.get("LIMIT", "6"))
count = 0

for item in data.get("actions", []):
    if safe_only and item.get("impact") != "safe":
        continue
    print("\t".join([
        item.get("severity", ""),
        item.get("impact", ""),
        item.get("command", ""),
        item.get("reason", ""),
    ]))
    count += 1
    if count >= limit:
        break
PY
  )

  if [[ "$command_count" -eq 0 ]]; then
    log_success "No matching control actions to run."
  fi
}

if [[ "$ACTION" == "apply" ]]; then
  execute_plan
  exit 0
fi

CONTROL_PAYLOAD="$(control_payload)" python - <<'PY'
import json
import os
import sys

data = json.loads(os.environ["CONTROL_PAYLOAD"])
summary = data.get("summary", {})

print("SevenOS Control Plane")
print("=====================")
print(f"Overall: {data.get('overall', 0)}%")
print(
    "Actions: "
    f"{summary.get('critical', 0)} critical, "
    f"{summary.get('high', 0)} high, "
    f"{summary.get('medium', 0)} medium"
)
print()
print(f"{'Severity':<9} {'Source':<11} {'Command'}")
print(f"{'--------':<9} {'------':<11} {'-------'}")
for item in data.get("actions", []):
    print(f"{item.get('severity',''):<9} {item.get('source',''):<11} {item.get('command','')}")
    print(f"{'':<9} {'':<11} {item.get('reason','')}")
PY
