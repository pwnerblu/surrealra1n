#!/usr/bin/env bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/runtime/prepare_environment.sh"
. "$SCRIPT_DIR/runtime/detect_device.sh"
. "$SCRIPT_DIR/runtime/apply_profiles.sh"

runtime_error_handler() {
    local exit_code=$?
    local failed_command="$BASH_COMMAND"
    local line_number="${BASH_LINENO[0]}"
    local script_file="${BASH_SOURCE[1]:-$0}"

    {
        echo "[!] surrealra1n has crashed due to an issue"
        echo "[!] Exit code: $exit_code"
        echo "[!] Script: $script_file"
        echo "[!] Line: $line_number"
        echo "[!] Failed command: $failed_command"
        echo
        echo "[!] It is recommended to report this issue here:"
        echo "    https://github.com/pwnerblu/surrealra1n/issues"
        echo "Here's the recommended way to report this:"
        echo "Title should be a brief and clear summary of the issue you are trying to report"
        echo "Issue description should mention all relevant details to such issue if possible, and also a full terminal log attached."
        echo "[!] Issues THAT DO NOT CONTAIN PROPER LOGS, DETAILS, OR ANYTHING RELEVANT, WILL BE CLOSED AS INVALID."
        echo
        echo "[!] To attach this log into your issue, do the following:"
        if [[ ${dist:-0} == 3 || ${dist:-0} == 4 ]]; then
            echo "Cmd + A -> Cmd + C, then paste the entire log into your issue you're opening"
        else
            echo "Ctrl + Shift + A -> Ctrl + Shift + C, then paste the entire log into the issue you're opening"
        fi
    }

    exit "$exit_code"
}

init_runtime_context() {
    clear
    set -euo pipefail
    trap 'runtime_error_handler $LINENO' ERR

    prepare_runtime_environment
    detect_connected_device
    apply_device_profiles
}
