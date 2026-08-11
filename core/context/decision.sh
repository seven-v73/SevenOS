#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# SevenOS Context Decision Engine
#
# Converts semantic state into behavioral signals and decisions.
#
# Architecture:
#
# Providers
# ↓
# snapshot.sh
# ↓
# schema.sh
# ↓
# state.sh
# ↓
# signals.sh
# ↓
# decision.sh
# ↓
# policy.sh
# ↓
# actions
#
# IMPORTANT:
#
# decision.sh NEVER performs actions.
#
# It only describes what SevenOS SHOULD consider doing.
#
# Input contract:
#
# state JSON
#
# Example:
#
# state.sh status --json | decision.sh status --json
# ============================================================

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

# ============================================================
# Input
# ============================================================

get_state() {
    if [[ ! -t 0 ]]; then
        cat
    else
        "$SCRIPT_DIR/state.sh" status --json
    fi
}

# ============================================================
# Signals
# ============================================================

get_signals() {
    local state="$1"

    "$SCRIPT_DIR/signals.sh" status <<< "$state"
}

# ============================================================
# Decision generation
# ============================================================

generate_decisions() {
    local state="$1"
    local signals="$2"

    jq -n \
        --argjson state "$state" \
        --argjson signals "$signals" \
        '
        [
            (
                if $signals.security_attention then
                    {
                        id: "security_attention",
                        priority: "high",
                        category: "security",
                        reason: "security_state is exposed",
                        recommendation: "notify_security"
                    }
                else
                    empty
                end
            ),

            (
                if $signals.power_saving then
                    {
                        id: "power_saving",
                        priority: "medium",
                        category: "power",
                        reason: "power state requires conservation",
                        recommendation: "reduce_power_usage"
                    }
                else
                    empty
                end
            ),

            (
                if $signals.offline then
                    {
                        id: "offline",
                        priority: "medium",
                        category: "network",
                        reason: "network is offline",
                        recommendation: "adapt_network_services"
                    }
                else
                    empty
                end
            ),

            (
                if $signals.limited_connectivity then
                    {
                        id: "limited_connectivity",
                        priority: "medium",
                        category: "network",
                        reason: "network connectivity is limited",
                        recommendation: "reduce_network_operations"
                    }
                else
                    empty
                end
            ),

            (
                if $signals.focus_mode then
                    {
                        id: "focus_mode",
                        priority: "low",
                        category: "focus",
                        reason: "user is in a focused activity",
                        recommendation: "minimize_interruptions"
                    }
                else
                    empty
                end
            ),

            (
                if $signals.creative_mode then
                    {
                        id: "creative_mode",
                        priority: "low",
                        category: "activity",
                        reason: "user is performing creative work",
                        recommendation: "prepare_creative_environment"
                    }
                else
                    empty
                end
            ),

            (
                if $signals.relaxed_mode then
                    {
                        id: "relaxed_mode",
                        priority: "low",
                        category: "activity",
                        reason: "user is in a relaxed activity",
                        recommendation: "reduce_attention_demands"
                    }
                else
                    empty
                end
            )
        ]
        '
}

# ============================================================
# Complete decision result
# ============================================================

show_status_json() {
    local state
    local signals
    local decisions

    state="$(get_state)"
    signals="$(get_signals "$state")"
    decisions="$(generate_decisions "$state" "$signals")"

    jq -n \
        --argjson state "$state" \
        --argjson signals "$signals" \
        --argjson decisions "$decisions" \
        '{
            schema: "sevenos.decisions.v1",
            state: $state,
            signals: $signals,
            decisions: $decisions
        }'
}

# ============================================================
# Human readable
# ============================================================

show_status() {
    local result
    local count

    result="$(show_status_json)"
    count="$(jq '.decisions | length' <<< "$result")"

    echo "SevenOS Decisions"
    echo "─────────────────"
    echo
    echo "Decisions : $count"

    if [[ "$count" -eq 0 ]]; then
        echo
        echo "No decisions required."
        return 0
    fi

    echo

    jq -r '
        .decisions[] |
        "[\(.priority)] \(.id) → \(.recommendation)\n  \(.reason)"
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
        echo "Missing decision key" >&2
        exit 1
    }

    result="$(show_status_json)"

    case "$2" in
        all)
            jq '.decisions' <<< "$result"
            ;;

        count)
            jq '.decisions | length' <<< "$result"
            ;;

        *)
            jq --arg id "$2" '
                .decisions[]
                | select(.id == $id)
            ' <<< "$result"
            ;;
    esac
    ;;

*)
    echo "Usage:"
    echo "  decision.sh status"
    echo "  decision.sh status --json"
    echo "  decision.sh get all"
    echo "  decision.sh get count"
    echo "  decision.sh get <decision-id>"
    echo "  state.sh status --json | decision.sh status"
    exit 1
    ;;

esac
