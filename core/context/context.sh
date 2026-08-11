#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# SevenOS Context Engine
#
# Central orchestration layer.
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
# IMPORTANT:
#
# context.sh captures exactly ONE snapshot per command.
#
# The same snapshot is used for:
# - raw context
# - semantic state
# - behavioral signals
# ============================================================

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

die() {
    echo "context.sh: $*" >&2
    exit 1
}

get_profile() {
    echo "${SEVENOS_PROFILE:-default}"
}

get_performance() {
    echo "${SEVENOS_PERFORMANCE:-balanced}"
}

get_snapshot() {
    "$SCRIPT_DIR/snapshot.sh" json
}

# ============================================================
# Extractors
# ============================================================

get_workspace_from_snapshot() {
    local snapshot="$1"

    jq -r '
        if .workspace.id == null
        then "unknown"
        else .workspace.id
        end
    ' <<< "$snapshot"
}

get_application_from_snapshot() {
    local snapshot="$1"

    jq -r '.application.class // "unknown"' <<< "$snapshot"
}

get_network_from_snapshot() {
    local snapshot="$1"

    jq -r '.network.state // "unknown"' <<< "$snapshot"
}

get_vpn_from_snapshot() {
    local snapshot="$1"

    jq -r '.network.vpn // "unknown"' <<< "$snapshot"
}

get_battery_from_snapshot() {
    local snapshot="$1"

    jq -r '
        if .battery.capacity == null
        then "unknown"
        else .battery.capacity
        end
    ' <<< "$snapshot"
}

get_audio_from_snapshot() {
    local snapshot="$1"

    jq -r '
        if .audio.volume == null
        then "unknown"
        else .audio.volume
        end
    ' <<< "$snapshot"
}

get_security_from_snapshot() {
    local snapshot="$1"

    jq -r '.security.state // "unknown"' <<< "$snapshot"
}

# ============================================================
# Semantic state
# ============================================================

get_state_from_snapshot() {
    local snapshot="$1"

    "$SCRIPT_DIR/state.sh" status --json <<< "$snapshot"
}

# ============================================================
# Behavioral signals
# ============================================================

get_signals_from_state() {
    local state="$1"

    "$SCRIPT_DIR/signals.sh" status <<< "$state"
}

get_signals_from_snapshot() {
    local snapshot="$1"
    local state

    state="$(get_state_from_snapshot "$snapshot")"

    get_signals_from_state "$state"
}

# ============================================================
# Human-readable status
# ============================================================

show_status() {
    local snapshot
    local profile
    local workspace
    local application
    local network
    local vpn
    local battery
    local audio
    local security
    local performance
    local state
    local signals

    snapshot="$(get_snapshot)"

    profile="$(get_profile)"
    workspace="$(get_workspace_from_snapshot "$snapshot")"
    application="$(get_application_from_snapshot "$snapshot")"
    network="$(get_network_from_snapshot "$snapshot")"
    vpn="$(get_vpn_from_snapshot "$snapshot")"
    battery="$(get_battery_from_snapshot "$snapshot")"
    audio="$(get_audio_from_snapshot "$snapshot")"
    security="$(get_security_from_snapshot "$snapshot")"
    performance="$(get_performance)"

    state="$(get_state_from_snapshot "$snapshot")"
    signals="$(get_signals_from_state "$state")"

    echo "SevenOS Context"
    echo "───────────────"

    printf "%-18s : %s\n" "Profile" "$profile"
    printf "%-18s : %s\n" "Workspace" "$workspace"
    printf "%-18s : %s\n" "Application" "$application"
    printf "%-18s : %s\n" "Network" "$network"
    printf "%-18s : %s\n" "VPN" "$vpn"
    printf "%-18s : %s%%\n" "Battery" "$battery"
    printf "%-18s : %s%%\n" "Audio" "$audio"
    printf "%-18s : %s\n" "Security" "$security"
    printf "%-18s : %s\n" "Performance" "$performance"

    echo
    echo "Semantic State"
    echo "──────────────"

    printf "%-18s : %s\n" \
        "Activity" \
        "$(jq -r '.activity' <<< "$state")"

    printf "%-18s : %s\n" \
        "Power state" \
        "$(jq -r '.power_state' <<< "$state")"

    printf "%-18s : %s\n" \
        "Connectivity" \
        "$(jq -r '.connectivity' <<< "$state")"

    printf "%-18s : %s\n" \
        "Security state" \
        "$(jq -r '.security_state' <<< "$state")"

    printf "%-18s : %s\n" \
        "Focus" \
        "$(jq -r '.focus' <<< "$state")"

    echo
    echo "Signals"
    echo "───────"

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
}

