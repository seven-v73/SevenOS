#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

ACTION="status"
BUNDLE=""
JSON_OUTPUT=0
YES=0
WITH_AUR=0

usage() {
  cat <<'EOF'
SevenOS Shield Bundles

Usage:
  seven shield bundles [--json]
  seven shield bundles list [--json]
  seven shield bundles status <bundle> [--json]
  seven shield bundles install <bundle> --yes [--with-aur]

Bundles:
  web         web pentest and application assessment
  forensics   evidence and artifact analysis
  osint       open-source intelligence and privacy routing
  reverse     reverse engineering and exploit research
  malware     offline sample triage and sandbox support
  devsecops   dependency, code and container security
  wireless    wireless and packet analysis

Bundles install only focused tool sets. BlackArch and Kali remain optional
sources exposed through: seven shield toolchain
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    list|status|install) ACTION="$1" ;;
    --json|json) JSON_OUTPUT=1 ;;
    --yes|-y) YES=1 ;;
    --with-aur) WITH_AUR=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *)
      if [[ -z "$BUNDLE" ]]; then
        BUNDLE="$1"
      else
        log_error "Unexpected argument: $1"
        usage
        exit 1
      fi
      ;;
  esac
  shift
done

bundle_file() {
  case "$1" in
    web) printf '%s/scripts/packages-shield-web.txt' "$ROOT_DIR" ;;
    forensics) printf '%s/scripts/packages-shield-forensics.txt' "$ROOT_DIR" ;;
    osint) printf '%s/scripts/packages-shield-osint.txt' "$ROOT_DIR" ;;
    reverse) printf '%s/scripts/packages-shield-reverse.txt' "$ROOT_DIR" ;;
    malware) printf '%s/scripts/packages-shield-malware.txt' "$ROOT_DIR" ;;
    devsecops) printf '%s/scripts/packages-shield-devsecops.txt' "$ROOT_DIR" ;;
    wireless) printf '%s/scripts/packages-shield-wireless.txt' "$ROOT_DIR" ;;
    *) return 1 ;;
  esac
}

bundle_title() {
  case "$1" in
    web) printf 'Web Pentest' ;;
    forensics) printf 'Forensics' ;;
    osint) printf 'OSINT' ;;
    reverse) printf 'Reverse Engineering' ;;
    malware) printf 'Malware Lab' ;;
    devsecops) printf 'DevSecOps' ;;
    wireless) printf 'Wireless' ;;
  esac
}

bundle_persona() {
  case "$1" in
    web) printf 'lab' ;;
    forensics) printf 'forensics' ;;
    osint) printf 'osint' ;;
    reverse) printf 'research' ;;
    malware) printf 'malware' ;;
    devsecops) printf 'devsecops' ;;
    wireless) printf 'lab' ;;
  esac
}

bundle_scope() {
  case "$1" in
    web|wireless) printf 'active scope recommended before intrusive scans' ;;
    malware|forensics) printf 'offline or evidence-safe workspace recommended' ;;
    osint) printf 'privacy routing recommended' ;;
    reverse|devsecops) printf 'local/lab target recommended' ;;
  esac
}

bundle_aur() {
  case "$1" in
    web) printf '%s\n' burpsuite feroxbuster nuclei ;;
    forensics) printf '%s\n' autopsy ;;
    osint) printf '%s\n' spiderfoot recon-ng ;;
    reverse) printf '%s\n' binaryninja-demo ;;
    malware) printf '%s\n' flare-floss capa ;;
    devsecops) printf '%s\n' semgrep ;;
    wireless) printf '%s\n' wifite ;;
  esac
}

bundle_blackarch() {
  case "$1" in
    web) printf 'webapp' ;;
    forensics) printf 'forensic' ;;
    osint) printf 'recon' ;;
    reverse) printf 'reversing' ;;
    malware) printf 'malware' ;;
    devsecops) printf 'scanner' ;;
    wireless) printf 'wireless' ;;
  esac
}

bundle_kali() {
  case "$1" in
    web) printf 'kali-tools-web' ;;
    forensics) printf 'kali-tools-forensics' ;;
    osint) printf 'kali-tools-information-gathering' ;;
    reverse) printf 'kali-tools-reverse-engineering' ;;
    malware) printf 'kali-tools-forensics' ;;
    devsecops) printf 'kali-tools-top10' ;;
    wireless) printf 'kali-tools-wireless' ;;
  esac
}

package_list_json() {
  local package_file="$1"
  PACKAGE_FILE="$package_file" python - <<'PY'
import json
import os
from pathlib import Path
items = []
for line in Path(os.environ["PACKAGE_FILE"]).read_text().splitlines():
    line = line.split("#", 1)[0].strip()
    if line:
        items.append(line)
print(json.dumps(items))
PY
}

bundle_status_json() {
  local key="$1"
  status_all_json | BUNDLE_FILTER="$key" python - <<'PY'
import json
import os
import sys
data = json.load(sys.stdin)
key = os.environ["BUNDLE_FILTER"]
for item in data.get("bundles", []):
    if item.get("key") == key:
        print(json.dumps(item, indent=2))
        raise SystemExit(0)
print(f"Unknown Shield bundle: {key}", file=sys.stderr)
raise SystemExit(1)
PY
}

all_bundles_json() {
  python - <<'PY'
print('["web","forensics","osint","reverse","malware","devsecops","wireless"]')
PY
}

