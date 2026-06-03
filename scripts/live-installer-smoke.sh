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
    elif [[ -e "${SEVENOS_TEST_CALAMARES_STARTED:-}" ]]; then
      printf '[{"class":"Calamares","title":"Install SevenOS"}]\n'
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
  if [[ "${SEVENOS_TEST_PORTAL_CRASH:-0}" == "1" ]]; then
    exit 42
  fi
  touch "$SEVENOS_TEST_PORTAL_STARTED"
  sleep 5
  exit 0
fi
if [[ "${1:-}" == "open" ]]; then
  if [[ "${SEVENOS_TEST_CALAMARES_CRASH:-0}" == "1" ]]; then
    exit 43
  fi
  touch "$SEVENOS_TEST_CALAMARES_STARTED"
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

for name in notify-send xdg-user-dirs-update seven-welcome dbus-update-activation-environment systemctl; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$tmp/bin/$name"
  chmod +x "$tmp/bin/$name"
done
cat >"$tmp/bin/nmcli" <<'SH'
#!/usr/bin/env bash
if [[ "${1:-}" == "-t" && "${*: -1}" == "general" ]]; then
  case "$*" in
    *CONNECTIVITY*) printf 'full\n' ;;
    *) printf 'connected\n' ;;
  esac
  exit 0
fi
if [[ "${1:-}" == "radio" ]]; then
  printf 'enabled\n'
  exit 0
fi
exit 0
SH
cat >"$tmp/bin/xhost" <<'SH'
#!/usr/bin/env bash
touch "$SEVENOS_TEST_XHOST_STARTED"
exit 0
SH
chmod +x "$tmp/bin/hyprctl" "$tmp/bin/calamares" "$tmp/bin/seven-installer" "$tmp/bin/sudo" "$tmp/bin/nmcli" "$tmp/bin/xhost"

status_file="$tmp/state/sevenos/live-status.json"
started_file="$tmp/calamares.started"
portal_file="$tmp/portal.started"
result_state="FAIL"
detail="live helper did not report a ready Calamares installer window"
exit_code=1

if SEVENOS_TEST_CALAMARES_STARTED="$started_file" \
  SEVENOS_TEST_PORTAL_STARTED="$portal_file" \
  HOME="$tmp/home" XDG_STATE_HOME="$tmp/state" XDG_CACHE_HOME="$tmp/cache" \
  PATH="$tmp/bin:/usr/bin:/bin" WAYLAND_DISPLAY=wayland-1 DISPLAY=:1 SEVENOS_ROOT="$ROOT_DIR" \
  timeout 14 "$ROOT_DIR/archiso/profile/airootfs/usr/local/bin/sevenos-live-ready" >/dev/null 2>&1; then
  if [[ -e "$started_file" && ! -e "$portal_file" && -r "$status_file" ]] && python - "$status_file" <<'PY' >/dev/null 2>&1
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
if data.get("state") != "ready":
    raise SystemExit(1)
if "Calamares installer is interactive" not in str(data.get("detail", "")):
    raise SystemExit(1)
PY
  then
    result_state="OK"
    detail="live helper opens Calamares directly and confirms its window"
    exit_code=0
  fi
fi

rm -f "$started_file" "$portal_file" "$status_file" "$tmp/state/sevenos/live-installer-opened" "$tmp/state/sevenos/live-first-screen-started"
rm -rf "$tmp/state/sevenos/live-ready.lock"
if SEVENOS_TEST_CALAMARES_STARTED="$started_file" \
  SEVENOS_TEST_PORTAL_STARTED="$portal_file" \
  SEVENOS_TEST_CALAMARES_CRASH=1 \
  HOME="$tmp/home" XDG_STATE_HOME="$tmp/state" XDG_CACHE_HOME="$tmp/cache" \
  PATH="$tmp/bin:/usr/bin:/bin" WAYLAND_DISPLAY=wayland-1 DISPLAY=:1 SEVENOS_ROOT="$ROOT_DIR" \
  timeout 24 "$ROOT_DIR/archiso/profile/airootfs/usr/local/bin/sevenos-live-ready" >/dev/null 2>&1; then
  if [[ ! -e "$started_file" && -e "$portal_file" && -r "$status_file" ]] && python - "$status_file" <<'PY' >/dev/null 2>&1
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
if data.get("state") != "ready":
    raise SystemExit(1)
if "SevenOS installer portal is interactive" not in str(data.get("detail", "")):
    raise SystemExit(1)
PY
  then
    if [[ "$result_state" == "OK" ]]; then
      detail="live helper opens Calamares directly and falls back to the SevenOS portal if needed"
    else
      result_state="PART"
      detail="portal fallback works, but the normal Calamares path failed"
      exit_code=1
    fi
  elif [[ "$result_state" == "OK" ]]; then
    result_state="FAIL"
    detail="live helper did not fall back to the SevenOS portal after an early Calamares close"
    exit_code=1
  fi
elif [[ "$result_state" == "OK" ]]; then
  result_state="FAIL"
  detail="live helper fallback scenario did not complete"
  exit_code=1
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
