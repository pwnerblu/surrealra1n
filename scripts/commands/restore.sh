#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

. "$PROJECT_ROOT/scripts/core/lib/bootstrap.sh"
. "$PROJECT_ROOT/scripts/core/lib/usage.sh"
. "$PROJECT_ROOT/scripts/core/lib/runtime_context.sh"
. "$PROJECT_ROOT/scripts/core/lib/command_helpers.sh"
. "$PROJECT_ROOT/scripts/core/lib/flows.sh"

cmd_restore() {
    normalize_command_args "--restore" "$@"
    local args=("${NORMALIZED_ARGS[@]}")

    if [[ ${#args[@]} -ne 1 ]]; then
        echo "[!] Usage: --restore [iOS_VERSION]"
        exit 1
    fi
    sudo rm -rf "shsh"
    IOS_VERSION="${args[0]}"
    echo "[*] Restoring to iOS $IOS_VERSION..."
    restoredir="restorefiles/$IDENTIFIER/$IOS_VERSION"
    echo "Fetching shsh blobs for iOS $LATEST_VERSION, this is just so it will restore. skip-blob flag is used"
    mkdir -p shsh
    sudo ./bin/tsschecker -d $IDENTIFIER -s -e $ECID -i $LATEST_VERSION --save-path shsh

    # Find the .shsh2 file in the shsh directory
    shshpath=$(require_shsh_blob "shsh")

    echo "[*] Using SHSH blob: $shshpath"
    read -p "Do you want to do an update install? (y/n): " update_prompt
    if [[ $IDENTIFIER == iPhone10* || $IDENTIFIER == iPad7* ]] && [[ $IOS_VERSION == 14.* || $IOS_VERSION == 15.* ]] && [[ $update_prompt == N || $update_prompt == n ]]; then
        echo "We must save activation tickets in order to activate on this version. Please read what is below."
        echo "Please read this guide to backup/restore activation tickets: https://gist.github.com/pixdoet/2b58cce317a3bc7158dfe10c53e3dd32"
    fi
    if [[ $IOS_VERSION == 11.0* || $IOS_VERSION == 11.1* || $IOS_VERSION == 11.2* ]] && [[ $update_prompt == N || $update_prompt == n ]]; then
        echo "We must save activation tickets in order to activate on this version. Please read what is below."
        echo "Please read this guide to backup/restore activation tickets: https://gist.github.com/pixdoet/2b58cce317a3bc7158dfe10c53e3dd32"
    fi
    if enter_pwndfu_mode 1; then
        echo "[*] Device is in PWNDFU mode"
        if [[ $IDENTIFIER == iPhone10,3 || $IDENTIFIER == iPhone10,6 ]]; then
            ./bin/irecovery -f surrealra1n.sh
            ./bin/gaster reset
        fi
    else
        echo "[!] Device is NOT in PWNDFU mode"
        echo "[!] Aborting restore. Please re-enter DFU and try again."
        exit 1
    fi
    if [[ $update_prompt == y || $update_prompt == Y ]]; then
        INSTALL_TYPE="--update"
    else
        INSTALL_TYPE=""
    fi
    # Check if IPSW is a make-custom-ipsw-2 ipsw or not.
    if [[ -f "$restoredir/kernel.im4p" && \
          -f "$restoredir/updateramdisk.im4p" && \
          -f "$restoredir/ramdisk.im4p" ]]; then
        echo "This is not a make-custom-ipsw-2 ipsw. Will use futurerestore."
    else
        echo "This is a make-custom-ipsw-2 IPSW. Will do custom restore method"
        sudo rm -rf "shsh"
        echo "Fetching shsh blobs for iOS $LATEST_VERSION, this is just so it will restore. skip-blob flag is used"
        mkdir -p shsh
        APNONCE=$(./bin/irecovery -q | grep "^NONC:" | cut -d ':' -f2 | xargs)
        sudo ./bin/tsschecker -d $IDENTIFIER -s -e $ECID -i $LATEST_VERSION --save-path shsh --apnonce $APNONCE

        # Find the .shsh2 file in the shsh directory
        shshpath2=$(find shsh -type f -name "*.shsh2" | head -n 1)
        if [[ -z "$shshpath2" ]]; then
            echo "[!] No .shsh2 blob found in shsh folder. Aborting."
            exit 1
        fi
        unzip -j "$restoredir/custom.ipsw" "Firmware/dfu/$IBSS" -d tmp
        unzip -j "$restoredir/custom.ipsw" "Firmware/dfu/$IBEC" -d tmp
        ./bin/img4tool -e -s $shshpath2 -m im4m
        ./bin/img4 -i tmp/$IBSS -o tmp/iBSS.img4 -M im4m -T ibss
        ./bin/img4 -i tmp/$IBEC -o tmp/iBEC.img4 -M im4m -T ibec
        ./bin/irecovery -f tmp/iBSS.img4
        ./bin/irecovery -f tmp/iBEC.img4
        echo "Checking if device is in Recovery mode"
        MODE=$(./bin/irecovery -q | grep "^MODE:" | cut -d ':' -f2 | xargs)
        if [[ $MODE == Recovery ]]; then
            echo "Device is in recovery mode"
            sleep 1
        else
            echo "Device not detected in Recovery, aborting"
            rm -rf "tmp"
            exit 1
        fi
        sudo ./futurerestore/futurerestore -t $shshpath2 $USE_BASEBAND --latest-sep --no-rsep $INSTALL_TYPE $restoredir/custom.ipsw
        rm -rf "tmp"
        echo "Restore has finished! Read above if there's any errors"
        exit 1
    fi

    # Potential future iOS 16.x tethered support, send rsep always if restoring iPhone X to fix FDR SEP panic
    if [[ $IOS_VERSION == 16.* || $IDENTIFIER == iPhone10,3 || $IDENTIFIER == iPhone10,6 ]]; then
        use_rsep=""
    else
        use_rsep="--no-rsep"
    fi
    echo "running futurerestore"
    if [[ "$IDENTIFIER" == iPhone6,* || $IDENTIFIER == iPod7* || $IDENTIFIER == iPad4* || $IDENTIFIER == iPhone7* || $IDENTIFIER == iPad5,1 || $IDENTIFIER == iPad5,2 ]] && [[ "$IOS_VERSION" == 10.* || "$IOS_VERSION" == 11.0* || "$IOS_VERSION" == 11.1* || "$IOS_VERSION" == 11.2* ]]; then
        echo "iOS 10 sep will be used"
        if [[ $IDENTIFIER == iPhone6* ]]; then
            sudo ./bin/pzb -g Firmware/all_flash/$SEP http://appldnld.apple.com/ios10.3.3/091-23133-20170719-CA8E78E6-6977-11E7-968B-2B9100BA0AE3/iPhone_4.0_64bit_10.3.3_14G60_Restore.ipsw
        fi
        if [[ $IDENTIFIER == iPad4,4 || $IDENTIFIER == iPad4,5 ]]; then
            sudo ./bin/pzb -g Firmware/all_flash/$SEP http://appldnld.apple.com/ios10.3.3/091-23378-20170719-CA983C78-6977-11E7-8922-3D9100BA0AE3/iPad_64bit_10.3.3_14G60_Restore.ipsw
        fi
        if [[ $IDENTIFIER == iPod7* ]]; then
            # download tvOS SEP
            SEP="sep-firmware.j42d.RELEASE.im4p"
            sudo ./bin/pzb -g Firmware/all_flash/$SEP https://secure-appldnld.apple.com/tvos10.2.2/091-23452-20170720-5D53229C-6A56-11E7-8577-8B2C4A4DD6D5/AppleTV5,3_10.2.2_14W756_Restore.ipsw
            mnifst="manifest/BuildManifest-iPod7,1.plist" # slightly modified BuildManifest from tvOS 10.2.2 to hack signed SEP for 10.3.x restores A8
        fi
        if [[ $IDENTIFIER == iPhone7,2 ]]; then
            SEP="sep-firmware.j42d.RELEASE.im4p"
            sudo ./bin/pzb -g Firmware/all_flash/$SEP https://secure-appldnld.apple.com/tvos10.2.2/091-23452-20170720-5D53229C-6A56-11E7-8577-8B2C4A4DD6D5/AppleTV5,3_10.2.2_14W756_Restore.ipsw
            mnifst="manifest/BuildManifest-iPhone7,2.plist"
            curl -L -o $mnifst https://github.com/pwnerblu/cursed-sep-resources/raw/refs/heads/main/BuildManifest-iPhone7,2.plist
        fi
        if [[ $IDENTIFIER == iPhone7,1 ]]; then
            SEP="sep-firmware.j42d.RELEASE.im4p"
            sudo ./bin/pzb -g Firmware/all_flash/$SEP https://secure-appldnld.apple.com/tvos10.2.2/091-23452-20170720-5D53229C-6A56-11E7-8577-8B2C4A4DD6D5/AppleTV5,3_10.2.2_14W756_Restore.ipsw
            mnifst="manifest/BuildManifest-iPhone7,1.plist"
            curl -L -o $mnifst https://github.com/pwnerblu/cursed-sep-resources/raw/refs/heads/main/BuildManifest-iPhone7,1.plist
        fi
        if [[ $IDENTIFIER == iPad5,1 ]]; then
            SEP="sep-firmware.j42d.RELEASE.im4p"
            sudo ./bin/pzb -g Firmware/all_flash/$SEP https://secure-appldnld.apple.com/tvos10.2.2/091-23452-20170720-5D53229C-6A56-11E7-8577-8B2C4A4DD6D5/AppleTV5,3_10.2.2_14W756_Restore.ipsw
            mnifst="manifest/BuildManifest-iPad5,1.plist"
            curl -L -o $mnifst https://github.com/pwnerblu/cursed-sep-resources/raw/refs/heads/main/BuildManifest-iPad5,1.plist
        fi
        if [[ $IDENTIFIER == iPad5,2 ]]; then
            SEP="sep-firmware.j42d.RELEASE.im4p"
            sudo ./bin/pzb -g Firmware/all_flash/$SEP https://secure-appldnld.apple.com/tvos10.2.2/091-23452-20170720-5D53229C-6A56-11E7-8577-8B2C4A4DD6D5/AppleTV5,3_10.2.2_14W756_Restore.ipsw
            mnifst="manifest/BuildManifest-iPad5,2.plist"
            curl -L -o $mnifst https://github.com/pwnerblu/cursed-sep-resources/raw/refs/heads/main/BuildManifest-iPad5,2.plist
        fi
        mkdir tmp
        mkdir tmp/Firmware
        mkdir tmp/Firmware/all_flash
        mv $SEP tmp/Firmware/all_flash/
        SEP_PATH="tmp/Firmware/all_flash/$SEP"
        if [[ $IOS_VERSION == 11.0* || $IOS_VERSION == 11.1* || $IOS_VERSION == 11.2* ]]; then
            if [[ $update_prompt == y || $update_prompt == Y ]]; then
                sudo FUTURERESTORE_I_SOLEMNLY_SWEAR_THAT_I_AM_UP_TO_NO_GOOD=1 ./futurerestore/futurerestore -t $shshpath --skip-blob --use-pwndfu --no-cache --rdsk $restoredir/updateramdisk.im4p --rkrn $restoredir/kernel.im4p $USE_BASEBAND --sep "$SEP_PATH" --sep-manifest "$mnifst" --no-rsep $restoredir/custom.ipsw
                echo "Restore has finished! Read above if there's any errors"
                echo "YOU WILL FACE A LOT OF ISSUES REGARDING STUFF THAT REQUIRES SEP TO FULLY WORK"
                exit 1
            fi
            sudo FUTURERESTORE_I_SOLEMNLY_SWEAR_THAT_I_AM_UP_TO_NO_GOOD=1 ./futurerestore/futurerestore -t $shshpath --skip-blob --use-pwndfu --rdsk $restoredir/ramdisk.im4p --rkrn $restoredir/kernel.im4p --no-cache $USE_BASEBAND --sep "$SEP_PATH" --sep-manifest "$mnifst" --no-rsep $restoredir/custom.ipsw
            rm -rf "tmp"
            echo "Restore has finished! Read above if there's any errors"
            echo "YOU WILL FACE A LOT OF ISSUES REGARDING STUFF THAT REQUIRES SEP TO FULLY WORK"
            exit 1
        fi
        if [[ $update_prompt == y || $update_prompt == Y ]]; then
            sudo FUTURERESTORE_I_SOLEMNLY_SWEAR_THAT_I_AM_UP_TO_NO_GOOD=1 ./futurerestore/futurerestore -t $shshpath --skip-blob --use-pwndfu --no-cache --rdsk $restoredir/updateramdisk.im4p --rkrn $restoredir/kernel.im4p $USE_BASEBAND --sep "$SEP_PATH" --sep-manifest "$mnifst" --no-rsep $restoredir/custom.ipsw
            echo "Restore has finished! Read above if there's any errors"
            exit 1
        fi
        sudo FUTURERESTORE_I_SOLEMNLY_SWEAR_THAT_I_AM_UP_TO_NO_GOOD=1 ./futurerestore/futurerestore -t $shshpath --skip-blob --use-pwndfu --rdsk $restoredir/ramdisk.im4p --rkrn $restoredir/kernel.im4p --no-cache $USE_BASEBAND --sep "$SEP_PATH" --sep-manifest "$mnifst" --no-rsep $restoredir/custom.ipsw
        rm -rf "tmp"
        echo "Restore has finished! Read above if there's any errors"
        exit 1
    else
        if [[ $update_prompt == y || $update_prompt == Y ]]; then
            sudo ./futurerestore/futurerestore -t $shshpath --skip-blob --use-pwndfu --no-cache --rdsk $restoredir/updateramdisk.im4p --rkrn $restoredir/kernel.im4p $USE_BASEBAND --latest-sep $use_rsep $restoredir/custom.ipsw
            echo "Restore has finished! Read above if there's any errors"
            if [[ $IDENTIFIER == iPad5* || $IDENTIFIER == iPad7* || $IDENTIFIER == iPhone10* ]]; then
                sudo rm -rf "boot/$IDENTIFIER/$IOS_VERSION"
            fi
            exit 1
        fi
        sudo ./futurerestore/futurerestore -t $shshpath --skip-blob --use-pwndfu --no-cache --rdsk $restoredir/ramdisk.im4p --rkrn $restoredir/kernel.im4p $USE_BASEBAND --latest-sep $use_rsep $restoredir/custom.ipsw 
    fi
    echo "Restore has finished! Read above if there's any errors"
    if [[ $IDENTIFIER == iPad5* || $IDENTIFIER == iPad7* || $IDENTIFIER == iPhone10* ]]; then
        sudo rm -rf "boot/$IDENTIFIER/$IOS_VERSION"
    fi
    exit 1
}

main() {
    bootstrap_environment
    init_runtime_context
    cmd_restore "$@"
}

main "$@"
