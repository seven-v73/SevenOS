#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# SevenOS Context History Engine
#
# Reads the audit stream and provides historical context.
#
# IMPORTANT:
#
# history.sh does not decide.
# history.sh does not execute.
# history.sh does not modify audit events.
#
# It only reads and summarizes historical execution data.
#
# Contract:
#
#   sevenos.history.v1
# ============================================================

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

AUDIT_FILE="$SCRIPT_DIR/audit/events.jsonl"

# ============================================================
# Validation
# ============================================================

require_audit_file() {
    [[ -f "$AUDIT_FILE" ]] || {
        echo "history.sh: audit file not found: $AUDIT_FILE" >&2
        return 1
    }
}

# ============================================================
# Input
# ============================================================

get_events() {
    require_audit_file

    cat "$AUDIT_FILE"
}

# ============================================================
# JSON history
# ============================================================

show_status_json() {
    local events

    if [[ ! -f "$AUDIT_FILE" ]]; then
        jq -n \
            '{
                schema: "sevenos.history.v1",
                source: {
                    audit_schema: "sevenos.audit.event.v1"
                },
                count: 0,
                events: []
            }'

        return 0
    fi

    events="$(
        jq -s '
            map(
                select(.schema == "sevenos.audit.event.v1")
            )
        ' "$AUDIT_FILE"
    )"

    jq -n \
        --arg audit_schema "sevenos.audit.event.v1" \
        --argjson events "$events" \
        '{
            schema: "sevenos.history.v1",

            source: {
                audit_schema: $audit_schema
            },

            count: ($events | length),

            events: $events
        }'
}

# ============================================================
# Statistics
# ============================================================

show_stats_json() {
    local events

    if [[ ! -f "$AUDIT_FILE" ]]; then
        jq -n '
            {
                schema: "sevenos.history.stats.v1",
                total: 0,
                executed: 0,
                blocked: 0,
                dry_run: 0,
                failures: 0,
                successes: 0
            }
        '

        return 0
    fi

    events="$(
        jq -s '
            map(
                select(.schema == "sevenos.audit.event.v1")
            )
        ' "$AUDIT_FILE"
    )"

    jq -n \
        --argjson events "$events" \
        '{
            schema: "sevenos.history.stats.v1",

            total: ($events | length),

            executed: (
                $events
                | map(select(.execution == "executed"))
                | length
            ),

            blocked: (
                $events
                | map(select(.execution | startswith("blocked")))
                | length
            ),

            dry_run: (
                $events
                | map(select(.execution == "dry_run"))
                | length
            ),

            failures: (
                $events
                | map(
                    select(
                        .execution == "handler_failed"
                        or
                        (.result.status? == "failure")
                    )
                )
                | length
            ),

            successes: (
                $events
                | map(
                    select(
                        .result.status? == "success"
                    )
                )
                | length
            )
        }'
}

# ============================================================
# Recent events
# ============================================================

show_recent_json() {
    local limit="${1:-10}"

    [[ "$limit" =~ ^[0-9]+$ ]] || {
        echo "history.sh: invalid limit: $limit" >&2
        return 1
    }

    if [[ ! -f "$AUDIT_FILE" ]]; then
        jq -n \
            --argjson limit "$limit" \
            '{
                schema: "sevenos.history.recent.v1",
                limit: $limit,
                events: []
            }'

        return 0
    fi

    jq -s \
        --argjson limit "$limit" '
        {
            schema: "sevenos.history.recent.v1",
            limit: $limit,
            events: (
                . |
                reverse |
                .[0:$limit] |
                reverse
            )
        }
    ' "$AUDIT_FILE"
}

# ============================================================
# Human readable
# ============================================================

show_status() {
    local result

    result="$(show_status_json)"

    echo "SevenOS History"
    echo "───────────────"
    echo
    echo "Events : $(jq -r '.count' <<< "$result")"
    echo

    jq -r '
        .events[] |
        "[\(.execution)] \(.action)\n" +
        "  timestamp : \(.timestamp)\n" +
        "  category  : \(.category)\n" +
        "  priority  : \(.priority)\n" +
        "  risk      : \(.risk)"
    ' <<< "$result"
}

# ============================================================
# CLI
# ============================================================

case "${1:-status}" in

status)
    if [[ "${2:-}" == "--json" ]]; then
        show_status_json
    else
        show_status
    fi
    ;;

stats)
    show_stats_json
    ;;

recent)
    limit="${2:-10}"

    show_recent_json "$limit"
    ;;

count)
    if [[ ! -f "$AUDIT_FILE" ]]; then
        echo "0"
    else
        wc -l < "$AUDIT_FILE"
    fi
    ;;

*)
    echo "Usage:"
    echo "  history.sh status"
    echo "  history.sh status --json"
    echo "  history.sh stats"
    echo "  history.sh recent [limit]"
    echo "  history.sh count"
    exit 1
    ;;

esac
