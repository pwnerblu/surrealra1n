#!/usr/bin/env bash

bootstrap_environment() {
    export CURRENT_VERSION="v1.3.21"
    # Device-specific latest iOS is filled later in apply_device_profiles().
    export LATEST_VERSION="${LATEST_VERSION:-}"
    export DOWNGRADE_RANGE="${DOWNGRADE_RANGE:-}"

    local bootstrap_lib_dir
    bootstrap_lib_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd -- "$bootstrap_lib_dir/../../.." && pwd)"
    SCRIPT_DIR="$PROJECT_ROOT"
    export SCRIPT_DIR PROJECT_ROOT

    # Always execute from project root so all relative paths like ./bin resolve correctly.
    cd "$PROJECT_ROOT"

    # Keep project binaries first in PATH.
    export PATH="$PROJECT_ROOT/bin:$PATH"

    mkdir -p "$PROJECT_ROOT/update" "$PROJECT_ROOT/bin"

    # Migrate accidentally created command-local asset folders into root paths.
    local accidental_bin="$PROJECT_ROOT/scripts/commands/bin"
    local accidental_sshrd="$PROJECT_ROOT/scripts/commands/sshrd/SSHRD_Script"
    local root_sshrd="$PROJECT_ROOT/sshrd/SSHRD_Script"
    local f base

    if [[ -d "$accidental_bin" ]]; then
        for f in "$accidental_bin"/*; do
            [[ -f "$f" ]] || continue
            base="$(basename "$f")"
            if [[ ! -e "$PROJECT_ROOT/bin/$base" ]]; then
                mv "$f" "$PROJECT_ROOT/bin/$base"
            else
                rm -f "$f"
            fi
        done
        rm -rf "$accidental_bin" 2>/dev/null || true
    fi

    if [[ -d "$accidental_sshrd" ]]; then
        if [[ ! -d "$root_sshrd" ]]; then
            mkdir -p "$PROJECT_ROOT/sshrd"
            mv "$accidental_sshrd" "$root_sshrd"
        fi
        chmod -R u+w "$PROJECT_ROOT/scripts/commands/sshrd" 2>/dev/null || true
        rm -rf "$PROJECT_ROOT/scripts/commands/sshrd" 2>/dev/null || true
    fi
}
