#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# SevenOS Context Executor
#
# Authorization boundary between proposed actions and handlers.
#
# executor.sh:
#
# - validates action contracts
# - determines whether an action may execute
# - supports dry-run / apply
# - delegates execution to handlers/dispatch.sh
# - returns structured execution results
#
# executor.sh does NOT implement action behavior.
#
# Contract:
#
# sevenos.execution.v1
# ============================================================

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

HANDLER_DISPATCHER="$SCRIPT_DIR/handlers/dispatch.sh"

MODE="dry-run"

EXECUTION_ID="exec-$(date -u +%Y%m%dT%H%M%SZ)-$$-${RANDOM}"

# ============================================================
# Input
# ============================================================

get_actions() {
    if [[ ! -t 0 ]]; then
        cat
    else
        "$SCRIPT_DIR/action.sh" status --json
    fi
}

# ============================================================
# Validation
# ============================================================

validate_actions() {
    local input="$1"

    jq -e '
        (.schema == "sevenos.actions.v1")
        and (.actions | type == "array")
        and all(
            .actions[];
            (.id | type == "string")
            and (.source | type == "string")
            and (.category | type == "string")
            and (.priority | IN("high", "medium", "low"))
            and (.mode | IN("automatic", "notify", "confirmation", "blocked"))
            and (.risk | IN("low", "medium", "high"))
            and (.status == "proposed")
        )
    ' <<< "$input" >/dev/null
}

# ============================================================
# Authorization
# ============================================================

is_executable() {
    local action="$1"
    local mode="$2"
    local risk="$3"

    [[ "$mode" == "automatic" ]] || return 1
    [[ "$risk" != "high" ]] || return 1

    case "$action" in
        reduce_power_usage)
            return 0
            ;;

        adapt_network_services)
            return 0
            ;;

        reduce_network_operations)
            return 0
            ;;

        minimize_interruptions)
            return 0
            ;;

        prepare_creative_environment)
            return 0
            ;;

        reduce_attention_demands)
            return 0
            ;;

        *)
            return 1
            ;;
    esac
}

# ============================================================
# Handler execution
# ============================================================

run_handler() {
    local action="$1"

    [[ -x "$HANDLER_DISPATCHER" ]] || {
        echo "executor.sh: handler dispatcher unavailable" >&2
        return 1
    }

    "$HANDLER_DISPATCHER" dispatch "$action"
}

# ============================================================
# Execute one action
# ============================================================

