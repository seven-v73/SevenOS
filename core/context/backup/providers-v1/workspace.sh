#!/usr/bin/env bash

set -Eeuo pipefail

if command -v hyprctl >/dev/null 2>&1; then
    hyprctl activeworkspace -j 2>/dev/null \
        | jq -r '.id // 1' 2>/dev/null \
        || echo "1"
else
    echo "1"
fi
