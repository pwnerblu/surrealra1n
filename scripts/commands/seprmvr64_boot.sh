#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

. "$PROJECT_ROOT/scripts/core/lib/bootstrap.sh"
. "$PROJECT_ROOT/scripts/core/lib/usage.sh"
. "$PROJECT_ROOT/scripts/core/lib/runtime_context.sh"
. "$PROJECT_ROOT/scripts/core/lib/command_helpers.sh"
. "$PROJECT_ROOT/scripts/core/lib/flows.sh"

cmd_seprmvr64_boot() {
    normalize_command_args "--seprmvr64-boot" "$@"
    local args=("${NORMALIZED_ARGS[@]}")

    if [[ ${#args[@]} -ne 1 ]]; then
        echo "[!] Usage: --seprmvr64-boot [iOS_VERSION]"
        exit 1
    fi
    IOS_VERSION="${args[0]}"
    savedir="seprmvr64boot/$IDENTIFIER/$IOS_VERSION"
    shshpath=$(require_shsh_blob "shsh")
    if [[ ! -d "$savedir" ]] || [[ ! -f "$savedir"/iBSS.img4 || ! -f "$savedir"/iBEC.img4 || ! -f "$savedir"/DeviceTree.img4 || ! -f "$savedir"/Kernelcache.img4 ]]; then
        echo "[!] New boot files must be created."
        IPSW_PATH=$($zenity --file-selection --title="Select the iOS $IOS_VERSION IPSW file")
        sleep 2
    else
        if ! enter_pwndfu_mode 1; then
            echo "[!] Device is NOT in PWNDFU mode"
            echo "[!] Aborting boot process. Please re-enter DFU and try again."
            exit 1
        fi
        ./bin/irecovery -f $savedir/iBSS.img4
        ./bin/irecovery -f $savedir/iBEC.img4
        ./bin/irecovery -f $savedir/DeviceTree.img4
        ./bin/irecovery -c devicetree
        ./bin/irecovery -f $savedir/Kernelcache.img4
        ./bin/irecovery -c bootx
        echo "Your device should now boot."
        exit 0
    fi
    if [[ -z "$IPSW_PATH" ]]; then
        echo "[!] No IPSW selected. Aborting."
        exit 1
    fi
    if [[ ! -f "$IPSW_PATH" ]]; then
        echo "[!] IPSW does not exist: $IPSW_PATH"
        exit 1
    fi
    rm -rf "$savedir"
    mkdir -p "$savedir"
    echo ""
    unzip "$IPSW_PATH" -d tmp1
    # Read decryption keys
    KEY_FILE="keys/$IDENTIFIER.txt"
    if [[ ! -f "$KEY_FILE" ]]; then
        echo "[!] Key file $KEY_FILE not found. Aborting."
        exit 1
    fi
    ./bin/img4tool -s "$shshpath" -e -m "$IDENTIFIER-im4m"
    im4m="$IDENTIFIER-im4m"

    # Extract iBSS and iBEC keys
    IBSS_KEY=$(read_key_value "$KEY_FILE" "ibss-$IOS_VERSION")
    IBEC_KEY=$(read_key_value "$KEY_FILE" "ibec-$IOS_VERSION")
    DTRE_KEY=$(read_key_value "$KEY_FILE" "dtre-$IOS_VERSION")
    KRNL_KEY=$(read_key_value "$KEY_FILE" "krnl-$IOS_VERSION")

    if [[ -z "$IBSS_KEY" || -z "$IBEC_KEY" ]]; then
        echo "[!] Missing iBSS or iBEC key for iOS $IOS_VERSION in $KEY_FILE. Aborting."
        exit 1
    fi

    echo "[*] Found keys:"
    echo "    iBSS Key: $IBSS_KEY"
    echo "    iBEC Key: $IBEC_KEY"
    mkdir -p work
    ./bin/img4 -i "tmp1/Firmware/all_flash/$ALLFLASH/$DEVICETREE" -o "work/dtre.raw" -k $DTRE_KEY
    ./bin/img4 -i "work/dtre.raw" -o "$savedir/DeviceTree.img4" -A -T rdtr -M $im4m
    if [[ $IOS_VERSION != 7.* ]]; then
        mv "tmp1/Firmware/dfu/$IBSS10" "tmp1/Firmware/dfu/$IBSS7"
        mv "tmp1/Firmware/dfu/$IBEC10" "tmp1/Firmware/dfu/$IBEC7"
    fi
    ./bin/img4 -i "tmp1/Firmware/dfu/$IBSS7" -o "work/iBSS.dec" -k $IBSS_KEY
    ./bin/img4 -i "tmp1/Firmware/dfu/$IBEC7" -o "work/iBEC.dec" -k $IBEC_KEY
    if [[ $IOS_VERSION == 7.* || $IOS_VERSION == 8.* ]]; then
        ./bin/ipatcher work/iBSS.dec work/iBSS.patched
        ./bin/ipatcher work/iBEC.dec work/iBEC.patched -b "-v rd=disk0s1s1"
    else
        ./bin/kairos work/iBSS.dec work/iBSS.patched
        ./bin/kairos work/iBEC.dec work/iBEC.patched -b "-v rd=disk0s1s1 amfi=0xff cs_enforcement_disable=1 keepsyms=1 debug=0x2014e wdt=-1 PE_i_can_has_debugger=1 amfi_get_out_of_my_way=0x1 amfi_unrestrict_task_for_pid=0x0"
    fi
    ./bin/img4 -i "work/iBSS.patched" -o "$savedir/iBSS.img4" -A -T ibss -M $im4m 
    ./bin/img4 -i "work/iBEC.patched" -o "$savedir/iBEC.img4" -A -T ibec -M $im4m
    ./bin/img4 -i "tmp1/$KERNELCACHE10" -o "work/kcache.raw" -k $KRNL_KEY  
    ./bin/img4 -i "tmp1/$KERNELCACHE10" -o "work/kcache.im4p" -k $KRNL_KEY -D
    if [[ $IOS_VERSION == 7.* ]]; then
        ./bin/Kernel64Patcher2 "work/kcache.raw" "work/kcache.patched" -u 7 -m 7 -e 7 -f 7 -k
    elif [[ $IOS_VERSION == 8.* ]]; then
        ./bin/Kernel64Patcher2 "work/kcache.raw" "work/kcache.patched" -u 8 -t -p -e 8 -f 8 -a -m 8 -g -s -d
    else
        ./bin/Kernel64Patcher2 "work/kcache.raw" "work/kcache.patched" -u 9 -f 9 -k
    fi     
    ./bin/kerneldiff "work/kcache.raw" "work/kcache.patched" "work/kcache.bpatch"
    ./bin/img4 -i "work/kcache.im4p" -o "$savedir/Kernelcache.img4" -T rkrn -P "work/kcache.bpatch" -J -M $im4m || true
    echo "Patching complete!"
    echo "[*] Verifying generated boot files..."

    require_file "$savedir/iBSS.img4"
    require_file "$savedir/iBEC.img4"
    require_file "$savedir/DeviceTree.img4"
    require_file "$savedir/Kernelcache.img4"

    echo "[*] Boot files created successfully." 
    rm -rf "work"
    rm -rf "tmp1"
    if ! enter_pwndfu_mode 1; then
        echo "[!] Device is NOT in PWNDFU mode"
        echo "[!] Aborting restore. Please re-enter DFU and try again."
        exit 1
    fi
    ./bin/irecovery -f $savedir/iBSS.img4
    ./bin/irecovery -f $savedir/iBEC.img4
    ./bin/irecovery -f $savedir/DeviceTree.img4
    ./bin/irecovery -c devicetree
    ./bin/irecovery -f $savedir/Kernelcache.img4
    ./bin/irecovery -c bootx
    echo "Your device should now boot."
    exit 0
}

main() {
    bootstrap_environment
    init_runtime_context
    cmd_seprmvr64_boot "$@"
}

main "$@"
