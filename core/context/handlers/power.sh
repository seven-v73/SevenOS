#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

source "$SCRIPT_DIR/result.sh"

case "${1:-}" in

reduce_power_usage)
    success \
        "reduce_power_usage" \
        "power" \
        "Power usage reduction prepared"
    ;;

*)
    echo "Usage:"
    echo "  power.sh reduce_power_usage"
    exit 1
    ;;

esac