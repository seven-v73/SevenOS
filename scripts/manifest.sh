#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
MANIFEST="${SEVENOS_MANIFEST:-$ROOT_DIR/sevenos.dotinst}"

usage() {
  cat <<'EOF'
Usage: seven manifest <command>

Commands:
  show          Print the SevenOS install manifest.
  doctor        Validate manifest structure and referenced paths.
  restore-plan  Show user paths that should be preserved during upgrades.
  protected     Show protected user-owned paths.
  components    Show future package/component boundaries.
  summary-json   Print machine-readable manifest summary.
  json          Print manifest JSON.
EOF
}

manifest_python() {
  python - "$MANIFEST" "$ROOT_DIR" "$@" <<'PY'
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
root = Path(sys.argv[2])
command = sys.argv[3] if len(sys.argv) > 3 else "show"

try:
    with manifest_path.open("r", encoding="utf-8") as handle:
        manifest = json.load(handle)
except Exception as error:
    print(f"manifest: invalid JSON: {error}", file=sys.stderr)
    sys.exit(1)

def required(value, label):
    if not value:
        print(f"manifest: missing {label}", file=sys.stderr)
        sys.exit(1)

def entries(name):
    value = manifest.get(name)
    if not isinstance(value, list) or not value:
        print(f"manifest: '{name}' must be a non-empty list", file=sys.stderr)
        sys.exit(1)
    return value

def doctor():
    for key in ("name", "id", "description", "version", "source"):
        required(manifest.get(key), key)

    restore = entries("restore")
    protected = entries("protected")
    components = entries("components")
    checks = entries("checks")

    problems = []
    for item in restore:
        if not item.get("title") or not item.get("target") or item.get("value") is not True:
            problems.append(f"restore entry is incomplete: {item}")

    for component in components:
        if not component.get("id") or not component.get("title") or not component.get("paths"):
            problems.append(f"component entry is incomplete: {component}")
            continue
        for relative in component.get("paths", []):
            candidate = root / relative
            if not candidate.exists():
                problems.append(f"component path missing: {relative}")

    for check in checks:
        script = check.split()[0]
        candidate = root / script
        if not candidate.exists():
            problems.append(f"check path missing: {script}")

    if problems:
        for problem in problems:
            print(f"manifest: {problem}", file=sys.stderr)
        sys.exit(1)

    print("SevenOS manifest OK")
    print(f"components: {len(components)}")
    print(f"restore entries: {len(restore)}")
    print(f"protected paths: {len(protected)}")

def show():
    print(f"{manifest.get('name')} [{manifest.get('version')}]")
    print(manifest.get("description", ""))
    base = manifest.get("base", {})
    print()
    print("Base:")
    for key in ("distribution", "desktop", "session", "package_manager", "software_layer"):
        if key in base:
            print(f"  {key}: {base[key]}")
    print()
    print("Entrypoints:")
    print("  seven manifest doctor")
    print("  seven manifest restore-plan")
    print("  seven manifest components")

def restore_plan():
    print("SevenOS restore/protection plan")
    for item in manifest.get("restore", []):
        title = item.get("title", "Untitled")
        target = item.get("target", item.get("source", ""))
        print(f"- {title}: {target}")

def protected():
    for path in manifest.get("protected", []):
        print(path)

def components():
    for item in manifest.get("components", []):
        paths = ", ".join(item.get("paths", []))
        print(f"{item.get('id')}: {item.get('title')} [{paths}]")

def summary_json():
    payload = {
        "schema": "sevenos.manifest.v1",
        "name": manifest.get("name"),
        "id": manifest.get("id"),
        "version": manifest.get("version"),
        "channel": manifest.get("channel"),
        "component_count": len(manifest.get("components", [])),
        "restore_count": len(manifest.get("restore", [])),
        "protected_count": len(manifest.get("protected", [])),
        "profile_targets": manifest.get("profile_targets", []),
        "components": [
            {
                "id": item.get("id"),
                "title": item.get("title"),
                "path_count": len(item.get("paths", [])),
            }
            for item in manifest.get("components", [])
        ],
    }
    print(json.dumps(payload, indent=2, ensure_ascii=False))

if command == "doctor":
    doctor()
elif command == "show":
    show()
elif command == "restore-plan":
    restore_plan()
elif command == "protected":
    protected()
elif command == "components":
    components()
elif command == "summary-json":
    summary_json()
elif command == "json":
    print(json.dumps(manifest, indent=2, ensure_ascii=False))
else:
    print(f"manifest: unknown command: {command}", file=sys.stderr)
    sys.exit(2)
PY
}

command="${1:-show}"
case "$command" in
  show|doctor|restore-plan|protected|components|summary-json|json)
    manifest_python "$command"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
