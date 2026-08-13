#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# SevenOS Context Daemon
# ============================================================
#
# Continuous orchestration layer for the SevenOS Context Engine.
#
# Pipeline:
#
#   state
#      ↓
#   decision
#      ↓
#   policy
#      ↓
#   action
#      ↓
#   executor
#      ↓
#   contextd
#      ↓
#   audit
#
# Contract:
#
#   sevenos.contextd.cycle.v1
#
# Design goals:
#
#   - deterministic
#   - idempotent
#   - auditable
#   - safe by default
#   - dry-run capable
#   - daemon capable
#   - persistent state
#   - explicit execution lifecycle
#
# ============================================================


# ============================================================
# Paths
# ============================================================

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

STATE="$SCRIPT_DIR/state.sh"
DECISION="$SCRIPT_DIR/decision.sh"
POLICY="$SCRIPT_DIR/policy.sh"
ACTION="$SCRIPT_DIR/action.sh"
EXECUTOR="$SCRIPT_DIR/executor.sh"
AUDIT="$SCRIPT_DIR/audit.sh"

STATE_DIR="$SCRIPT_DIR/.context"
STATE_FILE="$STATE_DIR/context.json"


# ============================================================
# Runtime configuration
# ============================================================

INTERVAL=5
MODE="dry-run"


# ============================================================
# Runtime identifiers
# ============================================================

generate_execution_id() {
    printf 'exec-%s-%s-%s\n' \
        "$(date -u '+%Y%m%dT%H%M%SZ')" \
        "$$" \
        "$RANDOM"
}


# ============================================================
# Validation
# ============================================================

require_component() {
    local component="$1"

    if [[ ! -x "$component" ]]; then
        echo "contextd.sh: component unavailable: $component" >&2
        exit 1
    fi
}

require_components() {
    require_component "$STATE"
    require_component "$DECISION"
    require_component "$POLICY"
    require_component "$ACTION"
    require_component "$EXECUTOR"
    require_component "$AUDIT"
}


# ============================================================
# Persistent context state
# ============================================================

context_state_init() {

    mkdir -p "$STATE_DIR"

    if [[ ! -f "$STATE_FILE" ]]; then
        cat > "$STATE_FILE" <<'EOF'
{
  "schema": "sevenos.context.state.v1",
  "last_context": null,
  "last_fingerprint": null,
  "last_actions": [],
  "updated_at": null
}
EOF
    fi
}

context_state_load() {
    context_state_init
    cat "$STATE_FILE"
}

context_state_save() {
    local context="$1"
    local fingerprint="$2"
    local actions="$3"

    local tmp

    context_state_init

    tmp="$(mktemp "${STATE_FILE}.XXXXXX")"

    jq \
        --argjson context "$context" \
        --argjson fingerprint "$fingerprint" \
        --argjson actions "$actions" \
        --arg updated_at "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
        '
        .last_context = $context
        | .last_fingerprint = $fingerprint
        | .last_actions = $actions
        | .updated_at = $updated_at
        ' \
        "$STATE_FILE" > "$tmp"

    mv "$tmp" "$STATE_FILE"
}


# ============================================================
# Build context
# ============================================================

build_context() {

    local state
    local decisions
    local policies
    local actions
    local execution

    state="$(
        "$STATE" status --json
    )"

    decisions="$(
        "$DECISION" status --json <<< "$state"
    )"

    policies="$(
        "$POLICY" status --json <<< "$decisions"
    )"

    actions="$(
        "$ACTION" status --json <<< "$policies"
    )"

    if [[ "$MODE" == "apply" ]]; then
        execution="$(
            "$EXECUTOR" --apply --json <<< "$actions"
        )"
    else
        execution="$(
            "$EXECUTOR" --dry-run --json <<< "$actions"
        )"
    fi

    jq -n \
        --arg mode "$MODE" \
        --argjson state "$state" \
        --argjson decisions "$decisions" \
        --argjson policies "$policies" \
        --argjson actions "$actions" \
        --argjson execution "$execution" \
        '{
            schema: "sevenos.contextd.cycle.v1",
            mode: $mode,
            state: $state,
            decisions: $decisions,
            policies: $policies,
            actions: $actions,
            execution: $execution
        }'
}


# ============================================================
# Context fingerprint
# ============================================================

