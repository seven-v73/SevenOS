#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# SevenOS Audio Context
#
# Source of truth for the current default audio sink.
# ============================================================

get_volume_raw() {
    if ! command -v wpctl >/dev/null 2>&1; then
        echo "unknown"
        return
    fi

    wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null \
        | awk '{print $2}' \
        || echo "unknown"
}

get_volume() {
    local raw

    raw="$(get_volume_raw)"

    if [[ "$raw" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        awk -v value="$raw" 'BEGIN {
            printf "%d\n", value * 100
        }'
    else
        echo "unknown"
    fi
}

get_mute() {
    if ! command -v wpctl >/dev/null 2>&1; then
        echo "unknown"
        return
    fi

    if wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null \
        | grep -q '\[MUTED\]'; then
        echo "true"
    else
        echo "false"
    fi
}

get_sink() {
    if ! command -v wpctl >/dev/null 2>&1; then
        echo "unknown"
        return
    fi

    wpctl status 2>/dev/null \
        | awk '
            /Audio/ { audio=1 }
            audio && /Sinks:/ { sinks=1; next }
            sinks && /\*/ {
                sub(/^[^*]*\*/, "", $0)
                sub(/^[[:space:]]+/, "", $0)
                print
                exit
            }
        '
}

get_state() {
    local volume
    local mute

    volume="$(get_volume)"
    mute="$(get_mute)"

    if [[ "$volume" == "unknown" || "$mute" == "unknown" ]]; then
        echo "unknown"
        return
    fi

    if [[ "$mute" == "true" ]]; then
        echo "muted"
    elif (( volume == 0 )); then
        echo "silent"
    elif (( volume >= 80 )); then
        echo "loud"
    else
        echo "normal"
    fi
}

show_json() {
    local volume
    local mute
    local sink
    local state

    volume="$(get_volume)"
    mute="$(get_mute)"
    sink="$(get_sink)"
    state="$(get_state)"

    if [[ "$mute" == "true" ]]; then
        mute_json=true
    elif [[ "$mute" == "false" ]]; then
        mute_json=false
    else
        mute_json=null
    fi

    jq -n \
        --arg volume "$volume" \
        --argjson mute "$mute_json" \
        --arg sink "$sink" \
        --arg state "$state" \
        '{
            volume: (
                if ($volume | test("^[0-9]+$"))
                then ($volume | tonumber)
                else null
                end
            ),
            muted: $mute,
            sink: (
                if $sink == "unknown" or $sink == ""
                then null
                else $sink
                end
            ),
            state: $state
        }'
}

case "${1:-}" in
    "")
        get_volume
        ;;

    volume)
        get_volume
        ;;

    mute)
        get_mute
        ;;

    sink)
        get_sink
        ;;

    state|status)
        get_state
        ;;

    json)
        show_json
        ;;

    *)
        echo "Usage:"
        echo "  audio.sh"
        echo "  audio.sh volume"
        echo "  audio.sh mute"
        echo "  audio.sh sink"
        echo "  audio.sh state"
        echo "  audio.sh json"
        exit 1
        ;;
esac
