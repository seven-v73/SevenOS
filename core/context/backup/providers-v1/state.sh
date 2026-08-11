#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# SevenOS Context State
#
# Converts raw system context into semantic SevenOS state.
# ============================================================

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

get_context() {
    local key="$1"

    case "$key" in
        battery)
            "$SCRIPT_DIR/battery.sh"
            ;;
        workspace)
            "$SCRIPT_DIR/workspace.sh"
            ;;
        application)
            "$SCRIPT_DIR/application.sh"
            ;;
        audio)
            "$SCRIPT_DIR/audio.sh"
            ;;
        network)
            "$SCRIPT_DIR/network.sh"
            ;;
        vpn)
            "$SCRIPT_DIR/network.sh" vpn
            ;;
        security)
            "$SCRIPT_DIR/security.sh"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# ------------------------------------------------------------
# Activity
# ------------------------------------------------------------

get_activity() {
    local application
    application="$(get_context application)"

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

# ------------------------------------------------------------
# Power state
# ------------------------------------------------------------

get_power_state() {
    local battery
    battery="$(get_context battery)"

    if [[ "$battery" == "unknown" ]]; then
        echo "unknown"
        return
    fi

    if (( battery <= 15 )); then
        echo "critical"
    elif (( battery <= 30 )); then
        echo "low"
    elif (( battery >= 80 )); then
        echo "high"
    else
        echo "normal"
    fi
}

# ------------------------------------------------------------
# Connectivity state
# ------------------------------------------------------------

get_connectivity_state() {
    local network vpn

    network="$(get_context network)"
    vpn="$(get_context vpn)"

    if [[ "$network" != "connected" ]]; then
        echo "offline"
    elif [[ "$vpn" == "active" ]]; then
        echo "secure"
    else
        echo "online"
    fi
}

# ------------------------------------------------------------
# Security state
# ------------------------------------------------------------

get_security_state() {
    local security vpn

    security="$(get_context security)"
    vpn="$(get_context vpn)"

    if [[ "$security" == "secure" && "$vpn" == "active" ]]; then
        echo "hardened"
    elif [[ "$security" == "secure" ]]; then
        echo "secure"
    else
        echo "attention"
    fi
}

# ------------------------------------------------------------
# Focus state
# ------------------------------------------------------------

get_focus_state() {
    local activity

    activity="$(get_activity)"

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

# ------------------------------------------------------------
# Semantic state
# ------------------------------------------------------------

show_state() {
    local activity
    local power
    local connectivity
    local security
    local focus

    activity="$(get_activity)"
    power="$(get_power_state)"
    connectivity="$(get_connectivity_state)"
    security="$(get_security_state)"
    focus="$(get_focus_state)"

    echo "SevenOS State"
    echo "─────────────"
    printf "%-16s : %s\n" "Activity"      "$activity"
    printf "%-16s : %s\n" "Power"         "$power"
    printf "%-16s : %s\n" "Connectivity"  "$connectivity"
    printf "%-16s : %s\n" "Security"      "$security"
    printf "%-16s : %s\n" "Focus"         "$focus"
}

# ------------------------------------------------------------
# Machine-readable state
# ------------------------------------------------------------

show_state_json() {
    local activity
    local power
    local connectivity
    local security
    local focus

    activity="$(get_activity)"
    power="$(get_power_state)"
    connectivity="$(get_connectivity_state)"
    security="$(get_security_state)"
    focus="$(get_focus_state)"

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

        case "$2" in
            activity)
                get_activity
                ;;
            power|power_state)
                get_power_state
                ;;
            connectivity)
                get_connectivity_state
                ;;
            security|security_state)
                get_security_state
                ;;
            focus)
                get_focus_state
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
        exit 1
        ;;
esac
