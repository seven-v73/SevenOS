#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/result.sh"

die() {
    echo "focus.sh: $*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        die "required command not found: $1"
    }
}

minimize_interruptions() {

    require_command hyprctl

    success \
        "minimize_interruptions" \
        "focus" \
        "Focus environment prepared"
}

reduce_attention_demands() {

    require_command hyprctl

    success \
        "reduce_attention_demands" \
        "focus" \
        "Attention demands reduced"
}

case "${1:-}" in

minimize_interruptions)
    minimize_interruptions
    ;;

reduce_attention_demands)
    reduce_attention_demands
    ;;

*)
    echo "Usage:"
    echo "  focus.sh minimize_interruptions"
    echo "  focus.sh reduce_attention_demands"
    exit 1
    ;;

esac