#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

source "$SCRIPT_DIR/result.sh"

case "${1:-}" in

prepare_creative_environment)
    success \
        "prepare_creative_environment" \
        "creative" \
        "Creative environment prepared"
    ;;

*)
    echo "Usage:"
    echo "  creative.sh prepare_creative_environment"
    exit 1
    ;;

esac