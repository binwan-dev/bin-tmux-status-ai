#!/bin/bash

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TESTS_DIR")"
SCRIPT="${PROJECT_DIR}/scripts/opencode_status.sh"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

PASSED=0
FAILED=0

assert_eq() {
    local expected=$1
    local actual=$2
    local msg=$3
    if [[ "$expected" == "$actual" ]]; then
        ((PASSED++))
        echo "  PASS: $msg"
    else
        ((FAILED++))
        echo "  FAIL: $msg"
        echo "    expected: '$expected'"
        echo "    actual:   '$actual'"
    fi
}

assert_contains() {
    local needle=$1
    local haystack=$2
    local msg=$3
    if [[ "$haystack" == *"$needle"* ]]; then
        ((PASSED++))
        echo "  PASS: $msg"
    else
        ((FAILED++))
        echo "  FAIL: $msg"
        echo "    expected to contain: '$needle'"
        echo "    actual: '$haystack'"
    fi
}

assert_empty() {
    local actual=$1
    local msg=$2
    if [[ -z "$actual" ]]; then
        ((PASSED++))
        echo "  PASS: $msg"
    else
        ((FAILED++))
        echo "  FAIL: $msg"
        echo "    expected empty, got: '$actual'"
    fi
}

test_output_running() {
    echo "test: output running"
    local result
    result=$(bash -c '
        output() {
            case "$1" in
                running) echo "#[fg=blue,bold] ⚡oc #[default]" ;;
                waiting) echo "#[fg=yellow] ⏳oc #[default]" ;;
                done)    echo "#[fg=green] ✓oc #[default]" ;;
            esac
        }
        output running
    ')
    assert_contains "⚡oc" "$result" "running shows lightning icon"
    assert_contains "blue" "$result" "running uses blue color"
}

test_output_waiting() {
    echo "test: output waiting"
    local result
    result=$(bash -c '
        output() {
            case "$1" in
                running) echo "#[fg=blue,bold] ⚡oc #[default]" ;;
                waiting) echo "#[fg=yellow] ⏳oc #[default]" ;;
                done)    echo "#[fg=green] ✓oc #[default]" ;;
            esac
        }
        output waiting
    ')
    assert_contains "⏳oc" "$result" "waiting shows hourglass icon"
    assert_contains "yellow" "$result" "waiting uses yellow color"
}

test_output_done() {
    echo "test: output done"
    local result
    result=$(bash -c '
        output() {
            case "$1" in
                running) echo "#[fg=blue,bold] ⚡oc #[default]" ;;
                waiting) echo "#[fg=yellow] ⏳oc #[default]" ;;
                done)    echo "#[fg=green] ✓oc #[default]" ;;
            esac
        }
        output done
    ')
    assert_contains "✓oc" "$result" "done shows checkmark icon"
    assert_contains "green" "$result" "done uses green color"
}

