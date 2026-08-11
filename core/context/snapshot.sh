#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# SevenOS Context Snapshot
#
# Captures all observable context providers once.
#
# Architecture:
#
# Providers
# ↓
# Snapshot
# ↓
# Semantic State
# ↓
# Context Engine
#
# Snapshot contract:
# sevenos.context.v1
# ============================================================

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

provider() {
    local name="$1"
    local path="$SCRIPT_DIR/$name"

    [[ -x "$path" ]] || {
        echo "snapshot.sh: provider not found: $name" >&2
        exit 1
    }

    printf '%s\n' "$path"
}

get_battery() {
    "$(provider battery.sh)" json
}

get_network() {
    "$(provider network.sh)" json
}

get_audio() {
    "$(provider audio.sh)" json
}

get_workspace() {
    "$(provider workspace.sh)" json
}

get_application() {
    "$(provider application.sh)" json
}

get_security() {
    "$(provider security.sh)" json
}

show_json() {
    local battery
    local network
    local audio
    local workspace
    local application
    local security

    # --------------------------------------------------------
    # Capture each provider exactly once.
    # --------------------------------------------------------

    battery="$(get_battery)"
    network="$(get_network)"
    audio="$(get_audio)"
    workspace="$(get_workspace)"
    application="$(get_application)"
    security="$(get_security)"

    # --------------------------------------------------------
    # Build immutable SevenOS context snapshot.
    # --------------------------------------------------------

    jq -n \
        --argjson battery "$battery" \
        --argjson network "$network" \
        --argjson audio "$audio" \
        --argjson workspace "$workspace" \
        --argjson application "$application" \
        --argjson security "$security" \
        '{
            schema: "sevenos.context.v1",
            timestamp: (now | todateiso8601),

            battery: $battery,
            network: $network,
            audio: $audio,
            workspace: $workspace,
            application: $application,
            security: $security
        }'
}

case "${1:-json}" in
    json)
        show_json
        ;;

    status)
        show_json
        ;;

    *)
        echo "Usage:"
        echo "  snapshot.sh"
        echo "  snapshot.sh json"
        echo "  snapshot.sh status"
        exit 1
        ;;
esac