execute_one() {
    local action_json="$1"

    local id
    local source
    local category
    local priority
    local mode
    local risk
    local status

    id="$(jq -r '.id' <<< "$action_json")"
    source="$(jq -r '.source' <<< "$action_json")"
    category="$(jq -r '.category' <<< "$action_json")"
    priority="$(jq -r '.priority' <<< "$action_json")"
    mode="$(jq -r '.mode' <<< "$action_json")"
    risk="$(jq -r '.risk' <<< "$action_json")"
    status="$(jq -r '.status' <<< "$action_json")"

    if [[ "$status" != "proposed" ]]; then
        jq -n \
            --arg id "$id" \
            --arg source "$source" \
            --arg category "$category" \
            --arg priority "$priority" \
            --arg mode "$mode" \
            --arg risk "$risk" \
            '{
                id: $id,
                source: $source,
                category: $category,
                priority: $priority,
                mode: $mode,
                risk: $risk,
                executable: false,
                execution: "invalid_status"
            }'

        return 0
    fi

    if ! is_executable "$id" "$mode" "$risk"; then
        local reason="blocked"

        if [[ "$mode" != "automatic" ]]; then
            reason="blocked_by_mode"
        elif [[ "$risk" == "high" ]]; then
            reason="blocked_by_risk"
        else
            reason="unsupported"
        fi

        jq -n \
            --arg id "$id" \
            --arg source "$source" \
            --arg category "$category" \
            --arg priority "$priority" \
            --arg mode "$mode" \
            --arg risk "$risk" \
            --arg execution "$reason" \
            '{
                id: $id,
                source: $source,
                category: $category,
                priority: $priority,
                mode: $mode,
                risk: $risk,
                executable: false,
                execution: $execution
            }'

        return 0
    fi

    if [[ "$MODE" == "dry-run" ]]; then
        jq -n \
            --arg id "$id" \
            --arg source "$source" \
            --arg category "$category" \
            --arg priority "$priority" \
            --arg mode "$mode" \
            --arg risk "$risk" \
            '{
                id: $id,
                source: $source,
                category: $category,
                priority: $priority,
                mode: $mode,
                risk: $risk,
                executable: true,
                execution: "dry_run"
            }'

        return 0
    fi

    local result

    if result="$(run_handler "$id")"; then

        if jq -e '.schema == "sevenos.execution.result.v1"' \
            <<< "$result" >/dev/null 2>&1; then

            jq -n \
                --argjson result "$result" \
                --arg id "$id" \
                --arg source "$source" \
                --arg category "$category" \
                --arg priority "$priority" \
                --arg mode "$mode" \
                --arg risk "$risk" \
                '{
                    id: $id,
                    source: $source,
                    category: $category,
                    priority: $priority,
                    mode: $mode,
                    risk: $risk,
                    executable: true,
                    execution: "executed",
                    result: $result
                }'

        else

            jq -n \
                --arg id "$id" \
                --arg source "$source" \
                --arg category "$category" \
                --arg priority "$priority" \
                --arg mode "$mode" \
                --arg risk "$risk" \
                '{
                    id: $id,
                    source: $source,
                    category: $category,
                    priority: $priority,
                    mode: $mode,
                    risk: $risk,
                    executable: true,
                    execution: "invalid_handler_result"
                }'

            return 1
        fi

    else

        jq -n \
            --arg id "$id" \
            --arg source "$source" \
            --arg category "$category" \
            --arg priority "$priority" \
            --arg mode "$mode" \
            --arg risk "$risk" \
            '{
                id: $id,
                source: $source,
                category: $category,
                priority: $priority,
                mode: $mode,
                risk: $risk,
                executable: true,
                execution: "handler_failed"
            }'

        return 1
    fi
}

# ============================================================
# Execute all
# ============================================================

execute_actions() {
    local input="$1"

    validate_actions "$input" || {
        echo "executor.sh: invalid action contract" >&2
        return 1
    }

    jq -c '.actions[]' <<< "$input" |
    while read -r action; do
        execute_one "$action"
    done
}

# ============================================================
# JSON result
# ============================================================

show_status_json() {
    local actions
    local executions

    actions="$(get_actions)"

    validate_actions "$actions" || {
        echo "executor.sh: invalid action contract" >&2
        exit 1
    }

    executions="$(
        execute_actions "$actions" |
        jq -s .
    )"
    executions="$(
    jq \
        --arg execution_id "$EXECUTION_ID" \
        'map(. + {execution_id: $execution_id})' \
        <<< "$executions"
    )"

    jq -n \
        --arg mode "$MODE" \
        --arg policy_schema "$(jq -r '.source.policy_schema' <<< "$actions")" \
        --argjson executions "$executions" \
        '{
            schema: "sevenos.execution.v1",

            mode: $mode,

            source: {
                action_schema: "sevenos.actions.v1",
                policy_schema: $policy_schema
            },

            executions: $executions
        }'
}

# ============================================================
# Human readable
# ============================================================

show_status() {
    local result

    result="$(show_status_json)"

    echo "SevenOS Executor"
    echo "────────────────"
    echo
    echo "Mode : $MODE"
    echo

    jq -r '
        .executions[] |
        if .execution == "executed" and .result.status == "success" then
            "SUCCESS: \(.id) → \(.result.message)"

        elif .execution == "dry_run" then
            "DRY-RUN: \(.id)"

        else
            "SKIP: \(.id) (\(.execution))"
        end
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

--dry-run)
    MODE="dry-run"

    if [[ "${2:-}" == "--json" ]]; then
        show_status_json
    else
        show_status
    fi
    ;;

--apply)
    MODE="apply"

    if [[ "${2:-}" == "--json" ]]; then
        show_status_json
    else
        show_status
    fi
    ;;

*)
    echo "Usage:"
    echo "  executor.sh status"
    echo "  executor.sh status --json"
    echo "  executor.sh --dry-run"
    echo "  executor.sh --dry-run --json"
    echo "  executor.sh --apply"
    echo "  executor.sh --apply --json"
    echo
    echo "  action.sh status --json | executor.sh --dry-run"
    exit 1
    ;;

esac
