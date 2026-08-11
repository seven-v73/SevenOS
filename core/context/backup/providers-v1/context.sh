#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"


# ============================================================
# SevenOS Context Engine
# Single source of truth for system context.
# ============================================================

get_profile() {
    echo "${SEVENOS_PROFILE:-default}"
}

get_workspace() {
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl activeworkspace -j 2>/dev/null \
            | jq -r '.id // 1' 2>/dev/null \
            || echo "1"
    else
        echo "1"
    fi
}

get_application() {
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl activewindow -j 2>/dev/null \
            | jq -r '.class // "unknown"' 2>/dev/null \
            || echo "unknown"
    else
        echo "unknown"
    fi
}

get_network() {
    if command -v nmcli >/dev/null 2>&1; then
        if nmcli networking connectivity 2>/dev/null | grep -q "full"; then
            echo "connected"
        else
            echo "disconnected"
        fi
    else
        echo "unknown"
    fi
}

get_vpn() {
    if command -v nmcli >/dev/null 2>&1; then
        if nmcli connection show --active 2>/dev/null \
            | grep -Ei 'vpn|wireguard|openvpn' >/dev/null; then
            echo "active"
        else
            echo "inactive"
        fi
    else
        echo "unknown"
    fi
}

get_battery() {
    local battery

    for battery in /sys/class/power_supply/BAT*; do
        if [[ -r "$battery/capacity" ]]; then
            cat "$battery/capacity"
            return 0
        fi
    done

    echo "unknown"
}

get_audio() {
    if command -v wpctl >/dev/null 2>&1; then
        wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null \
            | awk '{print int($2 * 100)}' \
            || echo "unknown"
    else
        echo "unknown"
    fi
}

get_security() {
    echo "secure"
}

get_performance() {
    echo "${SEVENOS_PERFORMANCE:-balanced}"
}

# ============================================================
# Generic getter
# ============================================================

get_value() {
    local key="$1"

    case "$key" in
        profile)
            get_profile
            ;;
        workspace)
            get_workspace
            ;;
        application)
            get_application
            ;;
        network)
            get_network
            ;;
        vpn)
            get_vpn
            ;;
        battery)
            get_battery
            ;;
        audio)
            get_audio
            ;;
        security)
            get_security
            ;;
        performance)
            get_performance
            ;;
        *)
            echo "unknown"
            return 1
            ;;
    esac
}

# ============================================================
# Human-readable status
# ============================================================

show_status() {
    echo "SevenOS Context"
    echo "───────────────"
    printf "%-13s : %s\n" "Profile"      "$(get_profile)"
    printf "%-13s : %s\n" "Workspace"    "$(get_workspace)"
    printf "%-13s : %s\n" "Application"  "$(get_application)"
    printf "%-13s : %s\n" "Network"      "$(get_network)"
    printf "%-13s : %s\n" "VPN"          "$(get_vpn)"
    printf "%-13s : %s%%\n" "Battery"     "$(get_battery)"
    printf "%-13s : %s%%\n" "Audio"       "$(get_audio)"
    printf "%-13s : %s\n" "Security"     "$(get_security)"
    printf "%-13s : %s\n" "Performance"  "$(get_performance)"
}

# ============================================================
# Machine-readable JSON status
# ============================================================

show_status_json() {
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

    profile="$(get_profile)"
    workspace="$(get_workspace)"
    application="$(get_application)"
    network="$(get_network)"
    vpn="$(get_vpn)"
    battery="$(get_battery)"
    audio="$(get_audio)"
    security="$(get_security)"
    performance="$(get_performance)"
    state="$("$SCRIPT_DIR/state.sh" status --json)"

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
        '
        {
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
            state: $state
        }
        '
}

case "${1:-}" in

    get)
        [[ $# -ge 2 ]] || {
            echo "Missing key" >&2
            exit 1
        }

        get_value "$2"
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
