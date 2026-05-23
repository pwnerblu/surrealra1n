#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

. "$PROJECT_ROOT/scripts/core/lib/bootstrap.sh"
. "$PROJECT_ROOT/scripts/core/lib/usage.sh"
. "$PROJECT_ROOT/scripts/core/lib/runtime_context.sh"
. "$PROJECT_ROOT/scripts/core/lib/command_helpers.sh"
. "$PROJECT_ROOT/scripts/core/lib/flows.sh"

cmd_downgrade() {
    normalize_command_args "--downgrade" "$@"
    local args=("${NORMALIZED_ARGS[@]}")

    if [[ ${#args[@]} -ne 2 ]]; then
        echo "[!] Usage: --downgrade [IPSW FILE] [SHSH BLOB]"
        exit 1
    fi
    IPSW="${args[0]}"
    SHSHBLOB="${args[1]}"
    read -p "What is the iOS version you are downgrading to: " vers
    if [[ $vers == 10.2* || $vers == 10.1* ]]; then
        echo "[!] Unsupported currently"
        exit 1
    fi
    echo "[*] Restoring to iOS $vers..."
    if ! enter_pwndfu_mode; then
        echo "[!] Device is NOT in PWNDFU mode"
        echo "[!] Aborting restore. Please re-enter DFU and try again."
        exit 1
    fi

    echo "[*] Using SHSH blob: $SHSHBLOB"
    echo "running futurerestore"
    if [[ $vers == 11.3* || $vers == 11.4* || $vers == 12.* || $vers == 13.* || $vers == 14.* || $vers == 15.* || $vers == 16.* ]]; then
       echo "Using latest SEP and baseband!"
       sudo ./futurerestore/futurerestore -t $SHSHBLOB --use-pwndfu $USE_BASEBAND --latest-sep --no-rsep $IPSW
    elif [[ $IDENTIFIER == iPhone6* ]] && [[ $vers == 10.1* || $vers == 10.2* || $vers == 10.3* ]]; then
       echo "iOS 10 SEP needs to be used"
       IPSW_PATH=$($zenity --file-selection --title="Select the iOS 10.3.3 IPSW file (for SEP firmware)")
       mkdir tmp
       mkdir tmp/Firmware
       mkdir tmp/Firmware/all_flash
       unzip -j "$IPSW_PATH" "Firmware/all_flash/$SEP" -d tmp/Firmware/all_flash
       unzip -j "$IPSW_PATH" "Firmware/$BASEBAND10" -d tmp/Firmware
       SEP_PATH="tmp/Firmware/all_flash/$SEP"
       BASEBAND_PATH="tmp/Firmware/$BASEBAND10"
       sudo FUTURERESTORE_I_SOLEMNLY_SWEAR_THAT_I_AM_UP_TO_NO_GOOD=1 ./futurerestore/futurerestore -t $SHSHBLOB --use-pwndfu --no-cache --baseband "$BASEBAND_PATH" --baseband-manifest "$mnifst" --sep "$SEP_PATH" --sep-manifest "$mnifst" --no-rsep $IPSW
    else
       echo "SEP is incompatible!"
       exit 1
    fi
    echo "Restore has finished! Read above if there's any errors"
    echo "Removing tmp folder if it exists"
    sudo rm -rf "tmp"
    exit 1
}

main() {
    bootstrap_environment
    init_runtime_context
    cmd_downgrade "$@"
}

main "$@"