context_fingerprint() {

    jq -cS '
    {
        state: {
            activity: .state.activity,
            power_state: .state.power_state,
            connectivity: .state.connectivity,
            security_state: .state.security_state,
            focus: .state.focus
        },

        signals: .decisions.signals,

        decisions: [
            .decisions.decisions[]
            | {
                id: .id,
                priority: .priority,
                category: .category,
                reason: .reason,
                recommendation: .recommendation
            }
        ],

        policies: [
            .policies.policies[]
            | {
                id: .id,
                category: .category,
                priority: .priority,
                reason: .reason,
                recommendation: .recommendation,
                allowed: .allowed,
                mode: .mode,
                risk: .risk,
                actions: .actions
            }
        ],

        actions: [
            .actions.actions[]
            | {
                id: .id,
                source: .source,
                category: .category,
                priority: .priority,
                mode: .mode,
                risk: .risk,
                status: .status
            }
        ]
    }
    ' <<< "$1"
}


# ============================================================
# Action state helpers
# ============================================================

extract_executed_actions() {

    jq '
    [
        .execution.executions[]
        | select(.execution == "executed")
        | {
            id: .id,
            execution: .execution,
            execution_id: (.execution_id // null)
        }
    ]
    ' <<< "$1"
}


action_was_executed() {

    local action_id="$1"
    local previous_actions="$2"

    jq -e \
        --arg id "$action_id" \
        '
        any(
            .[];
            .id == $id
            and .execution == "executed"
        )
        ' <<< "$previous_actions" \
        >/dev/null
}


# ============================================================
# Audit
# ============================================================

build_audit_execution() {

    local execution="$1"
    local execution_id="$2"

    jq \
        --arg execution_id "$execution_id" \
        '
        .executions |= map(
            .execution_id = (
                .execution_id
                // $execution_id
            )
        )
        ' <<< "$execution"
}

record_audit() {

    local execution="$1"

    "$AUDIT" record <<< "$execution" >/dev/null
}


# ============================================================
# Human-readable output
# ============================================================

print_context_header() {

    local context="$1"

    echo "SevenOS Context Daemon"
    echo "──────────────────────"
    echo
    echo "Mode : $MODE"
    echo "Cycle: once"
    echo

    jq -r '
        "State",
        "─────",
        "activity     : \(.state.activity)",
        "power        : \(.state.power_state)",
        "connectivity : \(.state.connectivity)",
        "security     : \(.state.security_state)",
        "focus        : \(.state.focus)",
        "",
        "Execution",
        "─────────"
    ' <<< "$context"
}


print_execution() {

    local context="$1"

    jq -r '
        (.execution.executions[] |
            if .execution == "executed"
               and .result.status == "success" then

                "SUCCESS: \(.id) → \(.result.message)"

            elif .execution == "dry_run" then

                "DRY-RUN: \(.id)"

            elif .execution == "no_op" then

                "NO-OP: \(.id)"

            else

                "SKIP: \(.id) (\(.execution))"

            end
        )
    ' <<< "$context"
}


# ============================================================
# Single cycle
# ============================================================

# run_once() {

#     local output_json="${1:-}"

#     local context
#     local fingerprint
#     local previous_state

#     local previous_fingerprint="null"
#     local previous_actions="[]"

#     local context_changed="true"

#     local execution_id
#     local executed_actions
#     local audit_execution


#     # --------------------------------------------------------
#     # Build current context
#     # --------------------------------------------------------

#     context="$(build_context)"

#     fingerprint="$(context_fingerprint "$context")"

#     execution_id="$(generate_execution_id)"


#     # --------------------------------------------------------
#     # Load previous daemon state
#     # --------------------------------------------------------

#     previous_state="$(context_state_load)"

#     previous_fingerprint="$(
#         jq -c '
#             .last_fingerprint // null
#         ' <<< "$previous_state"
#     )"

#     previous_actions="$(
#         jq -c '
#             .last_actions // []
#         ' <<< "$previous_state"
#     )"


#     # --------------------------------------------------------
#     # Detect context change
#     # --------------------------------------------------------

#     if [[ "$previous_fingerprint" != "null" ]] &&
#        [[ "$fingerprint" == "$previous_fingerprint" ]]; then

#         context_changed="false"
#     fi


#     # --------------------------------------------------------
#     # JSON mode
#     #
#     # Important:
#     # JSON mode always returns the complete cycle.
#     # It must never be replaced by a NO-OP message.
#     # --------------------------------------------------------

#     if [[ "$output_json" == "--json" ]]; then

#         jq \
#             --arg execution_id "$execution_id" \
#             --argjson changed "$context_changed" \
#             '
#             .execution.executions |= map(
#                 .execution_id = (
#                     .execution_id
#                     // $execution_id
#                 )
#             )
#             | .context_changed = $changed
#             ' <<< "$context"

#         # Persist even JSON cycles.
#         executed_actions="$(extract_executed_actions "$context")"

#         context_state_save \
#             "$context" \
#             "$fingerprint" \
#             "$executed_actions"

#         return 0
#     fi


#     # --------------------------------------------------------
#     # Human output
#     # --------------------------------------------------------

#     print_context_header "$context"


#     # --------------------------------------------------------
#     # Context unchanged
#     #
#     # We do NOT silently discard the execution information.
#     # The daemon still reports what executor decided.
#     # --------------------------------------------------------

#     if [[ "$context_changed" == "false" ]]; then

#         echo "Context : unchanged"
#         echo

#         print_execution "$context"

#         echo
#         echo "NO-OP: context unchanged"

#     else

#         print_execution "$context"

#     fi


#     # --------------------------------------------------------
#     # Extract successfully executed actions
#     # --------------------------------------------------------

#     executed_actions="$(extract_executed_actions "$context")"


#     # --------------------------------------------------------
#     # Save context state
#     # --------------------------------------------------------

#     context_state_save \
#         "$context" \
#         "$fingerprint" \
#         "$executed_actions"


#     # --------------------------------------------------------
#     # Audit apply cycles
#     # --------------------------------------------------------

#     if [[ "$MODE" == "apply" ]]; then

#         audit_execution="$(
#             build_audit_execution \
#                 "$(jq '.execution' <<< "$context")" \
#                 "$execution_id"
#         )"

#         record_audit "$audit_execution"

#     fi
# }

# ============================================================
# Context comparison
# ============================================================

context_changed() {
    local current="$1"
    local previous="$2"

    [[ "$current" != "$previous" ]]
}

run_once() {
    local output_json="${1:-}"

    local context
    local fingerprint
    local previous_state

    local previous_fingerprint="null"
    local previous_actions="[]"

    local changed="true"
    local execution_id
    local execution
    local audit_execution

    # --------------------------------------------------------
    # Persistent state
    # --------------------------------------------------------

    previous_state="$(context_state_load)"

    previous_fingerprint="$(
        jq -c '.last_fingerprint // null' <<< "$previous_state"
    )"

    previous_actions="$(
        jq -c '.last_actions // []' <<< "$previous_state"
    )"

    # --------------------------------------------------------
    # Build current context
    # --------------------------------------------------------

    context="$(build_context)"

    # --------------------------------------------------------
    # Generate execution identity
    # --------------------------------------------------------

    execution_id="$(generate_execution_id)"

    # --------------------------------------------------------
    # Attach execution ID to every execution record
    # --------------------------------------------------------

    execution="$(
        jq \
            --arg execution_id "$execution_id" \
            '
            .execution.executions |= map(
                .execution_id = $execution_id
            )
            ' <<< "$context"
    )"

    # --------------------------------------------------------
    # Extract execution object for audit
    # --------------------------------------------------------

    audit_execution="$(
        jq -c '.execution' <<< "$execution"
    )"

    # --------------------------------------------------------
    # ALWAYS AUDIT THE CYCLE
    #
    # Even if the context is unchanged.
    # A NO-OP is still an observable orchestration decision.
    # --------------------------------------------------------

    record_audit "$audit_execution"

    # --------------------------------------------------------
    # Calculate current fingerprint
    # --------------------------------------------------------

    fingerprint="$(
        context_fingerprint "$execution"
    )"

    # --------------------------------------------------------
    # Compare context
    # --------------------------------------------------------

    if [[ "$previous_fingerprint" == "null" ]]; then
        # First cycle is always considered a context change.
        changed="true"
    elif context_changed "$fingerprint" "$previous_fingerprint"; then
        changed="true"
    else
        changed="false"
    fi

    # --------------------------------------------------------
    # Persist orchestration state
    # --------------------------------------------------------

    local executed_actions

    executed_actions="$(
        jq -c '
            .execution.executions
            | map({
                id: .id,
                execution: .execution,
                executable: .executable
            })
        ' <<< "$execution"
    )"

    context_state_save \
        "$(
            jq -c '.state' <<< "$execution"
        )" \
        "$fingerprint" \
        "$executed_actions"

    # --------------------------------------------------------
    # Add change information to public contract
    # --------------------------------------------------------

    execution="$(
        jq \
            --argjson changed "$changed" \
            '
            .context_changed = $changed
            ' <<< "$execution"
    )"

    # --------------------------------------------------------
    # JSON mode
    # --------------------------------------------------------

    if [[ "$output_json" == "--json" ]]; then
        echo "$execution"
        return 0
    fi

    # --------------------------------------------------------
    # Human-readable output
    # --------------------------------------------------------

    echo "SevenOS Context Daemon"
    echo "──────────────────────"
    echo
    echo "Mode : $MODE"
    echo "Cycle: once"
    echo

    echo "State"
    echo "─────"

    jq -r '
        "activity     : \(.state.activity)",
        "power        : \(.state.power_state)",
        "connectivity : \(.state.connectivity)",
        "security     : \(.state.security_state)",
        "focus        : \(.state.focus)"
    ' <<< "$execution"

    echo
    echo "Execution"
    echo "─────────"

    if [[ "$changed" == "false" ]]; then
        echo "Context : unchanged"
        echo
    else
        echo "Context : changed"
        echo
    fi

    jq -r '
        .execution.executions[] |
        if .execution == "executed" then
            "SUCCESS: \(.id) → \(.result.message // "executed")"
        elif .execution == "dry_run" then
            "DRY-RUN: \(.id)"
        elif .execution == "blocked_by_mode" then
            "SKIP: \(.id) (blocked_by_mode)"
        elif .execution == "blocked_by_risk" then
            "SKIP: \(.id) (blocked_by_risk)"
        else
            "SKIP: \(.id) (\(.execution))"
        end
    ' <<< "$execution"

    if [[ "$changed" == "false" ]]; then
        echo
        echo "NO-OP: context unchanged"
    fi
}


