#!/bin/bash

MARKER_DIR="/tmp/tmux_opencode"
WINDOW_ID=$(tmux display-message -p "#{window_id}" 2>/dev/null || echo "unknown")
SANITIZED_ID="${WINDOW_ID//\//_}"
MARKER_FILE="${MARKER_DIR}/${SANITIZED_ID}"
DONE_TTL=30

mkdir -p "$MARKER_DIR"

get_pane_pids() {
    tmux list-panes -t "$WINDOW_ID" -F "#{pane_pid}" 2>/dev/null
}

get_ppid() {
    awk '{print $4}' "/proc/$1/stat" 2>/dev/null
}

belongs_to_window() {
    local pid=$1
    local pane_pids=$2
    local current=$pid
    local max_depth=10

    for ((i = 0; i < max_depth; i++)); do
        for ppid in $pane_pids; do
            if [[ "$current" == "$ppid" ]]; then
                return 0
            fi
        done
        current=$(get_ppid "$current")
        if [[ -z "$current" ]] || [[ "$current" == "0" ]] || [[ "$current" == "1" ]]; then
            break
        fi
    done
    return 1
}

get_window_opencode_pid() {
    local pane_pids
    pane_pids=$(get_pane_pids)
    if [[ -z "$pane_pids" ]]; then
        return 1
    fi

    for pid in $(pgrep -f "opencode" 2>/dev/null); do
        local cmdline
        cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)
        if [[ "$cmdline" != *opencode* ]] || [[ "$cmdline" == *opencode_status* ]]; then
            continue
        fi
        if belongs_to_window "$pid" "$pane_pids"; then
            echo "$pid"
            return 0
        fi
    done
    return 1
}

get_state_letter() {
    awk '{print $3}' "/proc/$1/stat" 2>/dev/null
}

output() {
    case "$1" in
        running) echo "#[fg=blue,bold] ⚡oc #[default]" ;;
        waiting) echo "#[fg=yellow] ⏳oc #[default]" ;;
        done)    echo "#[fg=green] ✓oc #[default]" ;;
    esac
}

main() {
    local pid
    pid=$(get_window_opencode_pid)

    if [[ -n "$pid" ]]; then
        echo "$pid" > "$MARKER_FILE"
        local state
        state=$(get_state_letter "$pid")
        if [[ "$state" == "R" ]]; then
            output "running"
        else
            output "waiting"
        fi
        return
    fi

    if [[ -f "$MARKER_FILE" ]]; then
        local content
        content=$(cat "$MARKER_FILE")
        if [[ "$content" == done:* ]]; then
            local done_time=${content#done:}
            local now
            now=$(date +%s)
            if (( now - done_time < DONE_TTL )); then
                output "done"
            else
                rm -f "$MARKER_FILE"
            fi
        else
            echo "done:$(date +%s)" > "$MARKER_FILE"
            output "done"
        fi
    fi
}

main