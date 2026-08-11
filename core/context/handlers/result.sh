#!/usr/bin/env bash

set -Eeuo pipefail

result() {
    local action="$1"
    local handler="$2"
    local status="$3"
    local message="$4"

    jq -n \
        --arg action "$action" \
        --arg handler "$handler" \
        --arg status "$status" \
        --arg message "$message" \
        '{
            schema: "sevenos.execution.result.v1",
            timestamp: (now | todateiso8601),
            action: $action,
            handler: $handler,
            status: $status,
            message: $message
        }'
}

success() {
    local action="$1"
    local handler="$2"
    local message="$3"

    result \
        "$action" \
        "$handler" \
        "success" \
        "$message"
}

failure() {
    local action="$1"
    local handler="$2"
    local message="$3"

    result \
        "$action" \
        "$handler" \
        "failure" \
        "$message"
}