# ============================================================
# Machine-readable JSON
# ============================================================

show_status_json() {
    local snapshot
    local profile
    local workspace
    local application
    local network
    local vpn
    local battery
    local audio
    local security
    local performance
    local state
    local signals

    snapshot="$(get_snapshot)"

    profile="$(get_profile)"
    workspace="$(get_workspace_from_snapshot "$snapshot")"
    application="$(get_application_from_snapshot "$snapshot")"
    network="$(get_network_from_snapshot "$snapshot")"
    vpn="$(get_vpn_from_snapshot "$snapshot")"
    battery="$(get_battery_from_snapshot "$snapshot")"
    audio="$(get_audio_from_snapshot "$snapshot")"
    security="$(get_security_from_snapshot "$snapshot")"
    performance="$(get_performance)"

    state="$(get_state_from_snapshot "$snapshot")"
    signals="$(get_signals_from_state "$state")"

    jq -n \
        --arg profile "$profile" \
        --arg workspace "$workspace" \
        --arg application "$application" \
        --arg network "$network" \
        --arg vpn "$vpn" \
        --arg battery "$battery" \
        --arg audio "$audio" \
        --arg security "$security" \
        --arg performance "$performance" \
        --argjson state "$state" \
        --argjson signals "$signals" \
        '{
            schema: "sevenos.context.v1",
            timestamp: (now | todateiso8601),

            profile: $profile,

            workspace: (
                if ($workspace | test("^[0-9]+$"))
                then ($workspace | tonumber)
                else null
                end
            ),

            application: $application,
            network: $network,
            vpn: $vpn,

            battery: (
                if ($battery | test("^[0-9]+$"))
                then ($battery | tonumber)
                else null
                end
            ),

            audio: (
                if ($audio | test("^[0-9]+$"))
                then ($audio | tonumber)
                else null
                end
            ),

            security: $security,
            performance: $performance,

            state: $state,
            signals: $signals
        }'
}

# ============================================================
# CLI
# ============================================================

case "${1:-}" in

    get)
        [[ $# -ge 2 ]] || die "missing context key"

        snapshot="$(get_snapshot)"

        case "$2" in
            profile)
                get_profile
                ;;

            workspace)
                get_workspace_from_snapshot "$snapshot"
                ;;

            application)
                get_application_from_snapshot "$snapshot"
                ;;

            network)
                get_network_from_snapshot "$snapshot"
                ;;

            vpn)
                get_vpn_from_snapshot "$snapshot"
                ;;

            battery)
                get_battery_from_snapshot "$snapshot"
                ;;

            audio)
                get_audio_from_snapshot "$snapshot"
                ;;

            security)
                get_security_from_snapshot "$snapshot"
                ;;

            performance)
                get_performance
                ;;

            state)
                get_state_from_snapshot "$snapshot"
                ;;

            signals)
                get_signals_from_snapshot "$snapshot"
                ;;

            *)
                die "unknown context key: $2"
                ;;
        esac
        ;;

    status)
        if [[ "${2:-}" == "--json" ]]; then
            show_status_json
        else
            show_status
        fi
        ;;

    *)
        echo "Usage:"
        echo "  context.sh status"
        echo "  context.sh status --json"
        echo "  context.sh get <key>"
        exit 1
        ;;

esac
