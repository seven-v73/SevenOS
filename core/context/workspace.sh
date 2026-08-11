#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# SevenOS Workspace Context
#
# Source of truth for Hyprland workspace state.
# ============================================================

get_workspace_json() {
    if ! command -v hyprctl >/dev/null 2>&1; then
        echo '{}'
        return
    fi

    hyprctl activeworkspace -j 2>/dev/null || echo '{}'
}

get_id() {
    local data

    data="$(get_workspace_json)"

    jq -r '.id // 1' <<< "$data"
}

get_name() {
    local data

    data="$(get_workspace_json)"

    jq -r '
        if .name != null and .name != ""
        then .name
        else (.id // 1 | tostring)
        end
    ' <<< "$data"
}

get_windows() {
    local data

    data="$(get_workspace_json)"

    jq -r '.windows // 0' <<< "$data"
}

get_special() {
    local data
    local name

    data="$(get_workspace_json)"

    name="$(jq -r '.name // ""' <<< "$data")"

    if [[ "$name" == special:* ]]; then
        echo "true"
    else
        echo "false"
    fi
}

show_json() {
    local data

    data="$(get_workspace_json)"

    jq '
        {
            id: (.id // 1),
            name: (
                if .name != null and .name != ""
                then .name
                else (.id // 1 | tostring)
                end
            ),
            windows: (.windows // 0),
            special: (
                if (.name // "") | startswith("special:")
                then true
                else false
                end
            ),
            monitor: (.monitor // null)
        }
    ' <<< "$data"
}

case "${1:-}" in
    "")
        get_id
        ;;

    id)
        get_id
        ;;

    name)
        get_name
        ;;

    windows)
        get_windows
        ;;

    special)
        get_special
        ;;

    json)
        show_json
        ;;

    status)
        get_id
        ;;

    *)
        echo "Usage:"
        echo "  workspace.sh"
        echo "  workspace.sh id"
        echo "  workspace.sh name"
        echo "  workspace.sh windows"
        echo "  workspace.sh special"
        echo "  workspace.sh status"
        echo "  workspace.sh json"
        exit 1
        ;;
esac
