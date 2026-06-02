#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
JSON_OUTPUT=0
[[ "${1:-}" == "--json" || "${1:-}" == "json" ]] && JSON_OUTPUT=1

tmp="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp"
}
trap cleanup EXIT

mkdir -p "$tmp/bin" "$tmp/home" "$tmp/state" "$tmp/cache"

cat >"$tmp/bin/hyprctl" <<'SH'
#!/usr/bin/env bash
case "$1" in
  monitors) exit 0 ;;
  clients)
    if [[ -e "${SEVENOS_TEST_PORTAL_STARTED:-}" ]]; then
      printf '[{"class":"SevenOSInstallerNative","title":"SevenOS Installer"}]\n'
    else
      printf '[]\n'
    fi
    exit 0
    ;;
  dispatch) exit 0 ;;
  *) exit 0 ;;
esac
SH

cat >"$tmp/bin/calamares" <<'SH'
#!/usr/bin/env bash
touch "$SEVENOS_TEST_CALAMARES_STARTED"
exit 20
SH

cat >"$tmp/bin/seven-installer" <<'SH'
#!/usr/bin/env bash
if [[ "${1:-}" == "gui" ]]; then
  touch "$SEVENOS_TEST_PORTAL_STARTED"
  sleep 5
  exit 0
fi
exit 0
SH

cat >"$tmp/bin/sudo" <<'SH'
#!/usr/bin/env bash
if [[ "${1:-}" == "-n" && "${2:-}" == "true" ]]; then
  exit 0
fi
if [[ "${1:-}" == "-E" ]]; then
  shift
  exec "$@"
fi
exec "$@"
SH

for name in notify-send nmcli xdg-user-dirs-update seven-welcome dbus-update-activation-environment systemctl; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$tmp/bin/$name"
  chmod +x "$tmp/bin/$name"
done
cat >"$tmp/bin/xhost" <<'SH'
#!/usr/bin/env bash
touch "$SEVENOS_TEST_XHOST_STARTED"
exit 0
SH
chmod +x "$tmp/bin/hyprctl" "$tmp/bin/calamares" "$tmp/bin/seven-installer" "$tmp/bin/sudo" "$tmp/bin/xhost"

status_file="$tmp/state/sevenos/live-status.json"
started_file="$tmp/calamares.started"
portal_file="$tmp/portal.started"
result_state="FAIL"
detail="live helper did not report a ready SevenOS portal window"
exit_code=1

if SEVENOS_TEST_CALAMARES_STARTED="$started_file" \
  SEVENOS_TEST_PORTAL_STARTED="$portal_file" \
  HOME="$tmp/home" XDG_STATE_HOME="$tmp/state" XDG_CACHE_HOME="$tmp/cache" \
  PATH="$tmp/bin:/usr/bin:/bin" WAYLAND_DISPLAY=wayland-1 DISPLAY=:1 SEVENOS_ROOT="$ROOT_DIR" \
  timeout 8 "$ROOT_DIR/archiso/profile/airootfs/usr/local/bin/sevenos-live-ready" >/dev/null 2>&1; then
  if [[ -e "$portal_file" && ! -e "$started_file" && -r "$status_file" ]] && python - "$status_file" <<'PY' >/dev/null 2>&1
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
if data.get("state") != "ready":
    raise SystemExit(1)
if "SevenOS installer portal is interactive" not in str(data.get("detail", "")):
    raise SystemExit(1)
PY
  then
    result_state="OK"
    detail="live helper opens the SevenOS portal first and confirms its window"
    exit_code=0
  fi
fi

if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  RESULT_STATE="$result_state" DETAIL="$detail" python - <<'PY'
import json
import os

print(json.dumps({
    "schema": "sevenos.live-installer-smoke.v1",
    "state": os.environ["RESULT_STATE"],
    "detail": os.environ["DETAIL"],
}, ensure_ascii=False, indent=2))
PY
else
  printf 'SevenOS live installer smoke: %s\n' "$result_state"
  printf '%s\n' "$detail"
fi

exit "$exit_code"