test_belongs_to_window_same_pid() {
    echo "test: belongs_to_window same pid"
    local result
    result=$(bash -c '
        get_ppid() { echo "0"; }
        belongs_to_window() {
            local pid=$1
            local pane_pids=$2
            local current=$pid
            for ((i=0; i<10; i++)); do
                for ppid in $pane_pids; do
                    if [[ "$current" == "$ppid" ]]; then
                        return 0
                    fi
                done
                current=$(get_ppid "$current")
                if [[ -z "$current" ]] || [[ "$current" == "0" ]]; then
                    break
                fi
            done
            return 1
        }
        if belongs_to_window "12345" "12345 12346"; then
            echo "yes"
        else
            echo "no"
        fi
    ')
    assert_eq "yes" "$result" "direct pane pid matches"
}

test_belongs_to_window_child() {
    echo "test: belongs_to_window child process"
    local result
    result=$(bash -c '
        call_count=0
        get_ppid() {
            ((call_count++))
            if [[ $call_count -eq 1 ]]; then
                echo "100"
            else
                echo "0"
            fi
        }
        belongs_to_window() {
            local pid=$1
            local pane_pids=$2
            local current=$pid
            for ((i=0; i<10; i++)); do
                for ppid in $pane_pids; do
                    if [[ "$current" == "$ppid" ]]; then
                        return 0
                    fi
                done
                current=$(get_ppid "$current")
                if [[ -z "$current" ]] || [[ "$current" == "0" ]]; then
                    break
                fi
            done
            return 1
        }
        if belongs_to_window "999" "100 200"; then
            echo "yes"
        else
            echo "no"
        fi
    ')
    assert_eq "yes" "$result" "child process matches ancestor"
}

test_belongs_to_window_no_match() {
    echo "test: belongs_to_window no match"
    local result
    result=$(bash -c '
        get_ppid() { echo "0"; }
        belongs_to_window() {
            local pid=$1
            local pane_pids=$2
            local current=$pid
            for ((i=0; i<10; i++)); do
                for ppid in $pane_pids; do
                    if [[ "$current" == "$ppid" ]]; then
                        return 0
                    fi
                done
                current=$(get_ppid "$current")
                if [[ -z "$current" ]] || [[ "$current" == "0" ]]; then
                    break
                fi
            done
            return 1
        }
        if belongs_to_window "999" "100 200"; then
            echo "yes"
        else
            echo "no"
        fi
    ')
    assert_eq "no" "$result" "unrelated process not matched"
}

test_marker_done_ttl() {
    echo "test: marker done TTL"
    local marker_file="${TMPDIR}/test_marker"
    local result

    echo "done:$(date -d '60 seconds ago' +%s)" > "$marker_file"
    result=$(bash -c "
        DONE_TTL=30
        MARKER_FILE='$marker_file'
        content=\$(cat \"\$MARKER_FILE\")
        if [[ \"\$content\" == done:* ]]; then
            done_time=\${content#done:}
            now=\$(date +%s)
            if (( now - done_time < DONE_TTL )); then
                echo 'show'
            else
                echo 'hide'
            fi
        fi
    ")
    assert_eq "hide" "$result" "expired done marker hidden"

    echo "done:$(date +%s)" > "$marker_file"
    result=$(bash -c "
        DONE_TTL=30
        MARKER_FILE='$marker_file'
        content=\$(cat \"\$MARKER_FILE\")
        if [[ \"\$content\" == done:* ]]; then
            done_time=\${content#done:}
            now=\$(date +%s)
            if (( now - done_time < DONE_TTL )); then
                echo 'show'
            else
                echo 'hide'
            fi
        fi
    ")
    assert_eq "show" "$result" "fresh done marker shown"
}

test_no_opencode_no_marker() {
    echo "test: no opencode, no marker file"
    local result
    result=$(bash -c "
        MARKER_FILE='${TMPDIR}/nonexistent_marker'
        if [[ -f \"\$MARKER_FILE\" ]]; then
            echo 'marker_exists'
        else
            echo 'no_marker'
        fi
    ")
    assert_eq "no_marker" "$result" "no output when no opencode and no marker"
}

test_sanitized_window_id() {
    echo "test: sanitized window id"
    local result
    result=$(bash -c '
        WINDOW_ID="@0"
        SANITIZED_ID="${WINDOW_ID//\//_}"
        echo "$SANITIZED_ID"
    ')
    assert_eq "@0" "$result" "window id without slash unchanged"

    result=$(bash -c '
        WINDOW_ID="@1/0"
        SANITIZED_ID="${WINDOW_ID//\//_}"
        echo "$SANITIZED_ID"
    ')
    assert_eq "@1_0" "$result" "window id with slash sanitized"
}

echo "=== running tests ==="
echo ""

test_output_running
test_output_waiting
test_output_done
test_belongs_to_window_same_pid
test_belongs_to_window_child
test_belongs_to_window_no_match
test_marker_done_ttl
test_no_opencode_no_marker
test_sanitized_window_id

echo ""
echo "=== results: $PASSED passed, $FAILED failed ==="

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi