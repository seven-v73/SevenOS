#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

source "$SCRIPT_DIR/result.sh"

case "${1:-}" in

notify_security)
    success \
        "notify_security" \
        "security" \
        "Security attention notification generated"
    ;;

*)
    echo "Usage:"
    echo "  security.sh notify_security"
    exit 1
    ;;

esac