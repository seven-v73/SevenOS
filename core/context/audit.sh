#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# SevenOS Context Audit Engine
#
# Records execution decisions and results.
#
# Contract:
#   input  -> sevenos.execution.v1
#   output -> sevenos.audit.v1
#
# IMPORTANT:
#
# audit.sh does not decide.
# audit.sh does not execute.
#
# It only records what happened.
# ============================================================

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

AUDIT_DIR="$SCRIPT_DIR/audit"
AUDIT_FILE="$AUDIT_DIR/events.jsonl"

mkdir -p "$AUDIT_DIR"


# ============================================================
# Input
# ============================================================

get_execution() {
    if [[ ! -t 0 ]]; then
        cat
    else
        "$SCRIPT_DIR/executor.sh" --dry-run --json
    fi
}


# ============================================================
# Validation
# ============================================================

validate_execution() {
    local input="$1"

    jq -e '
        (.schema == "sevenos.execution.v1")
        and (.mode | IN("dry-run", "apply"))
        and (.executions | type == "array")
        and all(
            .executions[];
            (.id | type == "string")
            and (.source | type == "string")
            and (.category | type == "string")
            and (.priority | IN("high", "medium", "low"))
            and (.mode | IN("automatic", "notify", "confirmation", "blocked"))
            and (.risk | IN("low", "medium", "high"))
            and (.executable | type == "boolean")
            and (.execution | type == "string")
            and (
                (.execution_id == null)
                or (.execution_id | type == "string")
            )
        )
    ' <<< "$input" >/dev/null
}


# ============================================================
# Build audit events
# ============================================================

build_events() {
    local input="$1"

    jq -c '
        . as $execution |

        $execution.executions[] |

        {
            schema: "sevenos.audit.event.v1",

            timestamp: (now | todateiso8601),

            execution_id: (
                .execution_id
                // "unknown"
            ),

            execution_mode: $execution.mode,

            action: .id,
            source: .source,
            category: .category,
            priority: .priority,
            mode: .mode,
            risk: .risk,

            executable: .executable,
            execution: .execution,

            result: (
                .result
                // null
            )
        }
    ' <<< "$input"
}


# ============================================================
# Record
# ============================================================

record_events() {
    local input="$1"

    validate_execution "$input" || {
        echo "audit.sh: invalid execution contract" >&2
        return 1
    }

    build_events "$input" >> "$AUDIT_FILE"
}


# ============================================================
# Status
# ============================================================

show_status() {
    local execution

    execution="$(get_execution)"

    validate_execution "$execution" || {
        echo "audit.sh: invalid execution contract" >&2
        exit 1
    }

    echo "SevenOS Audit"
    echo "─────────────"
    echo
    echo "Audit file : $AUDIT_FILE"
    echo

    jq -r '
        .executions[] |

        "[\(.execution)] \(.id)\n" +
        "  execution_id : \(.execution_id // "unknown")\n" +
        "  source       : \(.source)\n" +
        "  category     : \(.category)\n" +
        "  priority     : \(.priority)\n" +
        "  risk         : \(.risk)\n" +
        "  mode         : \(.mode)\n" +
        "  executable   : \(.executable)"
    ' <<< "$execution"
}


# ============================================================
# JSON
# ============================================================

show_status_json() {
    local execution

    execution="$(get_execution)"

    validate_execution "$execution" || {
        echo "audit.sh: invalid execution contract" >&2
        exit 1
    }

    jq -n \
        --arg file "$AUDIT_FILE" \
        --argjson execution "$execution" \
        '{
            schema: "sevenos.audit.v1",

            source: {
                execution_schema: $execution.schema
            },

            audit_file: $file,

            executions: $execution.executions
        }'
}


# ============================================================
# Events
# ============================================================

show_events() {
    if [[ -f "$AUDIT_FILE" ]]; then
        cat "$AUDIT_FILE"
    fi
}


# ============================================================
# Count
# ============================================================

show_count() {
    if [[ -f "$AUDIT_FILE" ]]; then
        wc -l < "$AUDIT_FILE"
    else
        echo "0"
    fi
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


record)
    execution="$(get_execution)"

    record_events "$execution"

    echo "Audit recorded."
    ;;


events)
    show_events
    ;;


count)
    show_count
    ;;


clear)
    : > "$AUDIT_FILE"
    echo "Audit cleared."
    ;;


*)
    echo "Usage:"
    echo "  audit.sh status"
    echo "  audit.sh status --json"
    echo "  audit.sh record"
    echo "  audit.sh events"
    echo "  audit.sh count"
    echo "  audit.sh clear"
    echo
    echo "  executor.sh --dry-run --json | audit.sh record"
    exit 1
    ;;

esac