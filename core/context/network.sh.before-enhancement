#!/usr/bin/env bash

set -Eeuo pipefail

case "${1:-network}" in

    network)
        if command -v nmcli >/dev/null 2>&1; then
            if nmcli networking connectivity 2>/dev/null | grep -q "full"; then
                echo "connected"
            else
                echo "disconnected"
            fi
        else
            echo "unknown"
        fi
        ;;

    vpn)
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
        ;;

    *)
        echo "Usage: network.sh [network|vpn]" >&2
        exit 1
        ;;

esac
