#!/bin/bash

STATE_FILE="/tmp/waybar_tailscale_state"
CONNECTING_DURATION=2  # seconds to show transition states

get_tailscale_status() {
    local status_json
    if status_json=$(tailscale status --json 2>/dev/null); then
        local backend_state=$(echo "$status_json" | jq -r '.BackendState // "NoState"')
        case "$backend_state" in
            "Running")
                echo "connected"
                ;;
            "Stopped"|"NoState"|"NeedsLogin")
                echo "stopped"
                ;;
            *)
                echo "stopped"
                ;;
        esac
    else
        echo "stopped"
    fi
}

get_tooltip() {
    local status_json
    if ! status_json=$(tailscale status --json 2>/dev/null); then
        echo ""
        return
    fi
    
    local backend_state=$(echo "$status_json" | jq -r '.BackendState // "NoState"')
    if [[ "$backend_state" != "Running" ]]; then
        echo ""
        return
    fi
    
    # Get current hostname
    local hostname=$(echo "$status_json" | jq -r '.Self.HostName // "Unknown"')
    
    # Build tooltip with hostname and peers using Pango markup
    local tooltip="<b>Hostname: <span foreground='#87CEEB'>$hostname</span></b>\n"

    tooltip+="\nPeers:\n"
    
    # Get peers and their status
    local peers=$(echo "$status_json" | jq -r '.Peer // {} | to_entries[] | "\(.value.HostName):\(.value.Online)"' | sort)
    
    if [[ -n "$peers" ]]; then
        while IFS=: read -r peer_name peer_online; do
            if [[ "$peer_online" == "true" ]]; then
                tooltip+="\n<span foreground='#00ff00'>●</span> $peer_name"
            else
                tooltip+="\n<span foreground='#666666'>●</span> <span foreground='#888888'>$peer_name</span>"
            fi
        done <<< "$peers"
    else
        tooltip+="\n<i><span foreground='#888888'>No peers</span></i>"
    fi
    
    echo "$tooltip"
}

show_status() {
    local status=$(get_tailscale_status)
    local text=""
    local alt=""
    local tooltip=""
    
    case $status in
        "connected")
            text=""
            alt="connected"
            tooltip=$(get_tooltip)
            ;;
        "stopped")
            text=""
            alt="stopped"
            tooltip="Tailscale is turned off"
            ;;
    esac
    
    if [[ -n "$tooltip" ]]; then
        echo "{\"text\":\"$text\",\"class\":\"$status\",\"alt\":\"$alt\",\"tooltip\":\"$tooltip\"}"
    else
        echo "{\"text\":\"$text\",\"class\":\"$status\",\"alt\":\"$alt\"}"
    fi
}

show_connecting() {
    echo "{\"text\":\"\",\"class\":\"connecting\",\"alt\":\"connecting\",\"tooltip\":\"Connecting...\"}"
}

show_disconnecting() {
    echo "{\"text\":\"\",\"class\":\"disconnecting\",\"alt\":\"disconnecting\",\"tooltip\":\"Disconnecting...\"}"
}

is_in_transition() {
    if [[ -f "$STATE_FILE" ]]; then
        local state_info=$(cat "$STATE_FILE")
        local state_time=$(echo "$state_info" | cut -d: -f1)
        local current_time=$(date +%s)
        
        if (( current_time - state_time < CONNECTING_DURATION )); then
            return 0  # true - in transition
        else
            rm -f "$STATE_FILE"
            return 1  # false - not in transition
        fi
    fi
    return 1  # false - no state file
}

case "$1" in
    --status)
        # Check if we're in a transition state
        if is_in_transition; then
            state_info=$(cat "$STATE_FILE")
            state_action=$(echo "$state_info" | cut -d: -f2)
            
            if [[ "$state_action" == "connecting" ]]; then
                show_connecting
                exit 0
            elif [[ "$state_action" == "disconnecting" ]]; then
                show_disconnecting
                exit 0
            fi
        fi
        
        show_status
        ;;
    --toggle)
        # Don't allow toggle during transition
        if is_in_transition; then
            # Just show current transition state and exit
            state_info=$(cat "$STATE_FILE")
            state_action=$(echo "$state_info" | cut -d: -f2)
            
            if [[ "$state_action" == "connecting" ]]; then
                show_connecting
            elif [[ "$state_action" == "disconnecting" ]]; then
                show_disconnecting
            fi
            exit 0
        fi
        
        # Determine the action and mark the start of transition state
        current_status=$(get_tailscale_status)
        if [[ "$current_status" == "connected" ]]; then
            # echo "$(date +%s):disconnecting" > "$STATE_FILE"
            # Make disconnects instant
            tailscale down
            show_status
        else
            echo "$(date +%s):connecting" > "$STATE_FILE"
            tailscale up
            show_connecting
        fi
        ;;
    *)
        echo "Usage: $0 {--status|--toggle}"
        exit 1
        ;;
esac