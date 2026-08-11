#!/usr/bin/env bash

set -Eeuo pipefail

if command -v wpctl >/dev/null 2>&1; then
    wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null \
        | awk '{print int($2 * 100)}' \
        || echo "unknown"
else
    echo "unknown"
fi
