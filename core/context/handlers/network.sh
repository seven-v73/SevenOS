#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

source "$SCRIPT_DIR/result.sh"

case "${1:-}" in

adapt_network_services)
    success \
        "adapt_network_services" \
        "network" \
        "Network services adapted"
    ;;

reduce_network_operations)
    success \
        "reduce_network_operations" \
        "network" \
        "Network operations reduced"
    ;;

*)
    echo "Usage:"
    echo "  network.sh adapt_network_services"
    echo "  network.sh reduce_network_operations"
    exit 1
    ;;

esac