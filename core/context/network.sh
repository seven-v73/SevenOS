#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# SevenOS Network Context
#
# Source of truth for network connectivity.
# Distinguishes:
#   - interface
#   - connection
#   - type
#   - connectivity
#   - VPN
# ============================================================

get_device() {
    nmcli -t -f DEVICE,TYPE,STATE device 2>/dev/null \
        | awk -F: '
            $2 == "wifi" && $3 == "connected" { print $1; exit }
            $2 == "ethernet" && $3 == "connected" { print $1; exit }
        '
}

get_type() {
    local device

    device="$(get_device)"

    if [[ -z "$device" ]]; then
        echo "none"
        return
    fi

    nmcli -t -f DEVICE,TYPE device 2>/dev/null \
        | awk -F: -v dev="$device" '$1 == dev { print $2; exit }'
}

get_connection() {
    local device

    device="$(get_device)"

    if [[ -z "$device" ]]; then
        echo "none"
        return
    fi

    nmcli -t -f DEVICE,CONNECTION device 2>/dev/null \
        | awk -F: -v dev="$device" '$1 == dev { print $2; exit }'
}

get_connectivity() {
    if ! command -v nmcli >/dev/null 2>&1; then
        echo "unknown"
        return
    fi

    nmcli networking connectivity 2>/dev/null || echo "unknown"
}

get_vpn() {
    if ! command -v nmcli >/dev/null 2>&1; then
        echo "unknown"
        return
    fi

    if nmcli connection show --active 2>/dev/null \
        | grep -Ei 'vpn|wireguard|openvpn' >/dev/null; then
        echo "active"
    else
        echo "inactive"
    fi
}

get_state() {
    local connectivity
    connectivity="$(get_connectivity)"

    case "$connectivity" in
        full)
            echo "connected"
            ;;
        limited|portal)
            echo "limited"
            ;;
        none)
            echo "disconnected"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

show_json() {
    local device
    local type
    local connection
    local connectivity
    local vpn
    local state

    device="$(get_device)"
    type="$(get_type)"
    connection="$(get_connection)"
    connectivity="$(get_connectivity)"
    vpn="$(get_vpn)"
    state="$(get_state)"

    jq -n \
        --arg device "$device" \
        --arg type "$type" \
        --arg connection "$connection" \
        --arg connectivity "$connectivity" \
        --arg vpn "$vpn" \
        --arg state "$state" \
        '{
            device: (
                if $device == "" then null else $device end
            ),
            type: $type,
            connection: (
                if $connection == "" then null else $connection end
            ),
            connectivity: $connectivity,
            vpn: $vpn,
            state: $state
        }'
}

case "${1:-status}" in
    "")
        get_state
        ;;

    status)
        get_state
        ;;

    device)
        get_device
        ;;

    type)
        get_type
        ;;

    connection)
        get_connection
        ;;

    connectivity)
        get_connectivity
        ;;

    vpn)
        get_vpn
        ;;

    json)
        show_json
        ;;

    *)
        echo "Usage:"
        echo "  network.sh"
        echo "  network.sh status"
        echo "  network.sh device"
        echo "  network.sh type"
        echo "  network.sh connection"
        echo "  network.sh connectivity"
        echo "  network.sh vpn"
        echo "  network.sh json"
        exit 1
        ;;
esac
