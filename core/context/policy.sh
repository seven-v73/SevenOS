#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# SevenOS Context Policy Engine
#
# Converts decisions into governed action proposals.
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
# policy.sh NEVER performs actions.
#
# It only determines:
#
# - whether a decision is allowed
# - how it may be handled
# - its risk level
# - which actions may be proposed
#
# Modes:
#
# automatic
# notify
# confirmation
# blocked
#
# ============================================================

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

# ============================================================
# Input
# ============================================================

get_decisions() {
    if [[ ! -t 0 ]]; then
        cat
    else
        "$SCRIPT_DIR/decision.sh" status --json
    fi
}

# ============================================================
# Policy evaluation
# ============================================================

evaluate_policies() {
    local input="$1"

    jq '
        [
            .decisions[] |
            {
                id: .id,
                category: .category,
                priority: .priority,
                reason: .reason,
                recommendation: .recommendation,

                allowed:
                    (
                        .id
                        | IN(
                            "security_attention",
                            "power_saving",
                            "offline",
                            "limited_connectivity",
                            "focus_mode",
                            "creative_mode",
                            "relaxed_mode"
                        )
                    ),

                mode:
                    (
                        if .id == "security_attention" then
                            "notify"

                        elif .id == "power_saving" then
                            "automatic"

                        elif .id == "offline" then
                            "automatic"

                        elif .id == "limited_connectivity" then
                            "automatic"

                        elif .id == "focus_mode" then
                            "automatic"

                        elif .id == "creative_mode" then
                            "automatic"

                        elif .id == "relaxed_mode" then
                            "automatic"

                        else
                            "blocked"
                        end
                    ),

                risk:
                    (
                        if .id == "security_attention" then
                            "low"

                        elif .id == "power_saving" then
                            "low"

                        elif .id == "offline" then
                            "low"

                        elif .id == "limited_connectivity" then
                            "low"

                        elif .id == "focus_mode" then
                            "low"

                        elif .id == "creative_mode" then
                            "low"

                        elif .id == "relaxed_mode" then
                            "low"

                        else
                            "high"
                        end
                    ),

                actions:
                    (
                        if .id == "security_attention" then
                            ["notify_security"]

                        elif .id == "power_saving" then
                            ["reduce_power_usage"]

                        elif .id == "offline" then
                            ["adapt_network_services"]

                        elif .id == "limited_connectivity" then
                            ["reduce_network_operations"]

                        elif .id == "focus_mode" then
                            ["minimize_interruptions"]

                        elif .id == "creative_mode" then
                            ["prepare_creative_environment"]

                        elif .id == "relaxed_mode" then
                            ["reduce_attention_demands"]

                        else
                            []
                        end
                    )
            }
        ]
    ' <<< "$input"
}

# ============================================================
# Complete policy result
# ============================================================

show_status_json() {
    local decisions
    local policies

    decisions="$(get_decisions)"
    policies="$(evaluate_policies "$decisions")"

    jq -n \
        --argjson source "$decisions" \
        --argjson policies "$policies" \
        '{
            schema: "sevenos.policy.v1",

            source: {
                decision_schema: $source.schema
            },

            policies: $policies
        }'
}

# ============================================================
# Human readable
# ============================================================

show_status() {
    local result
    local count

    result="$(show_status_json)"
    count="$(jq '.policies | length' <<< "$result")"

    echo "SevenOS Policies"
    echo "────────────────"
    echo
    echo "Policies : $count"

    if [[ "$count" -eq 0 ]]; then
        echo
        echo "No policies required."
        return 0
    fi

    echo

    jq -r '
        .policies[] |
        "[\(.mode)] \(.id) → \(.actions | join(", "))\n  priority: \(.priority)\n  risk: \(.risk)\n  allowed: \(.allowed)"
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
        echo "Missing policy key" >&2
        exit 1
    }

    result="$(show_status_json)"

    case "$2" in
        all)
            jq '.policies' <<< "$result"
            ;;

        count)
            jq '.policies | length' <<< "$result"
            ;;

        *)
            jq --arg id "$2" '
                .policies[]
                | select(.id == $id)
            ' <<< "$result"
            ;;
    esac
    ;;

*)
    echo "Usage:"
    echo "  policy.sh status"
    echo "  policy.sh status --json"
    echo "  policy.sh get all"
    echo "  policy.sh get count"
    echo "  policy.sh get <policy-id>"
    echo "  decision.sh status --json | policy.sh status"
    exit 1
    ;;

esac
