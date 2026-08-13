#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# SevenOS Context Control
# ============================================================
#
# User-facing CLI for the SevenOS Context Engine.
#
# contextctl is intentionally thin.
#
# It does not:
# - make decisions
# - evaluate policies
# - execute handlers directly
#
# It controls:
#
#                 contextctl
#                     │
#                     ▼
#                 contextd
#                     │
#        ┌────────────┼────────────┐
#        ▼            ▼            ▼
#      state       decision      policy
#        │            │            │
#        └────────────┼────────────┘
#                     ▼
#                   action
#                     │
#                     ▼
#                  executor
#                     │
#                     ▼
#                  handler
#                     │
#                     ▼
#                   audit
#
# ============================================================

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

CONTEXTD="$SCRIPT_DIR/contextd.sh"
STATE="$SCRIPT_DIR/state.sh"
DECISION="$SCRIPT_DIR/decision.sh"
POLICY="$SCRIPT_DIR/policy.sh"
ACTION="$SCRIPT_DIR/action.sh"
EXECUTOR="$SCRIPT_DIR/executor.sh"
AUDIT="$SCRIPT_DIR/audit.sh"
HISTORY="$SCRIPT_DIR/history.sh"

RUNTIME_DIR="$SCRIPT_DIR/.context"
PID_FILE="$RUNTIME_DIR/contextd.pid"
LOG_FILE="$RUNTIME_DIR/contextd.log"

# ============================================================
# Validation
# ============================================================

require_command() {
    local command_name="$1"

    command -v "$command_name" >/dev/null 2>&1 || {
        echo "contextctl: required command unavailable: $command_name" >&2
        exit 1
    }
}

require_component() {
    local component="$1"

    [[ -x "$component" ]] || {
        echo "contextctl: component unavailable: $component" >&2
        exit 1
    }
}

require_components() {
    require_command jq

    require_component "$CONTEXTD"
    require_component "$STATE"
    require_component "$DECISION"
    require_component "$POLICY"
    require_component "$ACTION"
    require_component "$EXECUTOR"
    require_component "$AUDIT"
    require_component "$HISTORY"
}

# ============================================================
# Runtime directory
# ============================================================

init_runtime() {
    mkdir -p "$RUNTIME_DIR"
}

# ============================================================
# Daemon process detection
# ============================================================

daemon_pid() {

    if [[ ! -f "$PID_FILE" ]]; then
        return 1
    fi

    local pid

    pid="$(cat "$PID_FILE" 2>/dev/null || true)"

    [[ "$pid" =~ ^[0-9]+$ ]] || return 1

    echo "$pid"
}

daemon_running() {

    local pid

    pid="$(daemon_pid)" || return 1

    kill -0 "$pid" 2>/dev/null
}

# ============================================================
# Cleanup stale PID
# ============================================================

cleanup_stale_pid() {

    if [[ -f "$PID_FILE" ]] && ! daemon_running; then
        rm -f "$PID_FILE"
    fi
}

# ============================================================
# State
# ============================================================

show_state() {

    if [[ "${1:-}" == "--json" ]]; then
        "$STATE" status --json
    else
        "$STATE" status
    fi
}

# ============================================================
# Decisions
# ============================================================

show_decisions() {

    if [[ "${1:-}" == "--json" ]]; then
        "$DECISION" status --json
    else
        "$DECISION" status
    fi
}

# ============================================================
# Policies
# ============================================================

show_policies() {

    if [[ "${1:-}" == "--json" ]]; then
        "$POLICY" status --json
    else
        "$POLICY" status
    fi
}

# ============================================================
# Actions
# ============================================================

show_actions() {

    if [[ "${1:-}" == "--json" ]]; then
        "$ACTION" status --json
    else
        "$ACTION" status
    fi
}

# ============================================================
# Execution
# ============================================================

execute_context() {

    local mode="${1:-dry-run}"
    local json="${2:-}"

    case "$mode" in

        dry-run)
            if [[ "$json" == "--json" ]]; then
                "$CONTEXTD" --dry-run --json
            else
                "$CONTEXTD" --dry-run
            fi
            ;;

        apply)
            if [[ "$json" == "--json" ]]; then
                "$CONTEXTD" --apply --json
            else
                "$CONTEXTD" --apply
            fi
            ;;

        *)
            echo "contextctl: invalid execution mode: $mode" >&2
            exit 1
            ;;

    esac
}

