#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

. "$PROJECT_ROOT/scripts/core/lib/bootstrap.sh"
. "$PROJECT_ROOT/scripts/core/lib/usage.sh"
. "$PROJECT_ROOT/scripts/core/lib/runtime_context.sh"
. "$PROJECT_ROOT/scripts/core/lib/command_helpers.sh"
. "$PROJECT_ROOT/scripts/core/lib/flows.sh"

cmd_seprmvr64_restore() {
    normalize_command_args "--seprmvr64-restore" "$@"
    local args=("${NORMALIZED_ARGS[@]}")

    if [[ ${#args[@]} -ne 1 ]]; then
        echo "[!] Usage: --seprmvr64-restore [iOS_VERSION]"
        exit 1
    fi
    IOS_VERSION="${args[0]}"
    echo "[!] IMPORTANT: This feature is only supported on iOS 7.0 - 9.3.5. DO NOT TRY THIS on 10.0 or later"
    echo "[!] Warning: Before you proceed with a seprmvr64 restore, please understand the following issues you will have afterwards:"
    echo "[!] 1. Touch ID will NOT work, at all."
    echo "[!] 2. Passcode will NOT work, at all. Your passcode is technically NULL. Any time you're asked for a passcode, input anything."
    echo "[!] 3. Encrypted Wi-Fi networks will not work. Use an open network instead."
    echo "[!] 4. You will have deep sleep issues, and POTENTIALLY other issues."
    echo "[!] 5. iOS 7.0 - 7.0.6 will likely freeze a lot after tether booting. It is recommended to do iOS 7.1 or later instead."
    echo "[!] 6. iOS 8.x will be stuck at Slide to Upgrade afterwards. It is recommended to do 7.x or 9.x instead"
    read -p "Press enter to continue. Or press CTRL + C to cancel."
    echo "[*] Starting Restore to iOS $IOS_VERSION..."
    savedir="noseprestore/$IDENTIFIER/$IOS_VERSION"
    echo "Fetching shsh blobs for iOS $LATEST_VERSION (to extract im4m later)"
    rm -rf "shsh"
    mkdir -p shsh
    sudo ./bin/tsschecker -d $IDENTIFIER -s -e $ECID -i $LATEST_VERSION --save-path shsh

    # Find the .shsh2 file in the shsh directory
    shshpath=$(require_shsh_blob "shsh")
    if ! enter_pwndfu_mode 1; then
        echo "[!] Aborting restore. Please re-enter DFU and try again."
        exit 1
    fi
    sudo LD_LIBRARY_PATH="lib" ./bin/idevicerestore -e $savedir/custom.ipsw -y
    echo "Restore has completed! If it's successful, you can boot with: ./surrealra1n.sh --seprmvr64-boot $IOS_VERSION"
    if [[ $IOS_VERSION == 8.* ]]; then
        echo "We are not done yet. You need to run this command to fix dyld: ./surrealra1n.sh --fix-ios8"
        echo "Only after fixing dyld can you boot it normally, this is so we don't get stuck at Slide to Upgrade"
    fi
    exit 0
}

main() {
    bootstrap_environment
    init_runtime_context
    cmd_seprmvr64_restore "$@"
}

main "$@"
