#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# SevenOS Application Context
#
# Source of truth for the currently focused Hyprland window.
# Keeps raw window information separate from semantic state.
# ============================================================

get_application_json() {
    if ! command -v hyprctl >/dev/null 2>&1; then
        echo '{}'
        return
    fi

    hyprctl activewindow -j 2>/dev/null || echo '{}'
}

get_class() {
    local data

    data="$(get_application_json)"

    jq -r '.class // "unknown"' <<< "$data"
}

get_title() {
    local data

    data="$(get_application_json)"

    jq -r '.title // ""' <<< "$data"
}

get_address() {
    local data

    data="$(get_application_json)"

    jq -r '.address // ""' <<< "$data"
}

get_pid() {
    local data

    data="$(get_application_json)"

    jq -r '.pid // null' <<< "$data"
}

get_workspace() {
    local data

    data="$(get_application_json)"

    jq -r '.workspace.id // null' <<< "$data"
}

get_initial_class() {
    local data

    data="$(get_application_json)"

    jq -r '.initialClass // ""' <<< "$data"
}

get_initial_title() {
    local data

    data="$(get_application_json)"

    jq -r '.initialTitle // ""' <<< "$data"
}

get_xwayland() {
    local data

    data="$(get_application_json)"

    jq -r '.xwayland // false' <<< "$data"
}

show_json() {
    local data

    data="$(get_application_json)"

    jq '
        {
            class: (.class // "unknown"),
            title: (.title // ""),
            address: (.address // null),
            pid: (.pid // null),
            workspace: (.workspace.id // null),
            initial_class: (.initialClass // ""),
            initial_title: (.initialTitle // ""),
            xwayland: (.xwayland // false)
        }
    ' <<< "$data"
}

case "${1:-}" in
    "")
        get_class
        ;;

    class)
        get_class
        ;;

    title)
        get_title
        ;;

    address)
        get_address
        ;;

    pid)
        get_pid
        ;;

    workspace)
        get_workspace
        ;;

    initial-class)
        get_initial_class
        ;;

    initial-title)
        get_initial_title
        ;;

    xwayland)
        get_xwayland
        ;;

    status)
        get_class
        ;;

    json)
        show_json
        ;;

    *)
        echo "Usage:"
        echo "  application.sh"
        echo "  application.sh class"
        echo "  application.sh title"
        echo "  application.sh address"
        echo "  application.sh pid"
        echo "  application.sh workspace"
        echo "  application.sh initial-class"
        echo "  application.sh initial-title"
        echo "  application.sh xwayland"
        echo "  application.sh status"
        echo "  application.sh json"
        exit 1
        ;;
esac
