#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
ACTION="${1:-doctor}"
JSON_OUTPUT=0

case "${2:-}" in
  --json|json) JSON_OUTPUT=1 ;;
esac

asset_state() {
  local path="$1"
  [[ -s "$ROOT_DIR/$path" ]] && printf OK || printf MISS
}

count_dynamic_wallpapers() {
  find "$ROOT_DIR/identity/wallpaper/dynamic" -maxdepth 1 -name '*.svg' 2>/dev/null | wc -l | tr -d ' '
}

manifest_count() {
  python - "$ROOT_DIR/identity/wallpaper/dynamic/manifest.json" <<'PY' 2>/dev/null || printf 0
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
print(data.get("count", 0))
PY
}

collection_list_ok() {
  SEVENOS_ROOT="$ROOT_DIR" "$ROOT_DIR/bin/seven-wallpaper" collection-list 2>/dev/null |
    python -m json.tool >/dev/null 2>&1
}

package_contains() {
  local package="$1"
  local file="$2"
  grep -Fxq "$package" "$ROOT_DIR/$file"
}

json_report() {
  local dynamic_count manifest_items state collection_state
  dynamic_count="$(count_dynamic_wallpapers)"
  manifest_items="$(manifest_count)"
  collection_state=MISS
  if collection_list_ok; then
    collection_state=OK
  fi
  state=OK
  for required in \
    identity/assets/wallpaper-sevenos.svg \
    identity/assets/wallpaper-sevenos-light.svg \
    identity/assets/symbol-seven-prism.svg \
    identity/assets/symbol-seven-prism-mark.svg \
    identity/assets/logo-sevenos.svg \
    identity/wallpaper/generate-sevenos-wallpapers.py \
    identity/wallpaper/dynamic/manifest.json \
    bin/seven-wallpaper; do
    [[ "$(asset_state "$required")" == OK ]] || state=MISS
  done
  [[ "$dynamic_count" == 45 && "$manifest_items" == 45 && "$collection_state" == OK ]] || state=MISS
  package_contains hyprpaper scripts/packages-base.txt || state=MISS
  package_contains swww scripts/packages-base.txt || state=MISS
  package_contains librsvg scripts/packages-base.txt || state=MISS

  ROOT_DIR="$ROOT_DIR" STATE="$state" DYNAMIC_COUNT="$dynamic_count" MANIFEST_ITEMS="$manifest_items" COLLECTION_STATE="$collection_state" python - <<'PY'
import json
import os
root = os.environ["ROOT_DIR"]
checks = []
for path in [
    "identity/assets/wallpaper-sevenos.svg",
    "identity/assets/wallpaper-sevenos-light.svg",
    "identity/assets/symbol-seven-prism.svg",
    "identity/assets/symbol-seven-prism-mark.svg",
    "identity/assets/logo-sevenos.svg",
    "identity/wallpaper/generate-sevenos-wallpapers.py",
    "identity/wallpaper/dynamic/manifest.json",
    "bin/seven-wallpaper",
]:
    import pathlib
    full = pathlib.Path(root) / path
    checks.append({"path": path, "state": "OK" if full.is_file() and full.stat().st_size > 0 else "MISS"})
checks.extend([
    {"path": "identity/wallpaper/dynamic/*.svg", "state": "OK" if os.environ["DYNAMIC_COUNT"] == "45" else "MISS", "count": int(os.environ["DYNAMIC_COUNT"] or 0)},
    {"path": "identity/wallpaper/dynamic/manifest.json count", "state": "OK" if os.environ["MANIFEST_ITEMS"] == "45" else "MISS", "count": int(os.environ["MANIFEST_ITEMS"] or 0)},
    {"path": "seven-wallpaper collection-list", "state": os.environ["COLLECTION_STATE"]},
    {"path": "scripts/packages-base.txt:hyprpaper", "state": "OK" if "hyprpaper\n" in pathlib.Path(root, "scripts/packages-base.txt").read_text() else "MISS"},
    {"path": "scripts/packages-base.txt:swww", "state": "OK" if "swww\n" in pathlib.Path(root, "scripts/packages-base.txt").read_text() else "MISS"},
    {"path": "scripts/packages-base.txt:librsvg", "state": "OK" if "librsvg\n" in pathlib.Path(root, "scripts/packages-base.txt").read_text() else "MISS"},
])
print(json.dumps({
    "schema": "sevenos.system-assets.v1",
    "state": os.environ["STATE"],
    "install_target": "/opt/SevenOS",
    "iso_copy": "scripts/build-iso.sh injects the repository into airootfs/opt/SevenOS",
    "checks": checks,
}, ensure_ascii=False, indent=2))
PY
}

case "$ACTION" in
  status|doctor|json)
    if [[ "$JSON_OUTPUT" -eq 1 || "$ACTION" == json ]]; then
      json_report
    else
      report="$(json_report)"
      state="$(printf '%s' "$report" | python -c 'import json,sys; print(json.load(sys.stdin)["state"])')"
      printf 'SevenOS system assets: %s\n' "$state"
      REPORT="$report" python - <<'PY'
import json
import os
import sys
data = json.loads(os.environ["REPORT"])
for check in data["checks"]:
    detail = f" ({check['count']})" if "count" in check else ""
    print(f"  {check['state']:4} {check['path']}{detail}")
PY
      [[ "$state" == OK ]]
    fi
    ;;
  *)
    printf 'Usage: scripts/system-assets.sh [doctor|status|json] [--json]\n' >&2
    exit 1
    ;;
esac
