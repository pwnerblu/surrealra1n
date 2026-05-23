#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

. "$PROJECT_ROOT/scripts/core/lib/bootstrap.sh"
. "$PROJECT_ROOT/scripts/core/lib/usage.sh"
. "$PROJECT_ROOT/scripts/core/lib/runtime_context.sh"
. "$PROJECT_ROOT/scripts/core/lib/command_helpers.sh"
. "$PROJECT_ROOT/scripts/core/lib/flows.sh"

cmd_make_custom_ipsw() {
    normalize_command_args "--make-custom-ipsw" "$@"
    local args=("${NORMALIZED_ARGS[@]}")

    if [[ ${#args[@]} -ne 3 ]]; then
        echo "[!] Usage: --make-custom-ipsw [TARGET_IPSW_PATH] [BASE_IPSW_PATH] [iOS_VERSION]"
        exit 1
    fi
    TARGET_IPSW="${args[0]}"
    BASE_IPSW="${args[1]}"
    IOS_VERSION="${args[2]}"
    if [[ "$IDENTIFIER" == iPhone6* ]] && [[ "$IOS_VERSION" == 10.0* || "$IOS_VERSION" == 9.* || "$IOS_VERSION" == 8.* || "$IOS_VERSION" == 7.* ]]; then
        echo "[!] SEP is incompatible"
        echo "[!] You cannot restore to this version or make a custom IPSW for it"
        exit 1
    fi
    if [[ "$IDENTIFIER" == iPad4,4 || $IDENTIFIER == iPad4,5 ]] && [[ "$IOS_VERSION" == 10.0* || "$IOS_VERSION" == 9.* || "$IOS_VERSION" == 8.* || "$IOS_VERSION" == 7.* ]]; then
        echo "[!] SEP is incompatible"
        echo "[!] You cannot restore to this version or make a custom IPSW for it"
        exit 1
    fi
    if [[ "$IDENTIFIER" == iPad4,6 ]] && [[ "$IOS_VERSION" == 11.2* || "$IOS_VERSION" == 11.1* || "$IOS_VERSION" == 11.0* || "$IOS_VERSION" == 10.* || "$IOS_VERSION" == 9.* || "$IOS_VERSION" == 8.* || "$IOS_VERSION" == 7.* ]]; then
        echo "[!] SEP is incompatible"
        echo "[!] You cannot restore to this version or make a custom IPSW for it"
        exit 1
    fi
    if [[ $IDENTIFIER == iPad4,4 || $IDENTIFIER == iPad4,5 || $IDENTIFIER == iPod7* || $IDENTIFIER == iPhone7* || $IDENTIFIER == iPad5* ]] && [[ $IOS_VERSION == 10.1* || $IOS_VERSION == 10.2* ]]; then
        echo "[!] 10.1-10.2.1 tethered support is not added yet for this device"
        echo "[!] We may add this support in a future update. For now, please do 10.3 or later"
        exit 1
    fi
    if [[ "$IDENTIFIER" == iPhone6* ]] && [[ "$IOS_VERSION" == 11.2* || "$IOS_VERSION" == 11.1* || "$IOS_VERSION" == 11.0* ]]; then
        echo "[!] SEP is partially compatible"
        echo "[!] Restoring to iOS $IOS_VERSION will use iOS 10.3.3 SEP (because iOS 12 SEP is fully incompatible with 11.2.6 and below)"
        echo "[!] The following issues will occur after the restore: Activation issues, Touch ID not working, unable to connect to password-protected Wi-Fi networks, etc. Device passcode may work though."
        echo "[!] This is ONLY recommended for advanced users, saving activation tickets with an SSH ramdisk is required before restoring to this version"
        echo "[!] PLEASE. PLEASE! DO NOT use this to bypass iCloud, only save activation tickets on a device you legally own"
        read -p "Press enter to continue"
    fi
    if [[ $IDENTIFIER == iPhone10* ]] && [[ $IOS_VERSION == 16.6* ]]; then
        echo "[!] iOS $LATEST_VERSION Cryptex is partially compatible"
        echo "[!] You will have the following issues:"
        echo "[!] iMessage/SMS won't work (there is a fix for that in the FutureRestore support Discord Server)"
        echo "[!] VPN may not work, and potentially other issues"
        read -p "Press enter to continue"
    fi
    if [[ $IDENTIFIER == iPhone10* ]] && [[ $IOS_VERSION == 16.0* || $IOS_VERSION == 16.1* || $IOS_VERSION == 16.2* || $IOS_VERSION == 16.3* || $IOS_VERSION == 16.4* || $IOS_VERSION == 16.5* ]]; then
        echo "[!] Latest Cryptex is incompatible"
        echo "You cannot restore or make a custom IPSW for this version."
        exit 1
    fi
    if [[ "$IDENTIFIER" == iPad4,5 || $IDENTIFIER == iPad4,4 ]] && [[ "$IOS_VERSION" == 11.2* || "$IOS_VERSION" == 11.1* || "$IOS_VERSION" == 11.0* ]]; then
        echo "[!] SEP is partially compatible"
        echo "[!] Restoring to iOS $IOS_VERSION will use iOS 10.3.3 SEP (because iOS 12 SEP is fully incompatible with 11.2.6 and below)"
        echo "[!] The following issues will occur after the restore: Activation issues, unable to connect to password-protected Wi-Fi networks, etc. Device passcode may work though."
        echo "[!] This is ONLY recommended for advanced users, saving activation tickets with an SSH ramdisk is required before restoring to this version"
        echo "[!] PLEASE. PLEASE! DO NOT use this to bypass iCloud, only save activation tickets on a device you legally own"
        read -p "Press enter to continue"
    fi
    if [[ "$IDENTIFIER" == iPhone7* ]] && [[ "$IOS_VERSION" == 11.2* || "$IOS_VERSION" == 11.1* || "$IOS_VERSION" == 11.0* || "$IOS_VERSION" == 10.0* || "$IOS_VERSION" == 9.* || "$IOS_VERSION" == 8.* ]]; then
        echo "[!] SEP is incompatible"
        echo "[!] You cannot restore to this version or make a custom IPSW for it"
        exit 1
    fi
    if [[ $IDENTIFIER == iPod7* || $IDENTIFIER == iPad5,1 || $IDENTIFIER == iPad5,2 || $IDENTIFIER == iPhone7* ]] && [[ $IOS_VERSION == 10.3* ]]; then
        echo "[!] SEP is compatible, but read the following:"
        echo "[!] This will use tvOS 10.2.2 SEP from the Apple TV HD."
        echo "[!] Some device features may or may not break, your mileage may vary."
        read -p "Press enter to continue"
    fi
    if [[ "$IDENTIFIER" == iPod7* ]] && [[ "$IOS_VERSION" == 10.0* || "$IOS_VERSION" == 9.* || "$IOS_VERSION" == 8.* ]]; then
        echo "[!] SEP is incompatible"
        echo "[!] You cannot restore to this version or make a custom IPSW for it"
        exit 1
    fi

    if [[ "$IDENTIFIER" == iPhone6* ]] && [[ "$IOS_VERSION" == 10.3.3 ]]; then
        echo "[!] iOS 10.3.3 can be restored untethered via OTA downgrade"
        echo "[!] It is recommended to use Legacy iOS Kit to downgrade to 10.3.3 untethered (https://github.com/LukeZGD/Legacy-iOS-Kit)"
        read -p "Press enter to continue with iOS 10.3.3 tethered downgrade"
    fi

    if [[ "$IDENTIFIER" == iPad7,5 ]] && [[ $IOS_VERSION == 13.4* || $IOS_VERSION == 13.5* || $IOS_VERSION == 13.6* || $IOS_VERSION == 13.7* || $IOS_VERSION == 14.* || $IOS_VERSION == 15.* ]]; then
        echo "[!] SEP is partially incompatible"
        echo "[!] The iPadOS $LATEST_VERSION SEP is not fully compatible with this version."
        echo "[!] The following issues may occur:"
        echo "[!] On iPadOS 14.0 - 15.7, you will have activation issues. On 15.x, you will also have issues when taking a photo or a video."
        echo "[!] Sideloading, iMessage, etc. may not work after downgrading with surrealra1n to iPadOS $IOS_VERSION"
        echo "[!] Touch ID will cease to function fully on 13.x, but it is broken on iPadOS 14-15. And setting a passcode may cause the device to crash."
        echo "[!] And if you are restoring to iPadOS 13.4 - 13.7, you will be stuck in a blank screen after the restore. Put the device into real DFU mode and boot it normally."
        echo "[!] It is recommended to use turdus merula instead: https://sep.lol"
        read -p "Press enter to continue"
    fi 
    if [[ "$IDENTIFIER" == iPad5* ]] && [[ $IOS_VERSION == 13.* ]]; then
        echo "[!] SEP is partially incompatible"
        echo "[!] The iPadOS $LATEST_VERSION SEP is not fully compatible with this version."
        echo "[!] The following issues may occur:"
        echo "[!] Touch ID will cease to function fully."
        read -p "Press enter to continue"
    fi 
    if [[ "$IDENTIFIER" == iPad5* ]] && [[ $IOS_VERSION == 12.* || $IOS_VERSION == 11.4* || $IOS_VERSION == 11.3* ]]; then
        echo "[!] SEP is partially incompatible"
        echo "[!] The iPadOS $LATEST_VERSION SEP is not fully compatible with this version."
        echo "[!] The following issues may occur:"
        echo "[!] Touch ID will cease to function fully."
        if [[ $IOS_VERSION == 12.* ]]; then
            echo "[!] USB accessories will not work, thus you cannot sideload with a PC"
            echo "[!] To sideload a jailbreak (eg: Chimera, unc0ver), you will need to use https://jailbreaks.app when it is signed."
        fi
        read -p "Press enter to continue"
    fi 
    if [[ "$IDENTIFIER" == iPad5,3 || $IDENTIFIER == iPad5,4 ]] && [[ $IOS_VERSION == 11.2* || $IOS_VERSION == 11.1* || $IOS_VERSION == 11.0* || $IOS_VERSION == 10.* || $IOS_VERSION == 9.* || $IOS_VERSION == 8.* ]]; then
        echo "[!] SEP is incompatible"
        echo "[!] You cannot restore to this version or make a custom IPSW for it"
        exit 1
    fi 
    if [[ "$IDENTIFIER" == iPad7,5 ]] && [[ $IOS_VERSION == 13.3* || $IOS_VERSION == 13.2* || $IOS_VERSION == 13.1* || $IOS_VERSION == 13.0* || $IOS_VERSION == 12.* || $IOS_VERSION == 11.* ]]; then
        echo "[!] SEP is incompatible"
        echo "[!] The iPadOS $LATEST_VERSION SEP is not compatible with this version."
        echo "[!] You MUST use turdus merula instead: https://sep.lol"
        exit 1
    fi 
    if [[ "$IDENTIFIER" == iPhone10* ]] && [[ $IOS_VERSION == 14.* || $IOS_VERSION == 15.* ]]; then
        echo "[!] SEP is partially incompatible"
        echo "[!] The following issues may occur:"
        echo "[!] You will have activation issues, Touch ID resetting (If you have an iPhone X, Face ID will not work), etc."
        echo "[!] Sideloading, iMessage, etc. may not work after downgrading with surrealra1n to iOS $IOS_VERSION"
        if [[ $IOS_VERSION == 14.0* || $IOS_VERSION == 14.1* || $IOS_VERSION == 14.2* ]]; then
            # Additional warnings when restoring 14.0-14.2 on A11 (with 14.3 iBoot method by Nathan)    
            echo "[!] Additionally, since we are restoring 14.0-14.2, this will have all of the issues of 14.3-15.6.1, but it may have additional issues, especially on versions below 14.2."
            echo "[!] 14.0-14.2 on A11 MUST use 14.3 iBSS/iBEC to successfully restore and boot."    
        fi
        if [[ $IDENTIFIER == iPhone10,2 || $IDENTIFIER == iPhone10,5 || $IDENTIFIER == iPhone10,6 || $IDENTIFIER == iPhone10,3 ]] && [[ $IOS_VERSION == 14.0* || $IOS_VERSION == 14.1* || $IOS_VERSION == 14.2* ]]; then   
            echo "[!] The 14.3 iBoot method is technically supported on this device, but the custom buildmanifests required for this method do not exist for your device yet!"   
            echo "[!] A future update will add the required buildmanifests to do this method on iPhone 8 Plus, and X." 
            exit 1
        fi
        read -p "Press enter to continue"
    fi 
    if [[ "$IDENTIFIER" == iPhone10* ]] && [[ $IOS_VERSION == 13.* || $IOS_VERSION == 12.* || $IOS_VERSION == 11.* ]]; then
        echo "[!] SEP is incompatible"
        echo "[!] You cannot restore to this version or make a custom IPSW for it"
        exit 1
    fi 
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
        find tmp1/Firmware/all_flash/ -type f ! -name '*DeviceTree*' -exec rm -f {} +
        find tmp2/Firmware/all_flash/ -type f ! -name '*DeviceTree*' -exec cp {} tmp1/Firmware/all_flash/ \;
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
    mkdir -p work
    if [[ "$IDENTIFIER" == iPhone6,* ]] && [[ "$IOS_VERSION" == 10.1* || "$IOS_VERSION" == 10.2* ]]; then
        cp tmp1/$KERNELCACHE10 work/kernel.orig 
    else
        cp tmp1/$KERNELCACHE work/kernel.orig 
    fi  
    if [[ $IDENTIFIER == iPhone10,3 || $IDENTIFIER == iPhone10,6 ]] && [[ $IOS_VERSION == 16.* ]]; then
        # Use latest signed AOP on iOS 16.x restores
        echo "Replacing AOP firmware"
        mv tmp2/Firmware/AOP/aopfw-iphone10baop.im4p tmp1/Firmware/AOP/aopfw-iphone10baop.im4p
    fi
    if [[ $IDENTIFIER == iPhone10,1 || $IDENTIFIER == iPhone10,4 || $IDENTIFIER == iPhone10,2 || $IDENTIFIER == iPhone10,5 ]] && [[ $IOS_VERSION == 16.* ]]; then
        # Use latest signed AOP on iOS 16.x restores
        echo "Replacing AOP firmware"
        mv tmp2/Firmware/AOP/aopfw-iphone10aop.im4p tmp1/Firmware/AOP/aopfw-iphone10aop.im4p
    fi
    rm -rf "tmp2"
    if [[ $IOS_VERSION == 16.* ]]; then
        # prepare the localboot stuff, pre-patch kernel-cache
        ./bin/img4 -i tmp1/$KERNELCACHE -o kernel.raw
        ./bin/Kernel64Patcher kernel.raw kernel.patched -e -o -h
        ./bin/img4 -i kernel.patched -o tmp1/$KERNELCACHE -A -T krnl
    fi
    if [[ $IOS_VERSION == 15.* ]] && [[ $IDENTIFIER != iPad5* ]]; then
        # prepare the localboot stuff, pre-patch kernel-cache
        ./bin/img4 -i tmp1/$KERNELCACHE -o kernel.raw
        ./bin/Kernel64Patcher kernel.raw kernel.patched -e -o -r -b15
        ./bin/img4 -i kernel.patched -o tmp1/$KERNELCACHE -A -T krnl
    fi
    if [[ $IOS_VERSION == 14.* ]] && [[ $IDENTIFIER != iPad5* ]]; then
        # prepare the localboot stuff, pre-patch kernel-cache
        ./bin/img4 -i tmp1/$KERNELCACHE -o kernel.raw
        ./bin/Kernel64Patcher kernel.raw kernel.patched -b
        ./bin/img4 -i kernel.patched -o tmp1/$KERNELCACHE -A -T krnl
    fi
    cd tmp1
    zip -0 -r ../custom.ipsw *
    cd ..
    mv custom.ipsw "$savedir/custom.ipsw"

    # determine restore ramdisk
    if [[ $IDENTIFIER == iPhone10,3 || $IDENTIFIER == iPhone10,6 ]]; then
        # mainly just 16.x stuff
        restore_ramdisk_dmg="098-08863-001.dmg"
        update_ramdisk_dmg="098-09105-001.dmg"
        ipsw_url="https://updates.cdn-apple.com/2022FallFCS/fullrestores/012-65861/0A0400A0-2174-4D49-91B7-43FC9DE24272/iPhone10,3,iPhone10,6_16.0_20A362_Restore.ipsw"
    fi
    if [[ $IDENTIFIER == iPhone10,1 || $IDENTIFIER == iPhone10,4 ]]; then
        # mainly just 16.x stuff
        restore_ramdisk_dmg="098-08863-001.dmg"
        update_ramdisk_dmg="098-09105-001.dmg"
        ipsw_url="https://updates.cdn-apple.com/2022FallFCS/fullrestores/012-65931/BD2515B7-7802-4EB4-9377-98E3238EA5A8/iPhone_4.7_P3_16.0_20A362_Restore.ipsw"
    fi
    if [[ $IDENTIFIER == iPhone10,2 || $IDENTIFIER == iPhone10,5 ]]; then
        # mainly just 16.x stuff
        restore_ramdisk_dmg="098-08863-001.dmg"
        update_ramdisk_dmg="098-09105-001.dmg"
        ipsw_url="https://updates.cdn-apple.com/2022FallFCS/fullrestores/012-65568/0851247C-1B06-4CD4-B3C2-5A94026970B7/iPhone_5.5_P3_16.0_20A362_Restore.ipsw"
    fi
    if [[ $IOS_VERSION == 16.* ]]; then
        # 16.0 ramdisk/kernel, stuff
        smallest_dmg="$restore_ramdisk_dmg"
        update_dmg="$update_ramdisk_dmg"
        sudo ./bin/pzb -g $smallest_dmg $ipsw_url
        sudo ./bin/pzb -g $update_dmg $ipsw_url
        sudo ./bin/pzb -g $KERNELCACHE $ipsw_url
        sudo mv $KERNELCACHE work/kernel.orig
    else
        smallest_dmg=$(find_dmg tmp1 smallest)
        # determine update ramdisk (experimental tethered updates?)
        update_dmg=$(find_dmg tmp1 largest 1073741824)   
    fi
    cd work
    echo "making patched restore chain"
    ../bin/img4 -i kernel.orig -o kernel.raw
    ../bin/KPlooshFinder kernel.raw kernel.patched
    if [[ $IDENTIFIER == iPad5* || $IDENTIFIER == iPhone7* ]] && [[ $IOS_VERSION == 10.* ]]; then
        mv kernel.patched kernel.patch
        ../bin/Kernel64Patcher2 kernel.patch kernel.patched -u 11 --skip-sks --skip-acm --skip-amfi
    fi
    ../bin/kerneldiff kernel.raw kernel.patched kernel.bpatch
    ../bin/img4 -i kernel.orig -o kernel.im4p -T rkrn -P kernel.bpatch -J || true
    mv kernel.im4p ../$savedir/kernel.im4p
    # build ramdisk
    cd ..
    ./bin/img4 -i "$smallest_dmg" -o ramdisk.raw
    if [[ "$IOS_VERSION" == 10.* || "$IOS_VERSION" == 11.0* || "$IOS_VERSION" == 11.1* || "$IOS_VERSION" == 11.2* ]]; then
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
    if [[ "$IOS_VERSION" == 10.* ]]; then
        ./bin/hfsplus ramdisk.raw chmod 100755 usr/sbin/asr
    else
        ./bin/hfsplus ramdisk.raw chmod 755 usr/sbin/asr 
    fi
    if [[ $IDENTIFIER == iPhone10,3 || $IDENTIFIER == iPhone10,6 ]]; then
        echo "Adding ipx patches"
        sudo ./bin/hfsplus ramdisk.raw extract usr/local/bin/restored_external 
        ./bin/ipx_restored_patcher restored_external patched_restored_external
        ./bin/ldid -e restored_external > ents.plist
        ./bin/ldid -Sents.plist patched_restored_external
        echo "replacing restored_external with patched restored_external"
        ./bin/hfsplus ramdisk.raw rm usr/local/bin/restored_external
        sleep 4 
        ./bin/hfsplus ramdisk.raw add patched_restored_external usr/local/bin/restored_external
        sleep 4
        ./bin/hfsplus ramdisk.raw chmod 755 usr/local/bin/restored_external
    fi
    if [[ $IOS_VERSION == 14.* || $IOS_VERSION == 15.* || $IOS_VERSION == 16.* ]]; then
        # do libimg4 validation patch
        echo "Doing validation patch so sealing system volume works"
        sudo ./bin/hfsplus ramdisk.raw extract usr/lib/libimg4.dylib
        ./bin/libimg4_patcher libimg4.dylib libimg4.patched
        ./bin/ldid -Sents.plist libimg4.patched
        sudo ./bin/hfsplus ramdisk.raw rm usr/lib/libimg4.dylib
        sudo ./bin/hfsplus ramdisk.raw add libimg4.patched usr/lib/libimg4.dylib
        sudo ./bin/hfsplus ramdisk.raw chmod 755 usr/lib/libimg4.dylib
    fi
    sleep 4
    echo "Packing patched Ramdisk as im4p"
    ./bin/img4 -i ramdisk.raw -o ramdisk.im4p -T rdsk -A
    mv ramdisk.im4p $savedir/ramdisk.im4p
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
    rm -rf "tmp1" 
    if [[ "$IOS_VERSION" == 10.* || "$IOS_VERSION" == 11.0* || "$IOS_VERSION" == 11.1* || "$IOS_VERSION" == 11.2* ]]; then
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
    if [[ "$IOS_VERSION" == 10.* ]]; then
        ./bin/hfsplus ramdisk.raw chmod 100755 usr/sbin/asr
    else
        ./bin/hfsplus ramdisk.raw chmod 755 usr/sbin/asr 
    fi
    # restored_external in update ramdisk is restored_update
    if [[ $IDENTIFIER == iPhone10,3 || $IDENTIFIER == iPhone10,6 ]]; then
        echo "patching restored_update, do ipx patches"
        ./bin/hfsplus ramdisk.raw extract usr/local/bin/restored_update 
        ./bin/ipx_restored_patcher restored_update patched_restored_external
        ./bin/ldid -e restored_update > ents.plist
        ./bin/ldid -Sents.plist patched_restored_external
        echo "replacing restored_update with patched restored_update"
        ./bin/hfsplus ramdisk.raw rm usr/local/bin/restored_update
        sleep 4 
        ./bin/hfsplus ramdisk.raw add patched_restored_external usr/local/bin/restored_update
        sleep 4
        ./bin/hfsplus ramdisk.raw chmod 755 usr/local/bin/restored_update
    fi
    if [[ $IOS_VERSION == 14.* || $IOS_VERSION == 15.* || $IOS_VERSION == 16.* ]]; then
        # do libimg4 validation patch
        echo "Doing validation patch so sealing system volume works"
        sudo ./bin/hfsplus ramdisk.raw extract usr/lib/libimg4.dylib
        ./bin/libimg4_patcher libimg4.dylib libimg4.patched
        ./bin/ldid -Sents.plist libimg4.patched
        sudo ./bin/hfsplus ramdisk.raw rm usr/lib/libimg4.dylib
        sudo ./bin/hfsplus ramdisk.raw add libimg4.patched usr/lib/libimg4.dylib
        sudo ./bin/hfsplus ramdisk.raw chmod 755 usr/lib/libimg4.dylib
    fi
    sleep 4
    echo "Packing patched Ramdisk as im4p"
    ./bin/img4 -i ramdisk.raw -o ramdisk.im4p -T rdsk -A
    mv ramdisk.im4p $savedir/updateramdisk.im4p
    rm -rf asr
    rm -rf restored_update
    rm -rf patched_external
    rm -rf patched_restored_external
    rm -rf patched_asr
    rm -rf ents.plist
    rm -rf ramdisk.raw
    echo "Custom IPSW + patched restore chain has been made! Use --restore $IOS_VERSION to downgrade to the designated firmware"
    exit 1
}

main() {
    bootstrap_environment
    init_runtime_context
    cmd_make_custom_ipsw "$@"
}

main "$@"
