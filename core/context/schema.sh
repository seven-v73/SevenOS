#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# SevenOS Context Schema
#
# Strict validation for SevenOS context snapshots.
#
# Contract:
# sevenos.context.v1
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
# context.sh
#
# This layer validates:
# - schema version
# - required objects
# - field types
# - allowed enum values
# - basic numeric ranges
# ============================================================

EXPECTED_SCHEMA="sevenos.context.v1"

validate() {
    local snapshot="$1"

    jq -e \
        --arg schema "$EXPECTED_SCHEMA" \
        '
        # ----------------------------------------------------
        # Root
        # ----------------------------------------------------

        (.schema == $schema)
        and (.timestamp | type == "string")

        # ----------------------------------------------------
        # Battery
        # ----------------------------------------------------

        and (.battery | type == "object")
        and (.battery.capacity | type == "number")
        and (.battery.capacity >= 0 and .battery.capacity <= 100)
        and (.battery.status | type == "string")
        and (.battery.charging | type == "boolean")
        and (.battery.source | type == "string")
        and (.battery.power_state | type == "string")
        and (.battery.power_state |
            IN("critical", "low", "normal", "high", "unknown")
        )

        # ----------------------------------------------------
        # Network
        # ----------------------------------------------------

        and (.network | type == "object")
        and (.network.device | type == "string")
        and (.network.type | type == "string")
        and (.network.connection | type == "string")
        and (.network.connectivity | type == "string")
        and (.network.connectivity |
            IN("full", "limited", "none", "unknown")
        )
        and (.network.vpn | type == "string")
        and (.network.vpn |
            IN("active", "inactive", "unknown")
        )
        and (.network.state | type == "string")
        and (.network.state |
            IN("connected", "limited", "disconnected", "unknown")
        )

        # ----------------------------------------------------
        # Audio
        # ----------------------------------------------------

        and (.audio | type == "object")
        and (.audio.volume | type == "number")
        and (.audio.volume >= 0 and .audio.volume <= 100)
        and (.audio.muted | type == "boolean")
        and (.audio.sink | type == "string")
        and (.audio.state | type == "string")
        and (.audio.state |
            IN("normal", "muted", "unknown")
        )

        # ----------------------------------------------------
        # Workspace
        # ----------------------------------------------------

        and (.workspace | type == "object")
        and (.workspace.id | type == "number")
        and (.workspace.id >= 0)
        and (.workspace.name | type == "string")
        and (.workspace.windows | type == "number")
        and (.workspace.windows >= 0)
        and (.workspace.special | type == "boolean")
        and (.workspace.monitor | type == "string")

        # ----------------------------------------------------
        # Application
        # ----------------------------------------------------

        and (.application | type == "object")
        and (.application.class | type == "string")
        and (.application.title | type == "string")
        and (.application.address | type == "string")
        and (.application.pid | type == "number")
        and (.application.pid >= 0)
        and (.application.workspace | type == "number")
        and (.application.workspace >= 0)
        and (.application.initial_class | type == "string")
        and (.application.initial_title | type == "string")
        and (.application.xwayland | type == "boolean")

        # ----------------------------------------------------
        # Security
        # ----------------------------------------------------

        and (.security | type == "object")
        and (.security.firewall | type == "string")
        and (.security.firewall |
            IN("active", "inactive", "unknown")
        )
        and (.security.vpn | type == "string")
        and (.security.vpn |
            IN("active", "inactive", "unknown")
        )
        and (.security.session | type == "string")
        and (.security.session |
            IN("wayland", "x11", "unknown")
        )
        and (.security.lock | type == "string")
        and (.security.lock |
            IN("locked", "unlocked", "unknown")
        )
        and (.security.state | type == "string")
        and (.security.state |
            IN("hardened", "protected", "private", "exposed", "unknown")
        )
        ' \
        <<< "$snapshot" >/dev/null
}

show_result() {
    local snapshot="$1"

    if validate "$snapshot"; then
        echo "valid"
        return 0
    fi

    echo "invalid"
    return 1
}

case "${1:-validate}" in

    validate)
        snapshot="$(cat)"
        validate "$snapshot"
        ;;

    status)
        snapshot="$(cat)"
        show_result "$snapshot"
        ;;

    *)
        echo "Usage:"
        echo "  snapshot.sh | schema.sh validate"
        echo "  snapshot.sh | schema.sh status"
        exit 1
        ;;

esac
