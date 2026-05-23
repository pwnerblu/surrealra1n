#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

. "$PROJECT_ROOT/scripts/core/lib/bootstrap.sh"
. "$PROJECT_ROOT/scripts/core/lib/usage.sh"
. "$PROJECT_ROOT/scripts/core/lib/runtime_context.sh"
. "$PROJECT_ROOT/scripts/core/lib/command_helpers.sh"
. "$PROJECT_ROOT/scripts/core/lib/flows.sh"

cmd_make_custom_ipsw_2() {
    normalize_command_args "--make-custom-ipsw-2" "$@"
    local args=("${NORMALIZED_ARGS[@]}")

    if [[ ${#args[@]} -ne 3 ]]; then
        echo "[!] Usage: --make-custom-ipsw-2 [TARGET_IPSW_PATH] [BASE_IPSW_PATH] [iOS_VERSION]"
        exit 1
    fi
    TARGET_IPSW="${args[0]}"
    BASE_IPSW="${args[1]}"
    IOS_VERSION="${args[2]}"
    if [[ $IDENTIFIER != iPad5* ]]; then
        echo "[!] --make-custom-ipsw-2 is not supported on any other devices than the iPad mini 4, Air 2."
        echo "[!] Use --make-custom-ipsw instead"
        exit 1
    fi
    if [[ $IDENTIFIER == iPad5* ]] && [[ $IOS_VERSION == 11.2* || $IOS_VERSION == 11.1* || $IOS_VERSION == 11.0* || $IOS_VERSION == 10.* || $IOS_VERSION == 9.* || $IOS_VERSION == 8.* ]]; then
        echo "[!] SEP is incompatible"
        echo "[!] You cannot restore or make a custom IPSW for this version."
        exit 1
    fi
    if [[ $IOS_VERSION == 11.* ]]; then
        KEYS_VERSION="13.4"
    else
        KEYS_VERSION="$IOS_VERSION"
    fi
    KEY_FILE="keys/$IDENTIFIER.txt"
    # Extract iBSS and iBEC keys
    IBSS_KEY=$(read_key_value "$KEY_FILE" "ibss-$KEYS_VERSION")
    IBEC_KEY=$(read_key_value "$KEY_FILE" "ibec-$KEYS_VERSION")
    echo "[*] Making custom IPSW..."
    savedir="restorefiles/$IDENTIFIER/$IOS_VERSION"
    rm -rf "$savedir"
    mkdir -p "$savedir"
    echo ""
    unzip "$TARGET_IPSW" -d tmp1
    unzip "$BASE_IPSW" -d tmp2
    if [[ "$IOS_VERSION" == 10.1* || "$IOS_VERSION" == 10.2* ]] && [[ $IDENTIFIER == iPhone6* ]]; then
        echo "iOS 10.3 iBSS and iBEC will be used."
        sudo ./bin/pzb -g Firmware/dfu/$IBSS http://appldnld.apple.com/ios10.3/091-02949-20170327-7584B286-0D86-11E7-A4FA-7ECE122AC769/iPhone_4.0_64bit_10.3_14E277_Restore.ipsw
        sudo ./bin/pzb -g Firmware/dfu/$IBEC http://appldnld.apple.com/ios10.3/091-02949-20170327-7584B286-0D86-11E7-A4FA-7ECE122AC769/iPhone_4.0_64bit_10.3_14E277_Restore.ipsw
        rm -rf tmp1/Firmware/dfu/$IBSS10
        rm -rf tmp1/Firmware/dfu/$IBEC10
        mv $IBSS tmp1/Firmware/dfu/$IBSS10
        mv $IBEC tmp1/Firmware/dfu/$IBEC10
        sudo rm -rf $IBSS
        sudo rm -rf $IBEC
    fi
    if [[ "$IOS_VERSION" == 10.1* || "$IOS_VERSION" == 10.2* ]]; then
        rm -rf tmp1/Firmware/all_flash/$ALLFLASH/$LLB10
        rm -rf tmp1/Firmware/all_flash/$ALLFLASH/$IBOOT10
        cp tmp2/Firmware/all_flash/$LLB tmp1/Firmware/all_flash/$ALLFLASH/$LLB10
        cp tmp2/Firmware/all_flash/$IBOOT tmp1/Firmware/all_flash/$ALLFLASH/$IBOOT10
        rm -rf tmp1/BuildManifest.plist
        cp manifest/$IDENTIFIER/$IOS_VERSION-Manifest.plist tmp1/BuildManifest.plist
    elif [[ "$IOS_VERSION" == 10.3* ]]; then
        rm -rf tmp1/Firmware/all_flash/$LLB
        rm -rf tmp1/Firmware/all_flash/$IBOOT
        cp tmp2/Firmware/all_flash/$LLB tmp1/Firmware/all_flash/$LLB
        cp tmp2/Firmware/all_flash/$IBOOT tmp1/Firmware/all_flash/$IBOOT
    else
        if [[ $IOS_VERSION == 14.0* || $IOS_VERSION == 14.1* || $IOS_VERSION == 14.2* ]] && [[ $IDENTIFIER == iPhone10* ]]; then
            # A11 hax to tether restore 14.0-14.2 on 16 SEP, 14.3 iBoot method (thanks to verygenericname for pointing that out)
            IPSW_PATH=$($zenity --file-selection --title="Select the iOS 14.3 IPSW file (for iBSS and iBEC)")
            rm -rf tmp1/Firmware/dfu/$IBSS
            rm -rf tmp1/Firmware/dfu/$IBEC 
            unzip -j "$IPSW_PATH" "Firmware/dfu/$IBSS" -d tmp1/Firmware/dfu
            unzip -j "$IPSW_PATH" "Firmware/dfu/$IBEC" -d tmp1/Firmware/dfu
            # hardcode custom buildmanifest, so it redirects to getting 14.3 keys instead of 14.0-14.2's
            sudo rm -rf tmp1/BuildManifest.plist
            cp manifest/$IDENTIFIER/$IOS_VERSION-Manifest.plist tmp1/BuildManifest.plist            
        fi
        if [[ $IOS_VERSION == 11.* || $IOS_VERSION == 12.* || $IOS_VERSION == 13.1* || $IOS_VERSION == 13.2* || $IOS_VERSION == 13.3* ]] && [[ $IDENTIFIER == iPad5* ]]; then
            sudo ./bin/pzb -g Firmware/all_flash/$DEVICETREE https://updates.cdn-apple.com/2020WinterFCS/fullrestores/041-42831/7341A77D-6526-4C64-8753-D886106F97CD/iPad_64bit_TouchID_13.4_17E255_Restore.ipsw
            sudo ./bin/pzb -g $KERNELCACHE https://updates.cdn-apple.com/2020WinterFCS/fullrestores/041-42831/7341A77D-6526-4C64-8753-D886106F97CD/iPad_64bit_TouchID_13.4_17E255_Restore.ipsw
            sudo rm -rf "tmp1/Firmware/all_flash/$DEVICETREE"
            sudo rm -rf "tmp1/$KERNELCACHE"
            cp $KERNELCACHE "tmp1/$KERNELCACHE"
            cp $DEVICETREE "tmp1/Firmware/all_flash/$DEVICETREE"
            sudo rm -rf $KERNELCACHE
            sudo rm -rf $DEVICETREE
            smallest_rdskdmg=$(find_dmg tmp1 smallest)
            update_rdskdmg=$(find_dmg tmp1 largest 1073741824)
            if [[ $IOS_VERSION == 12.* || $IOS_VERSION == 11.* ]]; then
                sudo rm -rf $smallest_rdskdmg
                cd tmp1
                sudo ../bin/pzb -g 048-64389-366.dmg https://updates.cdn-apple.com/2020WinterFCS/fullrestores/041-42831/7341A77D-6526-4C64-8753-D886106F97CD/iPad_64bit_TouchID_13.4_17E255_Restore.ipsw
                cd ..
                sudo rm -rf $update_rdskdmg
                cd tmp1
                if [[ $IOS_VERSION == 11.* ]]; then
                    sudo ../bin/pzb -g BuildManifest.plist https://updates.cdn-apple.com/2020WinterFCS/fullrestores/041-42831/7341A77D-6526-4C64-8753-D886106F97CD/iPad_64bit_TouchID_13.4_17E255_Restore.ipsw
                    sudo ../bin/pzb -g Firmware/048-64389-366.dmg.trustcache https://updates.cdn-apple.com/2020WinterFCS/fullrestores/041-42831/7341A77D-6526-4C64-8753-D886106F97CD/iPad_64bit_TouchID_13.4_17E255_Restore.ipsw    
                    sudo ../bin/pzb -g Firmware/048-64500-319.dmg.trustcache https://updates.cdn-apple.com/2020WinterFCS/fullrestores/041-42831/7341A77D-6526-4C64-8753-D886106F97CD/iPad_64bit_TouchID_13.4_17E255_Restore.ipsw
                    sudo ../bin/pzb -g Firmware/048-65142-364.dmg.trustcache https://updates.cdn-apple.com/2020WinterFCS/fullrestores/041-42831/7341A77D-6526-4C64-8753-D886106F97CD/iPad_64bit_TouchID_13.4_17E255_Restore.ipsw
                    mv 048-64389-366.dmg.trustcache Firmware/048-64389-366.dmg.trustcache
                    mv 048-64500-319.dmg.trustcache Firmware/048-64500-319.dmg.trustcache
                    mv 048-65142-364.dmg.trustcache Firmware/048-65142-364.dmg.trustcache
                    sudo ../bin/pzb -g Firmware/dfu/$IBSS https://updates.cdn-apple.com/2020WinterFCS/fullrestores/041-42831/7341A77D-6526-4C64-8753-D886106F97CD/iPad_64bit_TouchID_13.4_17E255_Restore.ipsw
                    sudo ../bin/pzb -g Firmware/dfu/$IBEC https://updates.cdn-apple.com/2020WinterFCS/fullrestores/041-42831/7341A77D-6526-4C64-8753-D886106F97CD/iPad_64bit_TouchID_13.4_17E255_Restore.ipsw
                    sudo rm -rf Firmware/dfu/$IBSS
                    sudo rm -rf Firmware/dfu/$IBEC
                    sudo mv $IBSS Firmware/dfu/$IBSS
                    sudo mv $IBEC Firmware/dfu/$IBEC
                    cd ..
                    root_dmg=$(find_dmg tmp1 largest)
                    mv $root_dmg tmp1/048-64500-319.dmg
                    cd tmp1
                fi
                sudo ../bin/pzb -g 048-65142-364.dmg https://updates.cdn-apple.com/2020WinterFCS/fullrestores/041-42831/7341A77D-6526-4C64-8753-D886106F97CD/iPad_64bit_TouchID_13.4_17E255_Restore.ipsw
                cd ..
            fi
        fi
    fi

    # determine restore ramdisk
    smallest_dmg=$(find_dmg tmp1 smallest)
    # determine update ramdisk (experimental tethered updates?)
    update_dmg=$(find_dmg tmp1 largest 1073741824)
    # determine restore ramdisk final destination
    smallest_dmg_2=$(find_dmg tmp2 smallest)
    # determine update ramdisk final destination
    update_dmg_2=$(find_dmg tmp2 largest 1073741824)
    # determine root filesystem 
    root_dmg_path=$(find_dmg tmp1 largest)
    # determine root filesystem final destination
    root_dmg_path_2=$(find_dmg tmp2 largest)
    rm -rf $root_dmg_path_2
    mv $root_dmg_path $root_dmg_path_2
    rm -rf tmp2/Firmware/all_flash/$DEVICETREE
    mv tmp1/Firmware/all_flash/$DEVICETREE tmp2/Firmware/all_flash/$DEVICETREE
    echo "Patching iBSS"
    mkdir -p work
    ./bin/img4 -i tmp1/Firmware/dfu/$IBSS -o work/iBSS.raw -k $IBSS_KEY
    ./bin/iBoot64Patcher work/iBSS.raw work/iBSS.patched
    ./bin/img4 -i work/iBSS.patched -o tmp2/Firmware/dfu/$IBSS -A -T ibss
    echo "Patching iBEC"
    ./bin/img4 -i tmp1/Firmware/dfu/$IBEC -o work/iBEC.raw -k $IBEC_KEY
    ./bin/iBoot64Patcher work/iBEC.raw work/iBEC.patched
    ./bin/img4 -i work/iBEC.patched -o tmp2/Firmware/dfu/$IBEC -A -T ibec
    if [[ "$IDENTIFIER" == iPhone6,* ]] && [[ "$IOS_VERSION" == 10.1* || "$IOS_VERSION" == 10.2* ]]; then
        cp tmp1/$KERNELCACHE10 work/kernel.orig 
    else
        cp tmp1/$KERNELCACHE work/kernel.orig 
    fi     
    cd work
    echo "making patched restore chain"
    ../bin/img4 -i kernel.orig -o kernel.raw
    ../bin/KPlooshFinder kernel.raw kernel.patched
    ../bin/kerneldiff kernel.raw kernel.patched kernel.bpatch
    ../bin/img4 -i kernel.orig -o kernel.im4p -T rkrn -P kernel.bpatch -J || true
    mv kernel.im4p ../tmp2/$KERNELCACHE
    # build ramdisk
    cd ..
    ./bin/img4 -i "$smallest_dmg" -o ramdisk.raw
    if [[ "$IDENTIFIER" == iPhone6,* || $IDENTIFIER == iPod7* || $IDENTIFIER == iPad4* ]] && [[ "$IOS_VERSION" == 10.* || "$IOS_VERSION" == 11.0* || "$IOS_VERSION" == 11.1* || "$IOS_VERSION" == 11.2* ]]; then
        echo "growing ramdisk"
        ./bin/hfsplus ramdisk.raw grow 60000000
    else
        echo "skipping ramdisk grow"
    fi
    echo "extracting asr to patch"
    ./bin/hfsplus ramdisk.raw extract usr/sbin/asr 
    echo "patching asr"
    ./bin/asr64_patcher asr patched_asr
    ./bin/ldid -e asr > ents.plist
    ./bin/ldid -Sents.plist patched_asr
    echo "replacing asr with patched asr"
    ./bin/hfsplus ramdisk.raw rm usr/sbin/asr
    sleep 4
    ./bin/hfsplus ramdisk.raw add patched_asr usr/sbin/asr
    sleep 4
    if [[ "$IDENTIFIER" == iPhone6,* || $IDENTIFIER == iPad4* ]] && [[ "$IOS_VERSION" == 10.* ]]; then
        ./bin/hfsplus ramdisk.raw chmod 100755 usr/sbin/asr
    else
        ./bin/hfsplus ramdisk.raw chmod 755 usr/sbin/asr 
    fi
    if [[ $IOS_VERSION == 14.* || $IOS_VERSION == 15.* ]]; then
        echo "patching restored_external"
        sudo ./bin/hfsplus ramdisk.raw extract usr/local/bin/restored_external 
        if [[ $IDENTIFIER == iPhone10,3 || $IDENTIFIER == iPhone10,6 ]]; then
            echo "[!] You are trying to restore an iPhone X to iOS $IOS_VERSION"
            echo "An additional patch is required!"
            ./bin/ipx_restored_patcher restored_external patched_external
            ./bin/restored_external64_patcher patched_external patched_restored_external
        else
            ./bin/restored_external64_patcher restored_external patched_restored_external
        fi
        ./bin/ldid -e restored_external > ents.plist
        ./bin/ldid -Sents.plist patched_restored_external
        echo "replacing restored_external with patched restored_external"
        ./bin/hfsplus ramdisk.raw rm usr/local/bin/restored_external
        sleep 4 
        ./bin/hfsplus ramdisk.raw add patched_restored_external usr/local/bin/restored_external
        sleep 4
        ./bin/hfsplus ramdisk.raw chmod 755 usr/local/bin/restored_external
    fi
    sleep 4
    echo "Packing patched Ramdisk as im4p"
    ./bin/img4 -i ramdisk.raw -o $smallest_dmg_2 -T rdsk -A
    rm -rf "work"
    rm -rf asr
    rm -rf restored_external
    rm -rf patched_external
    rm -rf patched_restored_external
    rm -rf patched_asr
    rm -rf ents.plist
    rm -rf ramdisk.raw
    # build update ramdisk
    echo "building patched update ramdisk..."
    ./bin/img4 -i "$update_dmg" -o ramdisk.raw
    if [[ "$IDENTIFIER" == iPhone6,* || $IDENTIFIER == iPod7* || $IDENTIFIER == iPad4* ]] && [[ "$IOS_VERSION" == 10.* || "$IOS_VERSION" == 11.0* || "$IOS_VERSION" == 11.1* || "$IOS_VERSION" == 11.2* ]]; then
        echo "growing ramdisk"
        ./bin/hfsplus ramdisk.raw grow 70000000
    else
        echo "skipping ramdisk grow"
    fi
    echo "extracting asr to patch"
    ./bin/hfsplus ramdisk.raw extract usr/sbin/asr 
    echo "patching asr"
    ./bin/asr64_patcher asr patched_asr
    ./bin/ldid -e asr > ents.plist
    ./bin/ldid -Sents.plist patched_asr
    echo "replacing asr with patched asr"
    ./bin/hfsplus ramdisk.raw rm usr/sbin/asr
    sleep 4
    ./bin/hfsplus ramdisk.raw add patched_asr usr/sbin/asr
    sleep 4
    if [[ "$IDENTIFIER" == iPhone6,* || $IDENTIFIER == iPad4* ]] && [[ "$IOS_VERSION" == 10.* ]]; then
        ./bin/hfsplus ramdisk.raw chmod 100755 usr/sbin/asr
    else
        ./bin/hfsplus ramdisk.raw chmod 755 usr/sbin/asr 
    fi
    # restored_external in update ramdisk is restored_update
    if [[ $IOS_VERSION == 14.* || $IOS_VERSION == 15.* ]]; then
        echo "patching restored_update"
        ./bin/hfsplus ramdisk.raw extract usr/local/bin/restored_update 
        if [[ $IDENTIFIER == iPhone10,3 || $IDENTIFIER == iPhone10,6 ]]; then
            echo "[!] You are trying to restore an iPhone X to iOS $IOS_VERSION"
            echo "An additional patch is required!"
            ./bin/ipx_restored_patcher restored_update patched_external
            ./bin/restored_external64_patcher patched_external patched_restored_external
        else
            ./bin/restored_external64_patcher restored_update patched_restored_external
        fi
        ./bin/ldid -e restored_update > ents.plist
        ./bin/ldid -Sents.plist patched_restored_external
        echo "replacing restored_update with patched restored_update"
        ./bin/hfsplus ramdisk.raw rm usr/local/bin/restored_update
        sleep 4 
        ./bin/hfsplus ramdisk.raw add patched_restored_external usr/local/bin/restored_update
        sleep 4
        ./bin/hfsplus ramdisk.raw chmod 755 usr/local/bin/restored_update
    fi
    sleep 4
    echo "Packing patched Ramdisk as im4p"
    ./bin/img4 -i ramdisk.raw -o $update_dmg_2 -T rdsk -A
    rm -rf asr
    rm -rf restored_update
    rm -rf patched_external
    rm -rf patched_restored_external
    rm -rf patched_asr
    rm -rf ents.plist
    rm -rf ramdisk.raw
    rm -rf "tmp1"
    cd tmp2
    zip -0 -r ../custom.ipsw *
    cd ..
    mv custom.ipsw "$savedir/custom.ipsw"
    rm -rf "tmp2"
    rm -rf "$savedir/ramdisk.im4p"
    rm -rf "$savedir/updateramdisk.im4p"
    rm -rf "$savedir/kernel.im4p"
    echo "Custom IPSW + patched restore chain has been made! Use --restore $IOS_VERSION to downgrade to the designated firmware"
    exit 1
}

main() {
    bootstrap_environment
    init_runtime_context
    cmd_make_custom_ipsw_2 "$@"
}

main "$@"
