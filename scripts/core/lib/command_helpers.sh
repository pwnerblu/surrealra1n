#!/usr/bin/env bash

normalize_command_args() {
    local command_name="$1"
    shift
    NORMALIZED_ARGS=("$@")
    if [[ "${NORMALIZED_ARGS[0]:-}" == "$command_name" ]]; then
        NORMALIZED_ARGS=("${NORMALIZED_ARGS[@]:1}")
    fi
}

has_flag() {
    local target="$1"
    shift
    local arg
    for arg in "$@"; do
        if [[ "$arg" == "$target" ]]; then
            return 0
        fi
    done
    return 1
}
