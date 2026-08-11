#!/usr/bin/env bash

set -Eeuo pipefail

get_battery() {
    local battery

    for battery in /sys/class/power_supply/BAT*; do
        if [[ -r "$battery/capacity" ]]; then
            echo "$battery"
            return 0
        fi
    done

    return 1
}

get_capacity() {
    local battery

    battery="$(get_battery)" || {
        echo "unknown"
        return
    }

    cat "$battery/capacity"
}

get_status() {
    local battery

    battery="$(get_battery)" || {
        echo "unknown"
        return
    }

    if [[ -r "$battery/status" ]]; then
        cat "$battery/status"
    else
        echo "unknown"
    fi
}

get_charging() {
    case "$(get_status)" in
        Charging)
            echo "true"
            ;;
        *)
            echo "false"
            ;;
    esac
}

get_source() {
    case "$(get_status)" in
        Charging|Full)
            echo "ac"
            ;;
        Discharging)
            echo "battery"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

get_power_state() {
    local capacity

    capacity="$(get_capacity)"

    if [[ "$capacity" == "unknown" ]]; then
        echo "unknown"
        return
    fi

    if (( capacity <= 15 )); then
        echo "critical"
    elif (( capacity <= 30 )); then
        echo "low"
    elif (( capacity >= 80 )); then
        echo "high"
    else
        echo "normal"
    fi
}

show_json() {
    local capacity
    local status
    local charging
    local source
    local power_state

    capacity="$(get_capacity)"
    status="$(get_status)"
    charging="$(get_charging)"
    source="$(get_source)"
    power_state="$(get_power_state)"

    jq -n \
        --arg capacity "$capacity" \
        --arg status "$status" \
        --argjson charging "$charging" \
        --arg source "$source" \
        --arg power_state "$power_state" \
        '{
            capacity: (
                if ($capacity | test("^[0-9]+$"))
                then ($capacity | tonumber)
                else null
                end
            ),
            status: $status,
            charging: $charging,
            source: $source,
            power_state: $power_state
        }'
}

case "${1:-}" in
    "")
        get_capacity
        ;;

    capacity)
        get_capacity
        ;;

    status)
        get_power_state
        ;;

    raw-status)
        get_status
        ;;

    charging)
        get_charging
        ;;

    source)
        get_source
        ;;

    json)
        show_json
        ;;

    *)
        echo "Usage:"
        echo "  battery.sh"
        echo "  battery.sh capacity"
        echo "  battery.sh status"
        echo "  battery.sh raw-status"
        echo "  battery.sh charging"
        echo "  battery.sh source"
        echo "  battery.sh json"
        exit 1
        ;;
esac
