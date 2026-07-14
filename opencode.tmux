#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUS_SCRIPT="${CURRENT_DIR}/scripts/opencode_status.sh"

_status_option="@opencode_status"
_status_default="#(${STATUS_SCRIPT})"

get_tmux_option() {
    local option=$1
    local default_value=$2
    local option_value
    option_value=$(tmux show-option -gqv "$option")
    if [[ -z "$option_value" ]]; then
        echo "$default_value"
    else
        echo "$option_value"
    fi
}

set_tmux_option() {
    local option=$1
    local value=$2
    tmux set-option -g "$option" "$value"
}

main() {
    local status_value
    status_value=$(get_tmux_option "$_status_option" "$_status_default")
    set_tmux_option "$_status_option" "$status_value"

    local current_right
    current_right=$(tmux show-option -gv status-right 2>/dev/null)
    if [[ "$current_right" != *"@{${_status_option}}"* ]]; then
        tmux set-option -g status-right "#{${_status_option}}${current_right}"
    fi
}

main