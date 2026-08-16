#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

STATE="$SCRIPT_DIR/state.sh"

# ============================================================
# SevenOS Context → Waybar adapter
#
# This file is an UI adapter.
# It does not make decisions.
# It only exposes the current semantic state.
# ============================================================

state="$("$STATE" status --json)"

activity="$(jq -r '.activity // "general"' <<< "$state")"
power="$(jq -r '.power_state // "unknown"' <<< "$state")"
connectivity="$(jq -r '.connectivity // "unknown"' <<< "$state")"
security="$(jq -r '.security_state // "unknown"' <<< "$state")"
focus="$(jq -r '.focus // "neutral"' <<< "$state")"

# ============================================================
# Labels
# ============================================================

case "$activity" in
    development)
        activity_label="Development"
        activity_icon="󰨞"
        ;;

    web)
        activity_label="Web"
        activity_icon="󰖟"
        ;;

    writing)
        activity_label="Writing"
        activity_icon="󰈙"
        ;;

    productivity)
        activity_label="Productivity"
        activity_icon="󰒓"
        ;;

    presentation)
        activity_label="Presentation"
        activity_icon="󰐪"
        ;;

    creative)
        activity_label="Creative"
        activity_icon="󰏘"
        ;;

    media)
        activity_label="Media"
        activity_icon="󰎆"
        ;;

    *)
        activity_label="General"
        activity_icon="󰋜"
        ;;
esac


case "$focus" in
    focused)
        focus_label="Focused"
        focus_icon="󰌨"
        ;;

    relaxed)
        focus_label="Relaxed"
        focus_icon="󰒲"
        ;;

    creative)
        focus_label="Creative"
        focus_icon="󰏘"
        ;;

    *)
        focus_label="Neutral"
        focus_icon="󰍹"
        ;;
esac


case "$power" in
    high)
        power_label="High"
        power_icon="󰁹"
        ;;

    normal)
        power_label="Normal"
        power_icon="󰂀"
        ;;

    low)
        power_label="Low"
        power_icon="󰁻"
        ;;

    critical)
        power_label="Critical"
        power_icon="󰂃"
        ;;

    *)
        power_label="Unknown"
        power_icon="󰂑"
        ;;
esac


case "$connectivity" in
    online)
        connectivity_label="Online"
        connectivity_icon="󰤨"
        ;;

    secure)
        connectivity_label="Secure"
        connectivity_icon="󰌘"
        ;;

    limited)
        connectivity_label="Limited"
        connectivity_icon="󰤭"
        ;;

    offline)
        connectivity_label="Offline"
        connectivity_icon="󰤮"
        ;;

    *)
        connectivity_label="Unknown"
        connectivity_icon="󰤯"
        ;;
esac


case "$security" in
    exposed)
        security_label="Exposed"
        security_icon="󰒃"
        ;;

    secure)
        security_label="Secure"
        security_icon="󰒙"
        ;;

    *)
        security_label="Unknown"
        security_icon="󰌆"
        ;;
esac


# ============================================================
# Waybar classes
# ============================================================

class="activity-${activity} focus-${focus} power-${power} connectivity-${connectivity} security-${security}"

# ============================================================
# Output
# ============================================================

tooltip="$(
    printf '%s\n' \
        "SevenOS Context" \
        "───────────────" \
        "Activity      : $activity_label" \
        "Focus         : $focus_label" \
        "Power         : $power_label" \
        "Connectivity  : $connectivity_label" \
        "Security      : $security_label"
)"

jq -n \
    --arg text "$activity_icon  $activity_label  ·  $focus_label" \
    --arg tooltip "$tooltip" \
    --arg class "$class" \
    '{
        text: $text,
        tooltip: $tooltip,
        class: $class
    }'