#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# SevenOS Context Signals
#
# Converts semantic state into behavioral signals.
#
# Architecture:
#
# Providers
#     ↓
# snapshot.sh
#     ↓
# schema.sh
#     ↓
# state.sh
#     ↓
# signals.sh
#     ↓
# context.sh
#
# Signals describe what SevenOS may want to do.
#
# They DO NOT perform actions.
# ============================================================

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

get_state() {
    if [[ ! -t 0 ]]; then
        cat
    else
        "$SCRIPT_DIR/state.sh" status --json
    fi
}

generate_signals() {
    local state="$1"

    jq '
        {
            power_saving:
                (.power_state == "low"
                 or .power_state == "critical"),

            secure_connection:
                (.connectivity == "secure"),

            focus_mode:
                (.focus == "focused"),

            creative_mode:
                (.focus == "creative"),

            relaxed_mode:
                (.focus == "relaxed"),

            security_attention:
                (.security_state == "exposed"),

            offline:
                (.connectivity == "offline"),

            limited_connectivity:
                (.connectivity == "limited")
        }
    ' <<< "$state"
}

case "${1:-status}" in

    status)
        state="$(get_state)"
        generate_signals "$state"
        ;;

    status-human)
        state="$(get_state)"
        signals="$(generate_signals "$state")"

        echo "SevenOS Signals"
        echo "───────────────"

        printf "%-22s : %s\n" \
            "Power saving" \
            "$(jq -r '.power_saving' <<< "$signals")"

        printf "%-22s : %s\n" \
            "Secure connection" \
            "$(jq -r '.secure_connection' <<< "$signals")"

        printf "%-22s : %s\n" \
            "Focus mode" \
            "$(jq -r '.focus_mode' <<< "$signals")"

        printf "%-22s : %s\n" \
            "Creative mode" \
            "$(jq -r '.creative_mode' <<< "$signals")"

        printf "%-22s : %s\n" \
            "Relaxed mode" \
            "$(jq -r '.relaxed_mode' <<< "$signals")"

        printf "%-22s : %s\n" \
            "Security attention" \
            "$(jq -r '.security_attention' <<< "$signals")"

        printf "%-22s : %s\n" \
            "Offline" \
            "$(jq -r '.offline' <<< "$signals")"

        printf "%-22s : %s\n" \
            "Limited connectivity" \
            "$(jq -r '.limited_connectivity' <<< "$signals")"
        ;;

    *)
        echo "Usage:"
        echo "  signals.sh status"
        echo "  signals.sh status-human"
        echo "  state.sh status --json | signals.sh status"
        exit 1
        ;;

esac
