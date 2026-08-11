#!/usr/bin/env bash

set -Eeuo pipefail

for battery in /sys/class/power_supply/BAT*; do
    if [[ -r "$battery/capacity" ]]; then
        cat "$battery/capacity"
        exit 0
    fi
done

echo "unknown"
