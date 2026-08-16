#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# SevenOS Semantic State
#
# Converts one immutable context snapshot into semantic state.
#
# Architecture:
#
# Providers
#     ↓
# snapshot.sh
#     ↓
# state.sh
#     ↓
# Semantic SevenOS state
#
# IMPORTANT:
# state.sh never queries providers directly when a snapshot
# is supplied.
#
# If no snapshot is supplied, state.sh creates one itself.
# ============================================================

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

# ============================================================
# Snapshot
# ============================================================

# get_snapshot() {
#     if [[ ! -t 0 ]]; then
#         cat
#     else
#         "$SCRIPT_DIR/snapshot.sh" json
#     fi
# }

get_snapshot() {
    if [[ -t 0 ]]; then
        "$SCRIPT_DIR/snapshot.sh" json
        return
    fi

    local input

    input="$(cat)"

    if [[ -n "$input" ]]; then
        printf '%s\n' "$input"
    else
        "$SCRIPT_DIR/snapshot.sh" json
    fi
}

# ============================================================
# Activity
# ============================================================

get_activity_from_snapshot() {
    local snapshot="$1"
    local application

    application="$(jq -r '.application.class // "unknown"' <<< "$snapshot")"

    case "${application,,}" in
        code|code-oss|codium|vscodium)
            echo "development"
            ;;

        firefox|firefox-esr|chromium|google-chrome|brave-browser)
            echo "web"
            ;;

        libreoffice-writer|writer)
            echo "writing"
            ;;

        libreoffice-calc|calc)
            echo "productivity"
            ;;

        libreoffice-impress|impress)
            echo "presentation"
            ;;

        gimp|krita|inkscape)
            echo "creative"
            ;;

        vlc|mpv)
            echo "media"
            ;;

        *)
            echo "general"
            ;;
    esac
}

# ============================================================
# Power
# ============================================================

get_power_state_from_snapshot() {
    local snapshot="$1"
    local power_state

    power_state="$(jq -r '.battery.power_state // "unknown"' <<< "$snapshot")"

    case "$power_state" in
        critical)
            echo "critical"
            ;;

        low)
            echo "low"
            ;;

        normal)
            echo "normal"
            ;;

        high)
            echo "high"
            ;;

        *)
            echo "unknown"
            ;;
    esac
}

# ============================================================
# Connectivity
# ============================================================

get_connectivity_from_snapshot() {
    local snapshot="$1"
    local network
    local vpn

    network="$(jq -r '.network.state // "unknown"' <<< "$snapshot")"
    vpn="$(jq -r '.network.vpn // "unknown"' <<< "$snapshot")"

    case "$network" in
        connected)
            if [[ "$vpn" == "active" ]]; then
                echo "secure"
            else
                echo "online"
            fi
            ;;

        limited)
            echo "limited"
            ;;

        disconnected)
            echo "offline"
            ;;

        *)
            echo "unknown"
            ;;
    esac
}

# ============================================================
# Security
# ============================================================

get_security_state_from_snapshot() {
    local snapshot="$1"

    jq -r '.security.state // "unknown"' <<< "$snapshot"
}

# ============================================================
# Focus
# ============================================================

get_focus_from_activity() {
    local activity="$1"

    case "$activity" in
        development|writing|presentation)
            echo "focused"
            ;;

        creative)
            echo "creative"
            ;;

        media|web)
            echo "relaxed"
            ;;

        *)
            echo "neutral"
            ;;
    esac
}

# ============================================================
# Complete semantic state
# ============================================================

show_state_json() {
    local snapshot
    local activity
    local power
    local connectivity
    local security
    local focus

    snapshot="$(get_snapshot)"

    activity="$(get_activity_from_snapshot "$snapshot")"
    power="$(get_power_state_from_snapshot "$snapshot")"
    connectivity="$(get_connectivity_from_snapshot "$snapshot")"
    security="$(get_security_state_from_snapshot "$snapshot")"
    focus="$(get_focus_from_activity "$activity")"

    jq -n \
        --arg activity "$activity" \
        --arg power "$power" \
        --arg connectivity "$connectivity" \
        --arg security "$security" \
        --arg focus "$focus" \
        '{
            activity: $activity,
            power_state: $power,
            connectivity: $connectivity,
            security_state: $security,
            focus: $focus
        }'
}

# ============================================================
# Human readable
# ============================================================

show_state() {
    local state

    state="$(show_state_json)"

    echo "SevenOS State"
    echo "─────────────"

    printf "%-16s : %s\n" \
        "Activity" \
        "$(jq -r '.activity' <<< "$state")"

    printf "%-16s : %s\n" \
        "Power" \
        "$(jq -r '.power_state' <<< "$state")"

    printf "%-16s : %s\n" \
        "Connectivity" \
        "$(jq -r '.connectivity' <<< "$state")"

    printf "%-16s : %s\n" \
        "Security" \
        "$(jq -r '.security_state' <<< "$state")"

    printf "%-16s : %s\n" \
        "Focus" \
        "$(jq -r '.focus' <<< "$state")"
}

# ============================================================
# CLI
# ============================================================

case "${1:-}" in

    status)
        if [[ "${2:-}" == "--json" ]]; then
            show_state_json
        else
            show_state
        fi
        ;;

    get)
        [[ $# -ge 2 ]] || {
            echo "Missing state key" >&2
            exit 1
        }

        state="$(show_state_json)"

        case "$2" in
            activity)
                jq -r '.activity' <<< "$state"
                ;;

            power|power_state)
                jq -r '.power_state' <<< "$state"
                ;;

            connectivity)
                jq -r '.connectivity' <<< "$state"
                ;;

            security|security_state)
                jq -r '.security_state' <<< "$state"
                ;;

            focus)
                jq -r '.focus' <<< "$state"
                ;;

            *)
                echo "Unknown state key: $2" >&2
                exit 1
                ;;
        esac
        ;;

    *)
        echo "Usage:"
        echo "  state.sh status"
        echo "  state.sh status --json"
        echo "  state.sh get <key>"
        echo "  snapshot.sh | state.sh status --json"
        exit 1
        ;;

esac
