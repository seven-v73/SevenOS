#!/usr/bin/env bash

set -Eeuo pipefail

HANDLERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() {
    echo "SevenOS Handler: $*" >&2
    exit 1
}

require_handler() {
    local handler="$1"

    [[ -x "$handler" ]] || {
        die "handler unavailable: $handler"
    }
}

dispatch_handler() {
    local handler="$1"
    shift

    require_handler "$handler"

    "$handler" "$@"
}