# ============================================================
# Once
# ============================================================

run_once() {

    local mode="dry-run"
    local json=""

    while (($# > 0)); do

        case "$1" in

            --apply)
                mode="apply"
                ;;

            --dry-run)
                mode="dry-run"
                ;;

            --json)
                json="--json"
                ;;

            *)
                echo "contextctl: unknown once option: $1" >&2
                exit 1
                ;;

        esac

        shift
    done

    execute_context "$mode" "$json"
}

# ============================================================
# Daemon status
# ============================================================

daemon_status() {

    cleanup_stale_pid

    echo "SevenOS Context Daemon"
    echo "──────────────────────"
    echo

    if daemon_running; then

        local pid

        pid="$(daemon_pid)"

        echo "Status   : running"
        echo "PID      : $pid"
        echo "Interval : managed by contextd"
        echo "Log      : $LOG_FILE"

    else

        echo "Status   : stopped"
        echo "PID      : none"
        echo "Log      : $LOG_FILE"

    fi
}

# ============================================================
# Daemon start
# ============================================================

daemon_start() {

    local mode="dry-run"

    if [[ "${1:-}" == "--apply" ]]; then
        mode="apply"
    elif [[ "${1:-}" == "--dry-run" || -z "${1:-}" ]]; then
        mode="dry-run"
    else
        echo "contextctl: unknown daemon option: $1" >&2
        exit 1
    fi

    init_runtime
    cleanup_stale_pid

    if daemon_running; then
        echo "SevenOS Context Daemon is already running."
        echo "PID: $(daemon_pid)"
        return 0
    fi

    : > "$LOG_FILE"

    if [[ "$mode" == "apply" ]]; then

        nohup "$CONTEXTD" daemon --apply \
            >> "$LOG_FILE" 2>&1 &

    else

        nohup "$CONTEXTD" daemon --dry-run \
            >> "$LOG_FILE" 2>&1 &

    fi

    local pid="$!"

    printf '%s\n' "$pid" > "$PID_FILE"

    sleep 0.2

    if ! kill -0 "$pid" 2>/dev/null; then
        echo "contextctl: daemon failed to start." >&2
        rm -f "$PID_FILE"
        echo
        tail -n 20 "$LOG_FILE" >&2 || true
        exit 1
    fi

    echo "SevenOS Context Daemon started."
    echo
    echo "PID  : $pid"
    echo "Mode : $mode"
    echo "Log  : $LOG_FILE"
}

# ============================================================
# Daemon stop
# ============================================================

daemon_stop() {

    if ! daemon_running; then
        cleanup_stale_pid
        echo "SevenOS Context Daemon is not running."
        return 0
    fi

    local pid

    pid="$(daemon_pid)"

    echo "Stopping SevenOS Context Daemon..."
    kill "$pid"

    for _ in {1..20}; do

        if ! kill -0 "$pid" 2>/dev/null; then
            rm -f "$PID_FILE"
            echo "SevenOS Context Daemon stopped."
            return 0
        fi

        sleep 0.1
    done

    echo "contextctl: daemon did not stop gracefully." >&2
    echo "Sending SIGKILL..." >&2

    kill -KILL "$pid" 2>/dev/null || true
    rm -f "$PID_FILE"

    echo "SevenOS Context Daemon stopped."
}

# ============================================================
# Full status
# ============================================================

show_status() {

    local json="${1:-}"

    if [[ "$json" == "--json" ]]; then

        local state
        local decisions
        local policies
        local actions
        local execution
        local history

        state="$("$STATE" status --json)"
        decisions="$("$DECISION" status --json <<< "$state")"
        policies="$("$POLICY" status --json <<< "$decisions")"
        actions="$("$ACTION" status --json <<< "$policies")"
        execution="$("$EXECUTOR" --dry-run --json <<< "$actions")"
        history="$("$HISTORY" status --json)"

        jq -n \
            --argjson state "$state" \
            --argjson decisions "$decisions" \
            --argjson policies "$policies" \
            --argjson actions "$actions" \
            --argjson execution "$execution" \
            --argjson history "$history" \
            '
            {
                schema: "sevenos.contextctl.status.v1",
                state: $state,
                decisions: $decisions,
                policies: $policies,
                actions: $actions,
                execution: $execution,
                history: $history
            }
            '

        return 0
    fi

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
    "$EXECUTOR" --dry-run --json |
        jq -r '
            "SevenOS Executor",
            "────────────────",
            "",
            "Mode : \(.mode)",
            "",
            (
                .executions[] |
                if .execution == "dry_run" then
                    "DRY-RUN: \(.id)"
                else
                    "SKIP: \(.id) (\(.execution))"
                end
            )
        '

    echo
    echo "HISTORY"
    echo "───────"

    "$HISTORY" status
}

