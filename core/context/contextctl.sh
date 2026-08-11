#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# SevenOS Context Control Interface
#
# Unified CLI for the SevenOS Context engine.
#
# This script is an interface layer.
#
# It does NOT:
#   - make decisions
#   - implement policies
#   - execute handlers directly
#
# It delegates to the existing context components.
#
# ============================================================

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

STATE="$SCRIPT_DIR/state.sh"
DECISION="$SCRIPT_DIR/decision.sh"
POLICY="$SCRIPT_DIR/policy.sh"
ACTION="$SCRIPT_DIR/action.sh"
EXECUTOR="$SCRIPT_DIR/executor.sh"
AUDIT="$SCRIPT_DIR/audit.sh"
HISTORY="$SCRIPT_DIR/history.sh"

# ============================================================
# Validation
# ============================================================

require_component() {
    local component="$1"

    [[ -x "$component" ]] || {
        echo "contextctl.sh: component unavailable: $component" >&2
        exit 1
    }
}

require_all_components() {
    require_component "$STATE"
    require_component "$DECISION"
    require_component "$POLICY"
    require_component "$ACTION"
    require_component "$EXECUTOR"
    require_component "$AUDIT"
    require_component "$HISTORY"
}

# ============================================================
# State
# ============================================================

show_state() {
    "$STATE" status
}

show_state_json() {
    "$STATE" status --json
}

# ============================================================
# Decisions
# ============================================================

show_decisions() {
    "$DECISION" status
}

show_decisions_json() {
    "$DECISION" status --json
}

# ============================================================
# Policies
# ============================================================

show_policies() {
    "$POLICY" status
}

show_policies_json() {
    "$POLICY" status --json
}

# ============================================================
# Actions
# ============================================================

show_actions() {
    "$ACTION" status
}

show_actions_json() {
    "$ACTION" status --json
}

# ============================================================
# Execution
# ============================================================

execute_dry_run() {
    "$EXECUTOR" --dry-run
}

execute_dry_run_json() {
    "$EXECUTOR" --dry-run --json
}

execute_apply() {
    "$EXECUTOR" --apply
}

execute_apply_json() {
    "$EXECUTOR" --apply --json
}

# ============================================================
# Audit
# ============================================================

show_audit() {
    "$AUDIT" status
}

show_audit_json() {
    "$AUDIT" status --json
}

show_audit_events() {
    "$AUDIT" events
}

show_audit_count() {
    "$AUDIT" count
}

# ============================================================
# History
# ============================================================

show_history() {
    "$HISTORY" status
}

show_history_json() {
    "$HISTORY" status --json
}

show_history_stats() {
    "$HISTORY" stats
}

show_history_recent() {
    "$HISTORY" recent "${1:-10}"
}

# ============================================================
# Full status
# ============================================================

show_status_json() {
    jq -n \
        --argjson state "$("$STATE" status --json)" \
        --argjson decisions "$("$DECISION" status --json)" \
        --argjson policies "$("$POLICY" status --json)" \
        --argjson actions "$("$ACTION" status --json)" \
        --argjson execution "$("$EXECUTOR" --dry-run --json)" \
        --argjson history "$("$HISTORY" status --json)" \
        '{
            schema: "sevenos.context.v1",

            state: $state,

            decisions: $decisions,

            policies: $policies,

            actions: $actions,

            execution: $execution,

            history: $history
        }'
}

show_status() {
    echo "SevenOS Context"
    echo "═══════════════"
    echo

    echo "STATE"
    echo "─────"
    "$STATE" status
    echo

    echo "DECISIONS"
    echo "─────────"
    "$DECISION" status
    echo

    echo "POLICIES"
    echo "────────"
    "$POLICY" status
    echo

    echo "ACTIONS"
    echo "───────"
    "$ACTION" status
    echo

    echo "EXECUTION"
    echo "─────────"
    "$EXECUTOR" --dry-run
    echo

    echo "HISTORY"
    echo "───────"
    "$HISTORY" stats
}

# ============================================================
# CLI
# ============================================================

require_all_components

case "${1:-status}" in

status)
    if [[ "${2:-}" == "--json" ]]; then
        show_status_json
    else
        show_status
    fi
    ;;

state)
    if [[ "${2:-}" == "--json" ]]; then
        show_state_json
    else
        show_state
    fi
    ;;

decisions)
    if [[ "${2:-}" == "--json" ]]; then
        show_decisions_json
    else
        show_decisions
    fi
    ;;

policies)
    if [[ "${2:-}" == "--json" ]]; then
        show_policies_json
    else
        show_policies
    fi
    ;;

actions)
    if [[ "${2:-}" == "--json" ]]; then
        show_actions_json
    else
        show_actions
    fi
    ;;

execute)
    case "${2:-dry-run}" in

        dry-run)
            if [[ "${3:-}" == "--json" ]]; then
                execute_dry_run_json
            else
                execute_dry_run
            fi
            ;;

        apply)
            if [[ "${3:-}" == "--json" ]]; then
                execute_apply_json
            else
                execute_apply
            fi
            ;;

        *)
            echo "Unknown execution mode: $2" >&2
            exit 1
            ;;

    esac
    ;;

audit)
    case "${2:-status}" in

        status)
            if [[ "${3:-}" == "--json" ]]; then
                show_audit_json
            else
                show_audit
            fi
            ;;

        events)
            show_audit_events
            ;;

        count)
            show_audit_count
            ;;

        *)
            echo "Unknown audit command: $2" >&2
            exit 1
            ;;

    esac
    ;;

history)
    case "${2:-status}" in

        status)
            if [[ "${3:-}" == "--json" ]]; then
                show_history_json
            else
                show_history
            fi
            ;;

        stats)
            show_history_stats
            ;;

        recent)
            show_history_recent "${3:-10}"
            ;;

        *)
            echo "Unknown history command: $2" >&2
            exit 1
            ;;

    esac
    ;;

*)
    echo "SevenOS Context"
    echo
    echo "Usage:"
    echo
    echo "  contextctl.sh status [--json]"
    echo "  contextctl.sh state [--json]"
    echo "  contextctl.sh decisions [--json]"
    echo "  contextctl.sh policies [--json]"
    echo "  contextctl.sh actions [--json]"
    echo
    echo "  contextctl.sh execute dry-run [--json]"
    echo "  contextctl.sh execute apply [--json]"
    echo
    echo "  contextctl.sh audit status [--json]"
    echo "  contextctl.sh audit events"
    echo "  contextctl.sh audit count"
    echo
    echo "  contextctl.sh history status [--json]"
    echo "  contextctl.sh history stats"
    echo "  contextctl.sh history recent [limit]"
    exit 1
    ;;

esac
