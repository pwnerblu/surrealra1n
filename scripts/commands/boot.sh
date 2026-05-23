#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

. "$PROJECT_ROOT/scripts/core/lib/bootstrap.sh"
. "$PROJECT_ROOT/scripts/core/lib/usage.sh"
. "$PROJECT_ROOT/scripts/core/lib/runtime_context.sh"
. "$PROJECT_ROOT/scripts/core/lib/command_helpers.sh"
. "$PROJECT_ROOT/scripts/core/lib/flows.sh"

cmd_boot() {
    normalize_command_args "--boot" "$@"
    local args=("${NORMALIZED_ARGS[@]}")

    if [[ ${#args[@]} -ne 1 ]]; then
        echo "[!] Usage: --boot [iOS_VERSION]"
        exit 1
    fi
    IOS_VERSION="${args[0]}"
    echo "[*] Tethered boot of iOS $IOS_VERSION..."
    echo "[!] Note: Kernel patches are applied for restoring only usually"
    # Find the .shsh2 file in the shsh directory
    shshpath=$(require_shsh_blob "shsh")
       

    # Check for boot files
    BOOT_DIR="boot/$IDENTIFIER/$IOS_VERSION"
    if [[ ! -d "$BOOT_DIR" ]] || [[ ! -f "$BOOT_DIR"/iBSS.img4 || ! -f "$BOOT_DIR"/iBEC.img4 || ! -f "$BOOT_DIR"/DeviceTree.img4 || ! -f "$BOOT_DIR"/Kernelcache.img4 ]]; then
        echo "[*] Boot files not found. Creating new boot files at $BOOT_DIR..."
        if [[ $IDENTIFIER == iPhone10* ]] && [[ $IOS_VERSION == 14.2* || $IOS_VERSION == 14.1* || $IOS_VERSION == 14.0* ]]; then
            IPSW_PATH="restorefiles/$IDENTIFIER/$IOS_VERSION/custom.ipsw"
        else
            echo "Drag and drop the iOS $IOS_VERSION IPSW file."
            IPSW_PATH=$($zenity --file-selection --title="Select the iOS $IOS_VERSION IPSW file")
        fi
        if [[ -z "$IPSW_PATH" ]]; then
            echo "[!] No IPSW selected. Aborting."
            sudo rm -rf "$BOOT_DIR"
            exit 1
        fi
        if [[ ! -f "$IPSW_PATH" ]]; then
            echo "[!] IPSW does not exist: $IPSW_PATH"
            sudo rm -rf "$BOOT_DIR"
            exit 1
        fi
        mkdir -p to_patch
        mkdir -p "$BOOT_DIR"
        # move ibss and ibec
        if [[ "$IOS_VERSION" == 10.2* || "$IOS_VERSION" == 10.1* ]]; then
            unzip -j "$IPSW_PATH" "Firmware/dfu/$IBSS10" -d to_patch
            unzip -j "$IPSW_PATH" "Firmware/dfu/$IBEC10" -d to_patch
            unzip -j "$IPSW_PATH" "$KERNELCACHE10" -d to_patch
            mv to_patch/$KERNELCACHE10 to_patch/$KERNELCACHE
            mv to_patch/$IBSS10 to_patch/$IBSS
            mv to_patch/$IBEC10 to_patch/$IBEC
        else
            unzip -j "$IPSW_PATH" "Firmware/dfu/$IBSS" -d to_patch
            unzip -j "$IPSW_PATH" "Firmware/dfu/$IBEC" -d to_patch
            unzip -j "$IPSW_PATH" "$KERNELCACHE" -d to_patch
        fi
        if [[ "$IOS_VERSION" == 10.1* || "$IOS_VERSION" == 10.2* ]]; then
            unzip -j "$IPSW_PATH" "Firmware/all_flash/$ALLFLASH/$DEVICETREE" -d to_patch
        else
            unzip -j "$IPSW_PATH" "Firmware/all_flash/$DEVICETREE" -d to_patch
        fi
        if [[ "$IOS_VERSION" == 12.* || "$IOS_VERSION" == 13.* || "$IOS_VERSION" == 14.* || "$IOS_VERSION" == 15.* ]]; then
            echo "Trustcache will be extracted too!"
            unzip -j "$IPSW_PATH" "Firmware/*.dmg.trustcache" -d to_patch
            # Select the biggest trustcache file
            BIGGEST_TRUSTCACHE=$(ls -S to_patch/*.trustcache 2>/dev/null | head -n 1)
            if [[ -n "$BIGGEST_TRUSTCACHE" ]]; then
                echo "[*] Using biggest trustcache: $(basename "$BIGGEST_TRUSTCACHE")"
                cp "$BIGGEST_TRUSTCACHE" to_patch/trustcache
            else
                echo "[!] No trustcache file found in IPSW."
            fi
        fi
        mv to_patch/$IBSS to_patch/iBSS.im4p
        mv to_patch/$IBEC to_patch/iBEC.im4p
        mv to_patch/$DEVICETREE to_patch/DeviceTree.im4p
        mv to_patch/$KERNELCACHE to_patch/kernelcache

        # Read decryption keys
        KEY_FILE="keys/$IDENTIFIER.txt"
        if [[ ! -f "$KEY_FILE" ]]; then
            echo "[!] Key file $KEY_FILE not found. Aborting."
            exit 1
        fi

        # Extract iBSS and iBEC keys
        IBSS_KEY=$(read_key_value "$KEY_FILE" "ibss-$IOS_VERSION")
        IBEC_KEY=$(read_key_value "$KEY_FILE" "ibec-$IOS_VERSION")

        if [[ -z "$IBSS_KEY" || -z "$IBEC_KEY" ]]; then
            echo "[!] Missing iBSS or iBEC key for iOS $IOS_VERSION in $KEY_FILE. Aborting."
            exit 1
        fi

        echo "[*] Found keys:"
        echo "    iBSS Key: $IBSS_KEY"
        echo "    iBEC Key: $IBEC_KEY"

        # Placeholder for actual boot file creation
        echo "[*] Creating boot files..."
        ./bin/img4tool -s "$shshpath" -e -m "$IDENTIFIER-im4m"
        im4m="$IDENTIFIER-im4m"
        ./bin/img4 -i to_patch/iBSS.im4p -o to_patch/iBSS.dec -k $IBSS_KEY
        ./bin/img4 -i to_patch/iBEC.im4p -o to_patch/iBEC.dec -k $IBEC_KEY
        if [[ "$IOS_VERSION" == 10.2* || "$IOS_VERSION" == 10.1* ]]; then
            ./bin/kairos to_patch/iBSS.dec to_patch/iBSS.patched
        elif [[ $IDENTIFIER == iPhone10* ]] && [[ $IOS_VERSION == 14.* || $IOS_VERSION == 15.* || $IOS_VERSION == 16.* ]]; then
            ./bin/iBoot64Patcher to_patch/iBSS.dec to_patch/iBSS.patched -b "-v wdt=-1" -l -n
        else
            ./bin/iBoot64Patcher to_patch/iBSS.dec to_patch/iBSS.patched
        fi
        if [[ "$IOS_VERSION" == 10.* || "$IOS_VERSION" == 11.* || "$IOS_VERSION" == 12.* ]]; then
            echo "Using kairos to patch iBEC instead of iBoot64Patcher"
            ./bin/kairos to_patch/iBEC.dec to_patch/iBEC.patched -n -b "-v debug=0x09" -c "go" 0x830000300
        elif [[ "$IOS_VERSION" == 13.* || "$IOS_VERSION" == 14.* || "$IOS_VERSION" == 15.* ]]; then
            ./bin/iBoot64Patcher to_patch/iBEC.dec to_patch/iBEC.patched -b "-v wdt=-1" -n              
        else
            ./bin/iBoot64Patcher to_patch/iBEC.dec to_patch/iBEC.patched -b "rd=disk0s1s1 -v"
        fi
        ./bin/img4 -i to_patch/DeviceTree.im4p -o $BOOT_DIR/DeviceTree.img4 -M "$im4m" -T rdtr
        ./bin/img4 -i to_patch/kernelcache -o $BOOT_DIR/Kernelcache.img4 -M "$im4m" -T rkrn
        if [[ $IOS_VERSION == 14.* ]]; then
            ./bin/img4 -i to_patch/kernelcache -o to_patch/kernel.raw
            ./bin/Kernel64Patcher to_patch/kernel.raw to_patch/kernel.patched -b
            ./bin/img4 -i to_patch/kernel.patched -o $BOOT_DIR/Kernelcache.img4 -M "$im4m" -A -T rkrn -J || true       
        fi
        if [[ $IOS_VERSION == 13.* ]]; then
            ./bin/img4 -i to_patch/kernelcache -o to_patch/kernel.raw
            ./bin/Kernel64Patcher to_patch/kernel.raw to_patch/kernel.patched -b13 -n
            ./bin/img4 -i to_patch/kernel.patched -o $BOOT_DIR/Kernelcache.img4 -M "$im4m" -A -T rkrn -J || true       
        fi
        if [[ $IOS_VERSION == 13.* ]] && [[ $IDENTIFIER == iPad5* ]]; then
            ./bin/img4 -i to_patch/kernelcache -o to_patch/kernel.raw
            ./bin/Kernel64Patcher to_patch/kernel.raw to_patch/kernel.patched -b13 -n
            ./bin/kerneldiff to_patch/kernel.raw to_patch/kernel.patched to_patch/kernel.bpatch
            ./bin/img4 -i to_patch/kernelcache -o $BOOT_DIR/Kernelcache.img4 -M "$im4m" -P to_patch/kernel.bpatch -T rkrn -J || true       
        fi
        if [[ $IOS_VERSION == 12.* ]] && [[ $IDENTIFIER == iPad5* ]]; then
            ./bin/img4 -i to_patch/kernelcache -o to_patch/kernel.raw
            ./bin/Kernel64Patcher2 to_patch/kernel.raw to_patch/kernel.patched -u 12 --skip-sks --skip-acm --skip-amfi
            ./bin/kerneldiff to_patch/kernel.raw to_patch/kernel.patched to_patch/kernel.bpatch
            ./bin/img4 -i to_patch/kernelcache -o $BOOT_DIR/Kernelcache.img4 -M "$im4m" -P to_patch/kernel.bpatch -T rkrn -J || true    
        fi
        if [[ $IOS_VERSION == 11.* || $IOS_VERSION == 10.* ]] && [[ $IDENTIFIER == iPad5* ]]; then
            ./bin/img4 -i to_patch/kernelcache -o to_patch/kernel.raw
            ./bin/Kernel64Patcher2 to_patch/kernel.raw to_patch/kernel.patched -u 11 --skip-sks --skip-acm --skip-amfi
            ./bin/kerneldiff to_patch/kernel.raw to_patch/kernel.patched to_patch/kernel.bpatch
            ./bin/img4 -i to_patch/kernelcache -o $BOOT_DIR/Kernelcache.img4 -M "$im4m" -P to_patch/kernel.bpatch -T rkrn -J || true   
        fi
        if [[ $IDENTIFIER == iPhone7* ]] && [[ $IOS_VERSION == 10.* ]]; then
            ./bin/img4 -i to_patch/kernelcache -o to_patch/kernel.raw
            ./bin/Kernel64Patcher2 to_patch/kernel.raw to_patch/kernel.patched -u 11 --skip-sks --skip-acm --skip-amfi
            ./bin/kerneldiff to_patch/kernel.raw to_patch/kernel.patched to_patch/kernel.bpatch
            ./bin/img4 -i to_patch/kernelcache -o $BOOT_DIR/Kernelcache.img4 -M "$im4m" -P to_patch/kernel.bpatch -T rkrn -J || true   
        fi
        if [[ $IOS_VERSION == 15.* ]]; then
            ./bin/img4 -i to_patch/kernelcache -o to_patch/kernel.raw
            ./bin/Kernel64Patcher to_patch/kernel.raw to_patch/kernel.patched -e -o -r -b15 
            ./bin/img4 -i to_patch/kernel.patched -o $BOOT_DIR/Kernelcache.img4 -M "$im4m" -A -T rkrn -J || true    
        fi
        if [[ $IOS_VERSION == 15.* ]] && [[ $IDENTIFIER == iPad5* ]]; then
            ./bin/img4 -i to_patch/kernelcache -o to_patch/kernel.raw
            ./bin/Kernel64Patcher to_patch/kernel.raw to_patch/kernel.patched -e -o -r -b15
            ./bin/kerneldiff to_patch/kernel.raw to_patch/kernel.patched to_patch/kernel.bpatch
            ./bin/img4 -i to_patch/kernelcache -o $BOOT_DIR/Kernelcache.img4 -M "$im4m" -P to_patch/kernel.bpatch -T rkrn -J || true        
        fi
        if [[ $IOS_VERSION == 14.* ]] && [[ $IDENTIFIER == iPad5* ]]; then
            ./bin/img4 -i to_patch/kernelcache -o to_patch/kernel.raw
            ./bin/Kernel64Patcher to_patch/kernel.raw to_patch/kernel.patched -b
            ./bin/kerneldiff to_patch/kernel.raw to_patch/kernel.patched to_patch/kernel.bpatch
            ./bin/img4 -i to_patch/kernelcache -o $BOOT_DIR/Kernelcache.img4 -M "$im4m" -P to_patch/kernel.bpatch -T rkrn -J || true      
        fi
        ./bin/img4 -i to_patch/iBSS.patched -o $BOOT_DIR/iBSS.img4 -M "$im4m" -A -T ibss
        ./bin/img4 -i to_patch/iBEC.patched -o $BOOT_DIR/iBEC.img4 -M "$im4m" -A -T ibec
        if [[ "$IOS_VERSION" == 12.* || $IOS_VERSION == 13.* || $IOS_VERSION == 14.* || $IOS_VERSION == 15.* ]]; then
            ./bin/img4 -i to_patch/trustcache -o $BOOT_DIR/Trustcache.img4 -M "$im4m" -T rtsc
        fi
        if [[ $IDENTIFIER == iPhone10,3 || $IDENTIFIER == iPhone10,6 ]]; then
            # camera fix
            unzip -j "$IPSW_PATH" "Firmware/isp_bni/adc-nike-d22.im4p" -d to_patch
            ./bin/img4 -i "to_patch/adc-nike-d22.im4p" -o "$BOOT_DIR/isp-firmware.img4" -T ispf -M $im4m
        fi
        if [[ $IDENTIFIER == iPhone10,1 || $IDENTIFIER == iPhone10,4 ]]; then
            # camera fix
            unzip -j "$IPSW_PATH" "Firmware/isp_bni/adc-nike-d20.im4p" -d to_patch
            ./bin/img4 -i "to_patch/adc-nike-d20.im4p" -o "$BOOT_DIR/isp-firmware.img4" -T ispf -M $im4m
        fi
        if [[ $IDENTIFIER == iPhone10,2 || $IDENTIFIER == iPhone10,5 ]]; then
            # camera fix
            unzip -j "$IPSW_PATH" "Firmware/isp_bni/adc-nike-d21.im4p" -d to_patch
            ./bin/img4 -i "to_patch/adc-nike-d21.im4p" -o "$BOOT_DIR/isp-firmware.img4" -T ispf -M $im4m
        fi
        # AVE firmware if on iOS 15.0+
        if [[ $IDENTIFIER == iPhone10* ]] && [[ $IOS_VERSION == 15.* ]]; then
            # camera fix
            unzip -j "$IPSW_PATH" "Firmware/ave/AppleAVE2FW_H10.im4p" -d to_patch
            ./bin/img4 -i "to_patch/AppleAVE2FW_H10.im4p" -o "$BOOT_DIR/ave-firmware.img4" -T avef -M $im4m
        fi         
        if [[ $IDENTIFIER == iPad7* ]] && [[ $IOS_VERSION == 15.* ]]; then
            # camera fix
            unzip -j "$IPSW_PATH" "Firmware/ave/AppleAVE2FW_H9.im4p" -d to_patch
            ./bin/img4 -i "to_patch/AppleAVE2FW_H9.im4p" -o "$BOOT_DIR/ave-firmware.img4" -T avef -M $im4m
        fi  
        echo "[*] Verifying generated boot files..."

        require_file "$BOOT_DIR/iBSS.img4"
        require_file "$BOOT_DIR/iBEC.img4"
        require_file "$BOOT_DIR/DeviceTree.img4"
        require_file "$BOOT_DIR/Kernelcache.img4"

        if [[ "$IOS_VERSION" == 12.* || \
              "$IOS_VERSION" == 13.* || \
              "$IOS_VERSION" == 14.* || \
              "$IOS_VERSION" == 15.* ]]; then
            require_file "$BOOT_DIR/Trustcache.img4"
        fi

        echo "[*] Boot files created successfully."      
        rm -rf "to_patch"
    else
        echo "[*] Existing boot files found in $BOOT_DIR"
    fi

    # Placeholder for tethered boot command
    normal_boot(){
        
    echo "[*] Proceeding to tethered boot..."
    if ! enter_pwndfu_mode; then
        echo "[!] Device is NOT in PWNDFU mode"
        echo "[!] You cannot send the bootchain in regular DFU"
        exit 1
    fi

    }
    palera1n_option=0
    if [[ $IOS_VERSION == 15.* || $IOS_VERSION == 16.* ]] && [[ $dist == 3 || $dist == 4 ]]; then
        read -p "Would you like to boot jailbroken with palera1n? (y/n): " palera1n_option
    fi
    if [[ $palera1n_option == y ]] && [[ $IOS_VERSION == 15.* || $IOS_VERSION == 16.* ]] && [[ $dist == 3 || $dist == 4 ]]; then
        ./bin/openra1n surrealra1n.sh # placeholder stuff
    else
        normal_boot
    fi
    ./bin/irecovery -f "$BOOT_DIR/iBSS.img4"
    if [[ $IDENTIFIER == iPhone10* ]] && [[ $palera1n_option != y ]]; then
        echo "Your device should now boot."
        exit 1
    elif [[ $IDENTIFIER == iPhone10* ]] && [[ $palera1n_option == y ]]; then
        sleep 3
        ./bin/palera1n -l -V
        echo "Your device should now boot."
        exit 1
    fi
    ./bin/irecovery -f "$BOOT_DIR/iBEC.img4"
    if [[ $IDENTIFIER == iPhone9* || $IDENTIFIER == iPhone10* || $IDENTIFIER == iPad7* ]]; then
        ./bin/irecovery -c go
        sleep 6
    fi
    ./bin/irecovery -f "$BOOT_DIR/DeviceTree.img4"
    ./bin/irecovery -c devicetree
    if [[ "$IOS_VERSION" == 12.* || $IOS_VERSION == 13.* || $IOS_VERSION == 14.* || $IOS_VERSION == 15.* ]]; then
      ./bin/irecovery -f "$BOOT_DIR/Trustcache.img4"
      ./bin/irecovery -c firmware
    fi
    if [[ $IDENTIFIER == iPhone10,3 || $IDENTIFIER == iPhone10,6 ]]; then
        ./bin/irecovery -f "$BOOT_DIR/sep-firmware.img4"
        ./bin/irecovery -c rsepfirmware
    fi
    if [[ $IDENTIFIER == iPhone10* ]]; then
        # Fix camera, flashlight
        ./bin/irecovery -f "$BOOT_DIR/isp-firmware.img4"
        ./bin/irecovery -c firmware 
    fi
    if [[ $IOS_VERSION == 15.* ]]; then
        ./bin/irecovery -f "$BOOT_DIR/ave-firmware.img4"
        ./bin/irecovery -c firmware
    fi
    ./bin/irecovery -f "$BOOT_DIR/Kernelcache.img4"
    ./bin/irecovery -c bootx
    echo "Your device should now boot."
    exit 1
}

main() {
    bootstrap_environment
    init_runtime_context
    cmd_boot "$@"
}

main "$@"
