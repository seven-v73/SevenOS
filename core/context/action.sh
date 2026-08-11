#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# SevenOS Context Action Engine
#
# Converts governed policies into executable action proposals.
#
# Contract:
#   input  -> sevenos.policy.v1
#   output -> sevenos.actions.v1
#
# IMPORTANT:
#
# action.sh NEVER executes actions.
# It only creates action proposals.
# ============================================================

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

# ============================================================
# Input
# ============================================================

get_policies() {
    if [[ ! -t 0 ]]; then
        cat
    else
        "$SCRIPT_DIR/policy.sh" status --json
    fi
}

# ============================================================
# Validation
# ============================================================

validate_policies() {
    local input="$1"

    jq -e '
        .schema == "sevenos.policy.v1"
        and (.policies | type == "array")
        and all(
            .policies[];
            (.id | type == "string")
            and (.category | type == "string")
            and (.priority | IN("high", "medium", "low"))
            and (.allowed | type == "boolean")
            and (.mode | IN("automatic", "notify", "confirmation", "blocked"))
            and (.risk | IN("low", "medium", "high"))
            and (.actions | type == "array")
        )
    ' <<< "$input" >/dev/null
}

# ============================================================
# Action mapping
# ============================================================

build_actions() {
    local input="$1"

    jq '
        [
            .policies[]
            | select(.allowed == true)
            | . as $policy
            | $policy.actions[]
            | {
                id: .,
                source: $policy.id,
                category: $policy.category,
                priority: $policy.priority,
                mode: $policy.mode,
                risk: $policy.risk,
                status: "proposed"
            }
        ]
    ' <<< "$input"
}

# ============================================================
# Complete result
# ============================================================

show_status_json() {
    local policies
    local actions

    policies="$(get_policies)"

    validate_policies "$policies" || {
        echo "action.sh: invalid policy contract" >&2
        return 1
    }

    actions="$(build_actions "$policies")"

    jq -n \
        --arg policy_schema "$(jq -r '.schema' <<< "$policies")" \
        --argjson actions "$actions" \
        '{
            schema: "sevenos.actions.v1",

            source: {
                policy_schema: $policy_schema
            },

            actions: $actions
        }'
}

# ============================================================
# Human readable
# ============================================================

show_status() {
    local result
    local count

    result="$(show_status_json)"
    count="$(jq '.actions | length' <<< "$result")"

    echo "SevenOS Actions"
    echo "───────────────"
    echo
    echo "Actions : $count"

    if [[ "$count" -eq 0 ]]; then
        echo
        echo "No actions proposed."
        return 0
    fi

    echo

    jq -r '
        .actions[] |
        "[\(.mode)] \(.id)\n" +
        "  source   : \(.source)\n" +
        "  category : \(.category)\n" +
        "  priority : \(.priority)\n" +
        "  risk     : \(.risk)\n" +
        "  status   : \(.status)"
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

get)
    [[ $# -ge 2 ]] || {
        echo "Missing action key" >&2
        exit 1
    }

    result="$(show_status_json)"

    case "$2" in
        all)
            jq '.actions' <<< "$result"
            ;;

        count)
            jq '.actions | length' <<< "$result"
            ;;

        *)
            jq --arg id "$2" '
                .actions[]
                | select(.id == $id)
            ' <<< "$result"
            ;;
    esac
    ;;

*)
    echo "Usage:"
    echo "  action.sh status"
    echo "  action.sh status --json"
    echo "  action.sh get all"
    echo "  action.sh get count"
    echo "  action.sh get <action-id>"
    echo "  policy.sh status --json | action.sh status"
    exit 1
    ;;

esac
