#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# SevenOS Security Context
#
# Source of truth for observable local security state.
#
# Providers:
# - firewall
# - VPN
# - session
# - lock state
#
# Important:
# This provider reports observable state.
# It does not claim that the whole system is "secure".
# ============================================================

get_firewall() {
    if command -v firewall-cmd >/dev/null 2>&1; then
        if firewall-cmd --state 2>/dev/null | grep -q '^running$'; then
            echo "active"
        else
            echo "inactive"
        fi
        return
    fi

    if command -v ufw >/dev/null 2>&1; then
        if ufw status 2>/dev/null | grep -q '^Status: active'; then
            echo "active"
        else
            echo "inactive"
        fi
        return
    fi

    if command -v nft >/dev/null 2>&1; then
        if nft list ruleset 2>/dev/null | grep -q .; then
            echo "configured"
        else
            echo "inactive"
        fi
        return
    fi

    echo "unknown"
}

get_vpn() {
    if command -v nmcli >/dev/null 2>&1; then
        if nmcli connection show --active 2>/dev/null \
            | grep -Ei 'vpn|wireguard|openvpn' >/dev/null; then
            echo "active"
        else
            echo "inactive"
        fi
        return
    fi

    echo "unknown"
}

get_session() {
    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        echo "wayland"
    elif [[ -n "${DISPLAY:-}" ]]; then
        echo "x11"
    else
        echo "unknown"
    fi
}

get_lock() {
    if command -v loginctl >/dev/null 2>&1; then
        local locked

        locked="$(
            loginctl show-session \
                "${XDG_SESSION_ID:-}" \
                -p LockedHint \
                --value 2>/dev/null \
                || true
        )"

        case "$locked" in
            yes)
                echo "locked"
                ;;
            no)
                echo "unlocked"
                ;;
            *)
                echo "unknown"
                ;;
        esac

        return
    fi

    echo "unknown"
}

get_state() {
    local firewall
    local vpn

    firewall="$(get_firewall)"
    vpn="$(get_vpn)"

    if [[ "$firewall" == "active" && "$vpn" == "active" ]]; then
        echo "hardened"
    elif [[ "$firewall" == "active" ]]; then
        echo "protected"
    elif [[ "$vpn" == "active" ]]; then
        echo "private"
    elif [[ "$firewall" == "inactive" ]]; then
        echo "exposed"
    else
        echo "unknown"
    fi
}

show_json() {
    local firewall
    local vpn
    local session
    local lock
    local state

    firewall="$(get_firewall)"
    vpn="$(get_vpn)"
    session="$(get_session)"
    lock="$(get_lock)"
    state="$(get_state)"

    jq -n \
        --arg firewall "$firewall" \
        --arg vpn "$vpn" \
        --arg session "$session" \
        --arg lock "$lock" \
        --arg state "$state" \
        '{
            firewall: $firewall,
            vpn: $vpn,
            session: $session,
            lock: $lock,
            state: $state
        }'
}

case "${1:-}" in
    "")
        get_state
        ;;

    firewall)
        get_firewall
        ;;

    vpn)
        get_vpn
        ;;

    session)
        get_session
        ;;

    lock)
        get_lock
        ;;

    state|status)
        get_state
        ;;

    json)
        show_json
        ;;

    *)
        echo "Usage:"
        echo "  security.sh"
        echo "  security.sh firewall"
        echo "  security.sh vpn"
        echo "  security.sh session"
        echo "  security.sh lock"
        echo "  security.sh state"
        echo "  security.sh json"
        exit 1
        ;;
esac