status_all_json() {
  ROOT_DIR="$ROOT_DIR" python - <<'PY'
import json
import subprocess
from pathlib import Path

root = Path(__import__("os").environ["ROOT_DIR"])
specs = {
    "web": ("Web Pentest", "lab", "active scope recommended before intrusive scans", "scripts/packages-shield-web.txt", ["burpsuite", "feroxbuster", "nuclei"], "webapp", "kali-tools-web"),
    "forensics": ("Forensics", "forensics", "offline or evidence-safe workspace recommended", "scripts/packages-shield-forensics.txt", ["autopsy"], "forensic", "kali-tools-forensics"),
    "osint": ("OSINT", "osint", "privacy routing recommended", "scripts/packages-shield-osint.txt", ["spiderfoot", "recon-ng"], "recon", "kali-tools-information-gathering"),
    "reverse": ("Reverse Engineering", "research", "local/lab target recommended", "scripts/packages-shield-reverse.txt", ["binaryninja-demo"], "reversing", "kali-tools-reverse-engineering"),
    "malware": ("Malware Lab", "malware", "offline or evidence-safe workspace recommended", "scripts/packages-shield-malware.txt", ["flare-floss", "capa"], "malware", "kali-tools-forensics"),
    "devsecops": ("DevSecOps", "devsecops", "local/lab target recommended", "scripts/packages-shield-devsecops.txt", ["semgrep"], "scanner", "kali-tools-top10"),
    "wireless": ("Wireless", "lab", "active scope recommended before intrusive scans", "scripts/packages-shield-wireless.txt", ["wifite"], "wireless", "kali-tools-wireless"),
}

try:
    installed = set(subprocess.check_output(["pacman", "-Qq"], text=True).splitlines())
except Exception:
    installed = set()

def read_packages(relative):
    path = root / relative
    items = []
    for line in path.read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            items.append(line)
    return items

bundles = []
for key, (title, persona, scope_note, relative, aur, blackarch, kali) in specs.items():
    packages = read_packages(relative)
    rows = [{"name": pkg, "state": "OK" if pkg in installed else "MISS"} for pkg in packages]
    ready = sum(1 for item in rows if item["state"] == "OK")
    total = len(rows)
    percent = int((ready / total) * 100) if total else 0
    state = "OK" if percent == 100 else ("PART" if percent else "MISS")
    bundles.append({
        "key": key,
        "title": title,
        "state": state,
        "percent": percent,
        "ready": ready,
        "total": total,
        "persona": persona,
        "scope_note": scope_note,
        "package_file": str(root / relative),
        "packages": rows,
        "recommended_aur": aur,
        "blackarch_category": blackarch,
        "kali_meta": kali,
        "commands": {
            "install": f"seven shield bundles install {key} --yes",
            "install_with_aur": f"seven shield bundles install {key} --yes --with-aur",
            "blackarch": f"seven shield toolchain blackarch-category {blackarch} --yes",
            "kali": f"seven shield toolchain kali-run 'apt update && apt install -y {kali}'",
        },
    })

print(json.dumps({
    "schema": "sevenos.shield-bundles.v1",
    "bundles": bundles,
    "policy": [
        "focused bundles before huge catalogs",
        "AUR optional tools require review",
        "BlackArch is opt-in by category",
        "Kali tools run inside the compatibility container",
    ],
}, indent=2))
PY
}

status_human() {
  status_all_json | python -c 'import json,sys
data=json.load(sys.stdin)
print("SevenOS Shield Bundles")
print("======================")
for item in data["bundles"]:
    print("{key:<10} {percent:>3}%  {title:<22} persona={persona}".format(**item))
print()
print("Install: seven shield bundles install <bundle> --yes")
print("AUR:     add --with-aur when you explicitly want advanced tools")
print("Bridge:  seven shield toolchain search <tool>")'
}

install_bundle() {
  [[ -n "$BUNDLE" ]] || { log_error "Missing bundle name."; usage; exit 1; }
  local file
  file="$(bundle_file "$BUNDLE")" || { log_error "Unknown Shield bundle: $BUNDLE"; exit 1; }
  [[ "$YES" -eq 1 || "${SEVENOS_YES:-0}" == "1" ]] || {
    log_error "Bundle installs require explicit consent."
    log_info "Run: seven shield bundles install $BUNDLE --yes"
    exit 1
  }
  SEVENOS_YES=1 install_package_file "$file"
  if [[ "$WITH_AUR" -eq 1 ]]; then
    while IFS= read -r package; do
      [[ -n "$package" ]] || continue
      "$ROOT_DIR/security/shield-toolchain.sh" install "$package" --yes || true
    done < <(bundle_aur "$BUNDLE")
  fi
  log_success "Shield bundle ready: $(bundle_title "$BUNDLE")"
  log_info "Recommended persona: seven shield persona $(bundle_persona "$BUNDLE")"
}

case "$ACTION" in
  list)
    if [[ "$JSON_OUTPUT" -eq 1 ]]; then status_all_json; else status_human; fi
    ;;
  status)
    if [[ -n "$BUNDLE" ]]; then
      if [[ "$JSON_OUTPUT" -eq 1 ]]; then
        bundle_status_json "$BUNDLE"
      else
        bundle_status_json "$BUNDLE" | python -c 'import json,sys; item=json.load(sys.stdin); print(f"{item[\"title\"]}: {item[\"percent\"]}% ({item[\"ready\"]}/{item[\"total\"]})"); [print(f"  {p[\"state\"]:<4} {p[\"name\"]}") for p in item["packages"]]'
      fi
    else
      if [[ "$JSON_OUTPUT" -eq 1 ]]; then status_all_json; else status_human; fi
    fi
    ;;
  install)
    install_bundle
    ;;
  *)
    usage
    exit 1
    ;;
esac
