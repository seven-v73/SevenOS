#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

JSON_OUTPUT=0
REFRESH=0
WORKSPACE="${SEVENOS_SHIELD_WORKSPACE:-$HOME/ShieldLab}"
STATE_DIR="$WORKSPACE/.sevenos"
CACHE_FILE="$STATE_DIR/tool-doctor-cache.json"
CACHE_TTL="${SEVENOS_SHIELD_TOOL_DOCTOR_TTL:-900}"

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --json|json) JSON_OUTPUT=1 ;;
    --refresh|refresh) REFRESH=1 ;;
    -h|--help|help)
      printf 'Usage: seven shield tool-doctor [--json] [--refresh]\n'
      exit 0
      ;;
    tool-doctor|status) ;;
    *) log_error "Unknown tool-doctor option: $1"; exit 1 ;;
  esac
  shift
done

cache_valid() {
  [[ "$REFRESH" -eq 0 && -s "$CACHE_FILE" ]] || return 1
  CACHE_FILE="$CACHE_FILE" CACHE_TTL="$CACHE_TTL" python - <<'PY'
import os
import time
from pathlib import Path
path = Path(os.environ["CACHE_FILE"])
ttl = int(os.environ["CACHE_TTL"])
raise SystemExit(0 if time.time() - path.stat().st_mtime <= ttl else 1)
PY
}

doctor_json_uncached() {
  python - <<'PY'
import json
import shutil
import subprocess

domains = {
    "web_pentest": {
        "title": "Web Pentest",
        "required": ["zaproxy", "sqlmap", "nikto", "gobuster", "nmap"],
        "optional": ["burpsuite", "feroxbuster", "nuclei"],
    },
    "forensics": {
        "title": "Forensics",
        "required": ["mmls", "yara", "binwalk", "foremost", "testdisk", "exiftool"],
        "optional": ["autopsy", "volatility3"],
    },
    "reverse": {
        "title": "Reverse Engineering",
        "required": ["ghidra", "radare2", "rizin", "gdb", "strace", "ltrace"],
        "optional": ["cutter", "jadx"],
    },
    "osint": {
        "title": "OSINT",
        "required": ["firefox", "whois", "exiftool"],
        "optional": ["obsidian", "recon-ng", "tor", "proxychains4"],
    },
    "malware": {
        "title": "Malware Triage",
        "required": ["yara", "radare2", "rizin", "ghidra", "strings"],
        "optional": ["cutter", "volatility3"],
    },
    "devsecops": {
        "title": "DevSecOps",
        "required": ["bandit", "git", "podman"],
        "optional": ["trivy", "semgrep", "docker"],
    },
    "wireless": {
        "title": "Wireless",
        "required": ["aircrack-ng", "bettercap", "macchanger"],
        "optional": ["ettercap"],
    },
    "compatibility": {
        "title": "Compatibility",
        "required": ["podman", "firejail", "bwrap", "java"],
        "optional": ["burpsuite", "autopsy", "tor", "proxychains4"],
    },
}

def installed(command):
    if shutil.which(command):
        return True
    aliases = {
        "exiftool": ["exiftool"],
        "mmls": ["mmls"],
        "bwrap": ["bwrap"],
        "java": ["java"],
        "ettercap": ["ettercap", "ettercap-gtk"],
    }
    return any(shutil.which(alias) for alias in aliases.get(command, []))

def aur_available(package):
    if not shutil.which("yay"):
        return False
    return subprocess.run(["yay", "-Si", package], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False).returncode == 0

rows = []
for key, spec in domains.items():
    req = [{"name": item, "state": "OK" if installed(item) else "MISS"} for item in spec["required"]]
    opt = [{"name": item, "state": "OK" if installed(item) else ("AUR" if aur_available(item) else "MISS")} for item in spec["optional"]]
    req_score = sum(1 for item in req if item["state"] == "OK")
    opt_score = sum(1 for item in opt if item["state"] == "OK")
    max_score = len(req) * 2 + len(opt)
    score = req_score * 2 + opt_score
    percent = round((score / max_score) * 100) if max_score else 0
    state = "READY" if percent >= 85 else "GOOD" if percent >= 65 else "PARTIAL" if percent >= 40 else "WEAK"
    rows.append({
        "key": key,
        "title": spec["title"],
        "state": state,
        "percent": percent,
        "required": req,
        "optional": opt,
    })

overall = round(sum(item["percent"] for item in rows) / len(rows)) if rows else 0
print(json.dumps({
    "schema": "sevenos.shield-tool-doctor.v1",
    "overall": overall,
    "state": "READY" if overall >= 85 else "GOOD" if overall >= 65 else "PARTIAL",
    "domains": rows,
    "next": [
        "seven shield optional-tools install --yes",
        "seven shield wrappers install",
        "seven shield toolchain kali-prepare --yes",
    ],
}, indent=2))
PY
}

doctor_json() {
  mkdir -p "$STATE_DIR"
  if cache_valid; then
    cat "$CACHE_FILE"
    return 0
  fi
  doctor_json_uncached | tee "$CACHE_FILE"
}

if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  doctor_json
else
  doctor_json | python -c 'import json,sys
data=json.load(sys.stdin)
print("SevenOS Shield Tool Doctor")
print("==========================")
print("Overall: {}% ({})".format(data.get("overall"), data.get("state")))
print()
for item in data.get("domains", []):
    print("  {percent:>3}%  {state:<8} {title}".format(**item))
print()
print("Next:")
for item in data.get("next", []):
    print("  {}".format(item))'
fi
