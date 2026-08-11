#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

SOURCE_DIR="$ROOT_DIR/hyprland/waybar"
TARGET_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"
LOG_FILE="${TMPDIR:-/tmp}/waybar.log"

echo "SevenOS Waybar - Installation"
echo "Root   : $ROOT_DIR"
echo "Source : $SOURCE_DIR"
echo "Target : $TARGET_DIR"

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Waybar source directory missing:"
    echo "   $SOURCE_DIR"
    exit 1
fi

if [[ ! -s "$SOURCE_DIR/config.jsonc" ]]; then
    echo "Waybar config missing or empty:"
    echo "   $SOURCE_DIR/config.jsonc"
    exit 1
fi

if [[ ! -s "$SOURCE_DIR/style.css" ]]; then
    echo "Waybar stylesheet missing or empty:"
    echo "   $SOURCE_DIR/style.css"
    exit 1
fi

mkdir -p "$TARGET_DIR"

cp -a "$SOURCE_DIR/." "$TARGET_DIR/"

chmod 644 \
    "$TARGET_DIR/config.jsonc" \
    "$TARGET_DIR/style.css"

echo "Configuration copied"

if pids="$(pgrep -x waybar || true)" && [[ -n "$pids" ]]; then
    echo "Stopping existing Waybar..."
    kill $pids || true

    for _ in {1..10}; do
        if ! pgrep -x waybar >/dev/null 2>&1; then
            break
        fi
        sleep 0.1
    done
fi

: > "$LOG_FILE"

echo "Starting Waybar..."

waybar \
    -c "$TARGET_DIR/config.jsonc" \
    -s "$TARGET_DIR/style.css" \
    >"$LOG_FILE" 2>&1 &

WAYBAR_PID=$!

sleep 1

if ! kill -0 "$WAYBAR_PID" 2>/dev/null; then
    echo "Waybar failed to start."
    echo
    echo "Log:"
    cat "$LOG_FILE"
    exit 1
fi

echo "SevenOS Waybar started"
echo "   PID    : $WAYBAR_PID"
echo "   Config : $TARGET_DIR/config.jsonc"
echo "   Style  : $TARGET_DIR/style.css"
echo "   Log    : $LOG_FILE"