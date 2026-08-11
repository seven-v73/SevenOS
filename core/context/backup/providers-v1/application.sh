#!/usr/bin/env bash

set -Eeuo pipefail

if command -v hyprctl >/dev/null 2>&1; then
    hyprctl activewindow -j 2>/dev/null \
        | jq -r '.class // "unknown"' 2>/dev/null \
        || echo "unknown"
else
    echo "unknown"
fi
