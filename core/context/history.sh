#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# SevenOS Context History
# ============================================================

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

STATE_DIR="$SCRIPT_DIR/.context"
STATE_FILE="$STATE_DIR/context.json"

AUDIT_DIR="$SCRIPT_DIR/audit"
AUDIT_FILE="$AUDIT_DIR/events.jsonl"

mkdir -p "$STATE_DIR" "$AUDIT_DIR"

# ============================================================
# Helpers
# ============================================================

die() {
    echo "history.sh: $*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        die "required command unavailable: $1"
    }
}

require_command jq

# ============================================================
# State
# ============================================================

history_state_json() {
    if [[ ! -f "$STATE_FILE" ]]; then
        jq -n '
            {
                schema: "sevenos.context.state.v1",
                last_context: null,
                last_fingerprint: null,
                last_actions: [],
                updated_at: null
            }
        '
        return
    fi

    jq '.' "$STATE_FILE"
}

# ============================================================
# Audit source
# ============================================================

audit_exists() {
    [[ -f "$AUDIT_FILE" ]]
}

audit_count() {
    if audit_exists; then
        wc -l < "$AUDIT_FILE"
    else
        echo "0"
    fi
}

# ============================================================
# Status
# ============================================================

show_status_json() {
    history_state_json |
        jq '
            {
                schema: "sevenos.history.v1",
                state_schema: .schema,
                updated_at: .updated_at,
                fingerprint: .last_fingerprint,
                actions: .last_actions,
                audit_events: 0
            }
        ' |
        if audit_exists; then
            jq --slurpfile events "$AUDIT_FILE" '
                .audit_events = ($events | length)
            '
        else
            cat
        fi
}

show_status() {
    local updated
    local fingerprint
    local actions

    updated="$(
        jq -r '.updated_at // "never"' "$STATE_FILE" 2>/dev/null || echo "never"
    )"

    fingerprint="$(
        jq -c '.last_fingerprint // null' "$STATE_FILE" 2>/dev/null || echo "null"
    )"

    actions="$(
        jq '.last_actions | length' "$STATE_FILE" 2>/dev/null || echo "0"
    )"

    echo "SevenOS Context History"
    echo "───────────────────────"
    echo
    echo "Schema       : sevenos.context.state.v1"
    echo "Updated      : $updated"
    echo
    echo "Fingerprint  : $fingerprint"
    echo
    echo "Actions      : $actions"
}

# ============================================================
# Stats
# ============================================================

show_stats() {
    local total=0
    local executed=0
    local blocked=0
    local dry_run=0
    local failed=0
    local noop=0

    if audit_exists; then

        total="$(
            jq -s 'length' "$AUDIT_FILE"
        )"

        executed="$(
            jq -s '
                map(select(.execution == "executed"))
                | length
            ' "$AUDIT_FILE"
        )"

        blocked="$(
            jq -s '
                map(
                    select(
                        .execution == "blocked_by_mode"
                        or .execution == "blocked_by_risk"
                        or .execution == "blocked"
                    )
                )
                | length
            ' "$AUDIT_FILE"
        )"

        dry_run="$(
            jq -s '
                map(select(.execution == "dry_run"))
                | length
            ' "$AUDIT_FILE"
        )"

        failed="$(
            jq -s '
                map(
                    select(
                        .execution == "handler_failed"
                        or .execution == "invalid_handler_result"
                    )
                )
                | length
            ' "$AUDIT_FILE"
        )"

        noop="$(
            jq -s '
                map(select(.execution == "no_op"))
                | length
            ' "$AUDIT_FILE"
        )"
    fi

    echo "SevenOS Context History"
    echo "───────────────────────"
    echo
    echo "Total events : $total"
    echo "Executed     : $executed"
    echo "Blocked      : $blocked"
    echo "Dry-run      : $dry_run"
    echo "Failed       : $failed"
    echo "No-op        : $noop"
}

# ============================================================
# Recent
# ============================================================

show_recent_json() {
    local limit="${1:-10}"

    [[ "$limit" =~ ^[0-9]+$ ]] || {
        die "invalid history limit: $limit"
    }

    if ! audit_exists; then
        echo "[]"
        return
    fi

    jq -s \
        --argjson limit "$limit" '
        if $limit == 0 then
            []
        else
            .[-$limit:]
        end
        ' "$AUDIT_FILE"
}

show_recent() {
    local limit="${1:-10}"

    [[ "$limit" =~ ^[0-9]+$ ]] || {
        die "invalid history limit: $limit"
    }

    if ! audit_exists; then
        echo "No history."
        return
    fi

    jq -s \
        --argjson limit "$limit" '
        if $limit == 0 then
            []
        else
            .[-$limit:]
        end
        |
        .[] |
        "[\(.execution_mode)] \(.action)",
        "  time        : \(.timestamp)",
        "  execution   : \(.execution)",
        "  execution_id: \(.execution_id)",
        "  category    : \(.category)",
        "  priority    : \(.priority)",
        "  risk        : \(.risk)",
        ""
        ' "$AUDIT_FILE"
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

        show_stats

        ;;

    recent)

        limit="${2:-10}"

        if [[ "${3:-}" == "--json" ]]; then
            show_recent_json "$limit"
        else
            show_recent "$limit"
        fi

        ;;

    *)

        echo "Usage:"
        echo
        echo "  history.sh status"
        echo "  history.sh status --json"
        echo "  history.sh stats"
        echo "  history.sh recent"
        echo "  history.sh recent 20"
        echo "  history.sh recent 20 --json"

        exit 1

        ;;

esac