# ============================================================
# Daemon
# ============================================================

run_daemon() {

    local running=true

    cleanup_daemon() {
        running=false
    }

    trap cleanup_daemon INT TERM

    echo "SevenOS Context Daemon"
    echo "──────────────────────"
    echo
    echo "Mode     : $MODE"
    echo "Interval : ${INTERVAL}s"
    echo
    echo "Press Ctrl+C to stop."
    echo

    while [[ "$running" == "true" ]]; do

        run_once

        [[ "$running" == "true" ]] || break

        echo

        # Sleep par petits intervalles afin que SIGTERM/SIGINT
        # soit traité rapidement.
        local elapsed=0

        while [[ "$running" == "true" && "$elapsed" -lt "$INTERVAL" ]]; do
            sleep 1 &
            local sleep_pid=$!

            wait "$sleep_pid" 2>/dev/null || true

            elapsed=$((elapsed + 1))
        done

    done

    trap - INT TERM

    echo
    echo "SevenOS Context Daemon stopped."

    return 0
}


# ============================================================
# CLI
# ============================================================

require_components
context_state_init


case "${1:-once}" in

    once)

        case "${2:-}" in

            --json)
                run_once --json
                ;;

            "")
                run_once
                ;;

            *)
                echo "Unknown option: $2" >&2
                exit 1
                ;;

        esac
        ;;


    daemon)

        case "${2:-}" in

            --apply)
                MODE="apply"
                ;;

            --dry-run)
                MODE="dry-run"
                ;;

            "")
                ;;

            *)
                echo "Unknown option: $2" >&2
                exit 1
                ;;

        esac

        run_daemon
        ;;


    --apply)

        MODE="apply"

        if [[ "${2:-}" == "--json" ]]; then
            run_once --json
        else
            run_once
        fi
        ;;


    --dry-run)

        MODE="dry-run"

        if [[ "${2:-}" == "--json" ]]; then
            run_once --json
        else
            run_once
        fi
        ;;


    *)

        echo "SevenOS Context Daemon"
        echo
        echo "Usage:"
        echo
        echo "  contextd.sh once"
        echo "  contextd.sh once --json"
        echo
        echo "  contextd.sh --dry-run"
        echo "  contextd.sh --dry-run --json"
        echo
        echo "  contextd.sh --apply"
        echo "  contextd.sh --apply --json"
        echo
        echo "  contextd.sh daemon"
        echo "  contextd.sh daemon --dry-run"
        echo "  contextd.sh daemon --apply"
        exit 1
        ;;

esac