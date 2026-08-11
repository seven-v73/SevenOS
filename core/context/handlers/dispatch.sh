#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

source "$SCRIPT_DIR/common.sh"

dispatch() {
    local action="${1:-}"

    case "$action" in

        minimize_interruptions)
            dispatch_handler \
                "$SCRIPT_DIR/focus.sh" \
                minimize_interruptions
            ;;

        reduce_power_usage)
            dispatch_handler \
                "$SCRIPT_DIR/power.sh" \
                reduce_power_usage
            ;;

        adapt_network_services)
            dispatch_handler \
                "$SCRIPT_DIR/network.sh" \
                adapt_network_services
            ;;

        reduce_network_operations)
            dispatch_handler \
                "$SCRIPT_DIR/network.sh" \
                reduce_network_operations
            ;;

        prepare_creative_environment)
            dispatch_handler \
                "$SCRIPT_DIR/creative.sh" \
                prepare_creative_environment
            ;;

        reduce_attention_demands)
            dispatch_handler \
                "$SCRIPT_DIR/focus.sh" \
                reduce_attention_demands
            ;;

        notify_security)
            dispatch_handler \
                "$SCRIPT_DIR/security.sh" \
                notify_security
            ;;

        *)
            die "unknown action: $action"
            ;;

    esac
}

case "${1:-}" in

dispatch)
    [[ $# -ge 2 ]] || die "missing action"
    dispatch "$2"
    ;;

*)
    echo "Usage:"
    echo "  dispatch.sh dispatch <action>"
    exit 1
    ;;

esac
