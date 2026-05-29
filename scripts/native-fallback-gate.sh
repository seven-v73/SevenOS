#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
ACTION="${1:-status}"
JSON_OUTPUT=0
for arg in "$@"; do
  [[ "$arg" == "--json" || "$arg" == "json" ]] && JSON_OUTPUT=1
done
[[ "$ACTION" == "json" ]] && JSON_OUTPUT=1

case "$ACTION" in
  status|doctor|plan|json|--json) ;;
  -h|--help|help)
    cat <<'EOF'
SevenOS native fallback gate

Usage:
  seven native-fallback-gate [--json]
  ./scripts/native-fallback-gate.sh [status|doctor|json] [--json]

Checks that public workflows prefer native SevenOS surfaces before legacy
fallback menus.
EOF
    exit 0
    ;;
  *) echo "[SevenOS] Unknown native fallback gate action: $ACTION" >&2; exit 1 ;;
esac

payload() {
  SEVENOS_ROOT="$ROOT_DIR" python - <<'PY'
import json
import os
import subprocess
from pathlib import Path

root = Path(os.environ["SEVENOS_ROOT"])
contract_path = root / "identity/native-fallback-contract.json"
try:
    contract = json.loads(contract_path.read_text(encoding="utf-8"))
except Exception:
    contract = {"required_routes": []}

checks = []
for item in contract.get("required_routes", []):
    key = str(item.get("key", "unknown"))
    script = root / str(item.get("script", ""))
    native = root / str(item.get("native", ""))
    patterns = [str(value) for value in item.get("required_patterns", [])]
    try:
        text = script.read_text(encoding="utf-8", errors="replace")
    except Exception:
        text = ""
    missing_patterns = [pattern for pattern in patterns if pattern not in text]
    script_ok = script.is_file() and os.access(script, os.X_OK)
    native_ok = native.is_file() and os.access(native, os.X_OK)
    ok = script_ok and native_ok and not missing_patterns
    checks.append({
        "key": key,
        "state": "OK" if ok else "WARN",
        "script": str(script.relative_to(root)) if script.exists() else str(item.get("script", "")),
        "native": str(native.relative_to(root)) if native.exists() else str(item.get("native", "")),
        "script_ok": script_ok,
        "native_ok": native_ok,
        "missing_patterns": missing_patterns,
        "detail": "Native route is preferred before legacy fallback." if ok else "Native route needs review before public release.",
    })

try:
    actions_result = subprocess.run(
        [str(root / "scripts/actions.sh"), "--json"],
        cwd=root,
        text=True,
        capture_output=True,
        check=False,
        timeout=12,
        env={**os.environ, "SEVENOS_ROOT": str(root)},
    )
    actions_payload = json.loads(actions_result.stdout or "{}")
    actions = actions_payload.get("actions") if isinstance(actions_payload.get("actions"), list) else []
except Exception:
    actions = []
terminal_actions = [
    item for item in actions
    if isinstance(item, dict)
    and (
        str(item.get("id", "")).startswith("terminal.")
        or "terminal" in str(item.get("title", "")).casefold()
        or "terminal" in str(item.get("command", "")).casefold()
    )
]
checks.append({
    "key": "terminal-actions",
    "state": "OK" if len(terminal_actions) >= 3 else "WARN",
    "script": "scripts/actions.sh",
    "native": "bin/seven-actions-native",
    "script_ok": (root / "scripts/actions.sh").is_file(),
    "native_ok": (root / "bin/seven-actions-native").is_file(),
    "missing_patterns": [] if len(terminal_actions) >= 3 else ["terminal action catalog"],
    "detail": f"{len(terminal_actions)} terminal action(s) available for the native palette.",
})

issues = [item for item in checks if item["state"] != "OK"]
score = round(100 * (len(checks) - len(issues)) / max(1, len(checks)))
print(json.dumps({
    "schema": "sevenos.native-fallback-gate.v1",
    "state": "ready" if not issues else "attention",
    "score": score,
    "summary": {
        "routes": len(checks),
        "ok": len(checks) - len(issues),
        "issues": len(issues),
    },
    "checks": checks,
    "issues": issues,
    "contract": "identity/NATIVE_FALLBACK_CONTRACT.md",
}, ensure_ascii=False, indent=2))
PY
}

data="$(payload)"
if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  printf '%s\n' "$data"
else
  GATE_JSON="$data" python - <<'PY'
import json
import os

data = json.loads(os.environ["GATE_JSON"])
print("SevenOS Native Fallback Gate")
print("============================")
print(f"State: {data.get('state')} · Score: {data.get('score')}%")
for item in data.get("checks", []):
    print(f"  {item.get('state'):<4} {item.get('key')}: {item.get('detail')}")
    if item.get("missing_patterns"):
        print(f"       missing: {', '.join(item.get('missing_patterns'))}")
PY
fi
