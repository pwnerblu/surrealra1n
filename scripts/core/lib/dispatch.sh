#!/usr/bin/env bash

CORE_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd -- "$CORE_LIB_DIR/../.." && pwd)"
COMMANDS_DIR="$SCRIPTS_DIR/commands"

dispatch_command() {
    local cmd="${1:-}"
    shift || true

    case "$cmd" in
        --seprmvr64-ipsw) exec "$COMMANDS_DIR/seprmvr64_ipsw.sh" "$@" ;;
        --seprmvr64-restore) exec "$COMMANDS_DIR/seprmvr64_restore.sh" "$@" ;;
        --fix-ios8) exec "$COMMANDS_DIR/fix_ios8.sh" "$@" ;;
        --seprmvr64-boot) exec "$COMMANDS_DIR/seprmvr64_boot.sh" "$@" ;;
        --make-custom-ipsw) exec "$COMMANDS_DIR/make_custom_ipsw.sh" "$@" ;;
        --make-custom-ipsw-2) exec "$COMMANDS_DIR/make_custom_ipsw_2.sh" "$@" ;;
        --restore) exec "$COMMANDS_DIR/restore.sh" "$@" ;;
        --downgrade) exec "$COMMANDS_DIR/downgrade.sh" "$@" ;;
        --boot) exec "$COMMANDS_DIR/boot.sh" "$@" ;;
        -h|--help)
            usage
            exit 0
            ;;
        "")
            usage
            exit 1
            ;;
        *)
            echo "[!] Unknown option: $cmd"
            usage
            exit 1
            ;;
    esac
}