# ============================================================
# Audit
# ============================================================

audit_command() {

    case "${1:-status}" in

        status)
            if [[ "${2:-}" == "--json" ]]; then
                "$AUDIT" status --json
            else
                "$AUDIT" status
            fi
            ;;

        events)
            "$AUDIT" events
            ;;

        count)
            "$AUDIT" count
            ;;

        *)
            echo "Usage:"
            echo "  contextctl audit"
            echo "  contextctl audit status [--json]"
            echo "  contextctl audit events"
            echo "  contextctl audit count"
            exit 1
            ;;

    esac
}

# ============================================================
# History
# ============================================================

history_command() {

    case "${1:-status}" in

        status)
            if [[ "${2:-}" == "--json" ]]; then
                "$HISTORY" status --json
            else
                "$HISTORY" status
            fi
            ;;

        stats)
            "$HISTORY" stats
            ;;

        recent)
            if [[ "${3:-}" == "--json" ]]; then
                "$HISTORY" recent "${2:-10}" --json
            else
                "$HISTORY" recent "${2:-10}"
            fi
            ;;

        *)
            echo "Usage:"
            echo "  contextctl history"
            echo "  contextctl history status [--json]"
            echo "  contextctl history stats"
            echo "  contextctl history recent [limit]"
            echo "  contextctl history recent [limit] --json"
            exit 1
            ;;

    esac
}

# ============================================================
# Help
# ============================================================

show_help() {

    cat <<'HELP'

SevenOS Context Control
════════════════════════

The user interface for the SevenOS Context Engine.

STATUS
──────

  contextctl status
  contextctl status --json

  contextctl state
  contextctl state --json

  contextctl decisions
  contextctl decisions --json

  contextctl policies
  contextctl policies --json

  contextctl actions
  contextctl actions --json


CONTEXT CYCLES
──────────────

  contextctl once
  contextctl once --dry-run
  contextctl once --apply
  contextctl once --json
  contextctl once --apply --json


DAEMON
──────

  contextctl daemon status

  contextctl daemon start
  contextctl daemon start --dry-run
  contextctl daemon start --apply

  contextctl daemon stop


AUDIT
─────

  contextctl audit
  contextctl audit status
  contextctl audit status --json

  contextctl audit events
  contextctl audit count


HISTORY
───────

  contextctl history
  contextctl history status
  contextctl history status --json

  contextctl history stats

  contextctl history recent
  contextctl history recent 20
  contextctl history recent 20 --json


ARCHITECTURE
────────────

  contextctl
      │
      ▼
  contextd
      │
      ├── state
      ├── decision
      ├── policy
      ├── action
      ├── executor
      ├── handlers
      └── audit

HELP
}

# ============================================================
# CLI
# ============================================================

require_components
init_runtime

case "${1:-status}" in

    status)
        show_status "${2:-}"
        ;;

    state)
        show_state "${2:-}"
        ;;

    decisions)
        show_decisions "${2:-}"
        ;;

    policies)
        show_policies "${2:-}"
        ;;

    actions)
        show_actions "${2:-}"
        ;;

    once)
        shift
        run_once "$@"
        ;;

    execute)
        mode="${2:-dry-run}"
        json="${3:-}"

        execute_context "$mode" "$json"
        ;;

    daemon)

        case "${2:-status}" in

            status)
                daemon_status
                ;;

            start)
                daemon_start "${3:-}"
                ;;

            stop)
                daemon_stop
                ;;

            *)
                echo "contextctl: unknown daemon command: ${2:-}" >&2
                show_help
                exit 1
                ;;

        esac
        ;;

    audit)
        audit_command "${@:2}"
        ;;

    history)
        history_command "${@:2}"
        ;;

    help|-h|--help)
        show_help
        ;;

    *)
        echo "contextctl: unknown command: $1" >&2
        echo
        show_help
        exit 1
        ;;

esac
