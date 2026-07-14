#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUS_SCRIPT="${CURRENT_DIR}/scripts/opencode_status.sh"

main() {
    local current_right
    current_right=$(tmux show-option -gv status-right 2>/dev/null)
    if [[ "$current_right" != *"#(${STATUS_SCRIPT})"* ]]; then
        tmux set-option -g status-right "#(${STATUS_SCRIPT})${current_right}"
    fi
}

main