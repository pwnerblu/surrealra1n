#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

. "$PROJECT_ROOT/scripts/core/lib/bootstrap.sh"
. "$PROJECT_ROOT/scripts/core/lib/usage.sh"
. "$PROJECT_ROOT/scripts/core/lib/runtime_context.sh"
. "$PROJECT_ROOT/scripts/core/lib/command_helpers.sh"
. "$PROJECT_ROOT/scripts/core/lib/flows.sh"
. "$PROJECT_ROOT/scripts/core/lib/ramdisk.sh"

cmd_fix_ios8() {
    normalize_command_args "--fix-ios8" "$@"
    local args=("${NORMALIZED_ARGS[@]}")

    if [[ ${#args[@]} -ne 0 ]]; then
        echo "[!] Usage: --fix-ios8"
        exit 1
    fi

    echo "[!] IMPORTANT: Device should be freshly restored to iOS 8.x and not booted yet."
    echo "[*] Auto-preparing SSH ramdisk and required dependencies for dyld fix..."
    ensure_ssh_ramdisk_ready
    echo "[*] SSH ramdisk is ready. Patching dyld cache..."
    ./bin/sshpass -p "alpine" ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs /dev/disk0s1s1 /mnt1 || true"
    ./bin/sshpass -p "alpine" scp -P2222 -o StrictHostKeyChecking=no root@localhost:/mnt1/System/Library/Caches/com.apple.dyld/dyld_shared_cache_arm64 dyld.raw
    ./bin/dsc64patcher dyld.raw dyld.patched -8
    ./bin/sshpass -p "alpine" scp -P2222 -o StrictHostKeyChecking=no dyld.patched root@localhost:/mnt1/System/Library/Caches/com.apple.dyld/dyld_shared_cache_arm64
    rm -f dyld.patched dyld.raw
    ./bin/sshpass -p "alpine" ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/reboot || true"
    echo "dyld fix is complete. You can now boot iOS 8."
    exit 0
}

main() {
    bootstrap_environment
    init_runtime_context
    cmd_fix_ios8 "$@"
}

main "$@"
