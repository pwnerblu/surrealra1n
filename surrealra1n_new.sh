#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

. "$SCRIPT_DIR/scripts/core/lib/bootstrap.sh"
. "$SCRIPT_DIR/scripts/core/lib/usage.sh"
. "$SCRIPT_DIR/scripts/core/lib/auto_update.sh"
. "$SCRIPT_DIR/scripts/core/lib/dispatch.sh"

main() {
    bootstrap_environment
    maybe_auto_update "$@"

    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi

    dispatch_command "$@"
}

main "$@"
