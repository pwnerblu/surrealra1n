#!/bin/bash

echo "surrealra1n"
echo "Tether Downgrader for iPhone 5S - iOS 11.3 - 12.5.6"
echo ""
echo "Uses latest SHSH blobs (for tethered downgrades)"
echo "All restores will use the latest baseband firmware. On certain A7 devices, iOS 10.3.3 SEP will be used to do an OTA downgrade to 10.3.3"

# Run ideviceinfo and capture both output and return code
IDEVICE_INFO=$(ideviceinfo 2>&1)
IDEVICE_STATUS=$?

if [[ $IDEVICE_STATUS -eq 0 && "$IDEVICE_INFO" != *"No device found!"* ]]; then
    echo "[*] Device is in normal mode."

    # Extract ProductType and UniqueChipID
    IDENTIFIER=$(echo "$IDEVICE_INFO" | grep "^ProductType:" | cut -d ':' -f2 | xargs)
    ECID=$(echo "$IDEVICE_INFO" | grep "^UniqueChipID:" | cut -d ':' -f2 | xargs)

    echo "[+] Device Identifier: $IDENTIFIER"
    echo "[+] ECID: $ECID"

else
    echo "[*] Device is not in normal mode. Trying recovery/DFU mode..."

    # Try irecovery
    IRECOVERY_INFO=$(./bin/irecovery -q 2>/dev/null)

    if [[ -n "$IRECOVERY_INFO" ]]; then
        echo "[*] Device is in Recovery or DFU mode."

        # Extract PRODUCT and ECID
        IDENTIFIER=$(echo "$IRECOVERY_INFO" | grep "^PRODUCT:" | cut -d ':' -f2 | xargs)
        ECID=$(echo "$IRECOVERY_INFO" | grep "^ECID:" | cut -d ':' -f2 | xargs)

        echo "[+] Device Identifier: $IDENTIFIER"
        echo "[+] ECID: $ECID"

    else
        echo "[!] No device detected in normal or recovery mode."
        exit 1
    fi
fi

if [[ $IDENTIFIER == iPhone6* ]]; then
    KERNELCACHE="kernelcache.release.iphone6"
    LLB="LLB.iphone6.RELEASE.im4p"
    IBOOT="iBoot.iphone6.RELEASE.im4p"
fi

if [[ $IDENTIFIER == iPhone8* ]]; then
    KERNELCACHE="kernelcache.release.n71"
    LLB="LLB.n71.RELEASE.im4p"
    IBOOT="iBoot.n71.RELEASE.im4p"
fi

if [[ $IDENTIFIER == iPhone9* ]]; then
    KERNELCACHE="kernelcache.release.iphone9"
    LLB="LLB.d10.RELEASE.im4p"
    IBOOT="iBoot.d10.RELEASE.im4p"
fi

if [[ $IDENTIFIER == iPhone6* || $IDENTIFIER == iPhone7* ]]; then
    LATEST_VERSION="12.5.7"
    DOWNGRADE_RANGE="11.3 to 12.5.6"
fi

if [[ $IDENTIFIER == iPhone8* || $IDENTIFIER == iPhone9* ]]; then
    LATEST_VERSION="15.8.5"
    DOWNGRADE_RANGE="13.7 to 15.8.4"
fi

if [[ $IDENTIFIER == iPhone10* ]]; then
    LATEST_VERSION="16.7.12"
    DOWNGRADE_RANGE="14.3 to 15.6.1"
fi

if [[ $IDENTIFIER == iPhone6,1 ]]; then
    SEP="sep-firmware.n51.RELEASE.im4p"
    sudo rm -rf "tmpmanifest"
    mkdir -p tmpmanifest
    cd tmpmanifest
    curl -L -o Manifest.plist https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/resources/manifest/BuildManifest_iPhone6,1_10.3.3.plist
    cd ..
fi

mnifst="tmpmanifest/Manifest.plist"

echo "Using:"
echo "Kernelcache: $KERNELCACHE"
echo "LLB for restore: $LLB"
echo "iBoot for restore: $IBOOT"
if [[ $IDENTIFIER == iPhone6* ]]; then
   echo "SEP for iOS 10.x downgrades: $SEP"
fi

#!/bin/bash

function usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --make-custom-ipsw [TARGET_IPSW_PATH] [BASE_IPSW_PATH] [iOS_VERSION]
        Create a custom IPSW for tethered restore.
        - TARGET_IPSW_PATH: Path for the stock IPSW for target version
        - BASE_IPSW_PATH: Must be iOS $LATEST_VERSION IPSW
        - iOS_VERSION: Target iOS version to restore ($DOWNGRADE_RANGE)

  --restore [iOS_VERSION]
        Restore the device to a previously created custom IPSW.
        - Requires a custom IPSW already built for the specified iOS version.

  --ota-downgrade [IPSW FILE]
        Restore the device to iOS 10.3.3 without saved blobs
        - For certain A7 devices that still have iOS 10.3.3 signed via OTA

  --boot [iOS_VERSION]
        Perform a tethered boot of the specified iOS version.
        - You must be on that iOS version already.

  -h, --help
        Show this help message and exit.

EOF
}

if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

case "$1" in
    --make-custom-ipsw)
        if [[ $# -ne 4 ]]; then
            echo "[!] Usage: --make-custom-ipsw [TARGET_IPSW_PATH] [BASE_IPSW_PATH] [iOS_VERSION]"
            exit 1
        fi
        TARGET_IPSW="$2"
        BASE_IPSW="$3"
        IOS_VERSION="$4"
        if [[ "$IDENTIFIER" == iPhone6* || "$IOS_VERSION" == 11.2* || "$IOS_VERSION" == 11.1* || "$IOS_VERSION" == 11.0* || "$IOS_VERSION" == 10.* || "$IOS_VERSION" == 9.* || "$IOS_VERSION" == 8.* || "$IOS_VERSION" == 7.* ]]; then
            echo "[!] SEP is incompatible"
            echo "[!] You cannot restore to this version or make a custom IPSW for it"
            echo "[!] On this device, you can use --ota-downgrade flag to restore to iOS 10.3.3 without saved blobs"
            exit 1
        fi
        if [[ "$IDENTIFIER" == iPhone7* || "$IOS_VERSION" == 11.2* || "$IOS_VERSION" == 11.1* || "$IOS_VERSION" == 11.0* || "$IOS_VERSION" == 10.* || "$IOS_VERSION" == 9.* || "$IOS_VERSION" == 8.* ]]; then
            echo "[!] SEP is incompatible"
            echo "[!] You cannot restore to this version or make a custom IPSW for it"
            exit 1
        fi
        if [[ "$IDENTIFIER" == iPhone8* || "$IOS_VERSION" == 13.* ]]; then
            echo "[!] SEP is partially incompatible"
            echo "[!] You can restore to this version, but Touch ID won't work afterwards. It is recommended to use Turdus Merula instead."
            read -p "Press any key to continue"
        fi
        if [[ "$IDENTIFIER" == iPhone9* || "$IOS_VERSION" == 13.* ]]; then
            echo "[!] SEP is partially incompatible"
            echo "[!] You can restore to this version, but Touch ID and home button won't work afterwards. It is recommended to use Turdus Merula instead."
            read -p "Press any key to continue"
        fi
        if [[ "$IDENTIFIER" == iPhone8* || "$IDENTIFIER" == iPhone9* || "$IOS_VERSION" == 12.* || "$IOS_VERSION" == 11.* || "$IOS_VERSION" == 10.* || "$IOS_VERSION" == 9.* ]]; then
            echo "[!] SEP is incompatible"
            echo "[!] You cannot restore to this version or make a custom IPSW for it. You must use Turdus Merula instead."
            exit 1
        fi
        if [[ "$IDENTIFIER" == iPhone10* || "$IOS_VERSION" == 14.2* || "$IOS_VERSION" == 14.1* || "$IOS_VERSION" == 14.0* || "$IOS_VERSION" == 13.* || "$IOS_VERSION" == 12.* || "$IOS_VERSION" == 11.* ]]; then
            echo "[!] SEP & baseband is incompatible"
            echo "[!] You cannot restore to this version or make a custom IPSW for it"
            exit 1
        fi
        if [[ "$IDENTIFIER" == iPhone10* || "$IOS_VERSION" == 14.3* || "$IOS_VERSION" == 14.4* || "$IOS_VERSION" == 14.5* || "$IOS_VERSION" == 14.6* || "$IOS_VERSION" == 14.7* || "$IOS_VERSION" == 14.8* || "$IOS_VERSION" == 15.* ]]; then
            echo "[!] SEP & baseband is partially incompatible"
            echo "[!] YOU MAY FACE ACTIVATION ISSUES, and some things may not work after the restore! you can downgrade untethered to iOS 16.6.x-16.7.x if you have SHSH blobs for those versions instead of 14.3-15.x"
            read -p "Press any key to continue"
        fi
        if [[ "$IDENTIFIER" == iPhone10* || "$IOS_VERSION" == 16.* ]]; then
            echo "[!] You cannot downgrade tethered to iOS 16, but instead you can downgrade untethered to iOS 16.6.x-16.7.x if you have SHSH blobs for that version"
            exit 1
        fi
        if [[ "$IDENTIFIER" == iPhone11* || "$IDENTIFIER" == iPhone12* || "$IDENTIFIER" == iPhone13* || "$IDENTIFIER" == iPhone14* || "$IDENTIFIER" == iPhone15* || "$IDENTIFIER" == iPhone16* || "$IDENTIFIER" == iPhone17* || "$IDENTIFIER" == iPhone18* ]]; then
            echo "[!] This device is not supported"
            exit 1
        fi
        echo "[*] Making custom IPSW..."
        savedir="restorefiles/$IDENTIFIER/$IOS_VERSION"
        mkdir -p "$savedir"
        unzip "$TARGET_IPSW" -d tmp1
        unzip "$BASE_IPSW" -d tmp2
        rm -rf tmp1/Firmware/all_flash/$LLB
        rm -rf tmp1/Firmware/all_flash/$IBOOT
        cp tmp2/Firmware/all_flash/$LLB tmp1/Firmware/all_flash/$LLB
        cp tmp2/Firmware/all_flash/$IBOOT tmp1/Firmware/all_flash/$IBOOT
        cd tmp1
        zip -0 -r ../custom.ipsw *
        cd ..
        mv custom.ipsw "$savedir/custom.ipsw"
        rm -rf "tmp2"
        
        # Find smallest .dmg in tmp1 and copy to work/RestoreRamdisk.orig
        smallest_dmg=$(find tmp1 -type f -name '*.dmg' ! -name '._*' -printf '%s %p\n' | sort -n | head -n 1 | cut -d' ' -f2-)
        mkdir -p work
        cp tmp1/$KERNELCACHE work/kernel.orig      
        cd work
        echo "making patched restore chain"
        ../bin/img4 -i kernel.orig -o kernel.raw
        ../bin/KPlooshFinder kernel.raw kernel.patched
        ../bin/kerneldiff kernel.raw kernel.patched kernel.bpatch
        ../bin/img4 -i kernel.orig -o kernel.im4p -T rkrn -P kernel.bpatch -J
        mv kernel.im4p ../$savedir/kernel.im4p
        # build ramdisk
        cd ..
        sudo ./bin/img4 -i "$smallest_dmg" -o ramdisk.raw
        rm -rf "tmp1" 
        echo "extracting asr to patch"
        sudo ./bin/hfsplus ramdisk.raw extract usr/sbin/asr 
        echo "patching asr"
        sudo ./bin/asr64_patcher asr patched_asr
        sudo ./bin/ldid -e asr > ents.plist
        sudo ./bin/ldid -Sents.plist patched_asr
        fi
        echo "replacing asr with patched asr"
        sudo ./bin/hfsplus ramdisk.raw rm usr/sbin/asr
        sleep 4
        sudo ./bin/hfsplus ramdisk.raw add patched_asr usr/sbin/asr
        sleep 4
        sudo ./bin/hfsplus ramdisk.raw chmod 755 usr/sbin/asr 
        sleep 4
        echo "Packing patched Ramdisk as im4p"
        sudo ./bin/img4 -i ramdisk.raw -o ramdisk.im4p -T rdsk -A
        mv ramdisk.im4p $savedir/ramdisk.im4p
        rm -rf "work"
        rm -rf asr
        rm -rf patched_asr
        rm -rf ents.plist
        rm -rf ramdisk.raw
        echo "Custom IPSW + patched restore chain has been made! Use --restore $IOS_VERSION to downgrade to the designated firmware"
        exit 1
        ;;


    --restore)
        if [[ $# -ne 2 ]]; then
            echo "[!] Usage: --restore [iOS_VERSION]"
            exit 1
        fi
        sudo rm -rf "shsh"
        IOS_VERSION="$2"
        echo "[*] Restoring to iOS $IOS_VERSION..."
        if [[ "$IOS_VERSION" == 10.3* || "$IOS_VERSION" == 10.2* ]]; then
            echo "[!] Latest SEP is not compatible"
            echo "[!] You can downgrade to this version, but it will use 10.3.3 SEP instead of latest SEP"
            IPSW_PATH=$(zenity --file-selection --title="Select the iOS 10.3.3 IPSW file" --file-filter="*.ipsw")

            if [[ -z "$IPSW_PATH" ]]; then
                echo "[!] No IPSW selected. Aborting."
                exit 1
            fi
            read -p "Press any key to continue."
        fi
        if [[ "$IOS_VERSION" == 10.1* ]]; then
            echo "[!] Latest SEP is not compatible"
            echo "[!] iOS 10.3.3 SEP is partially incompatible with iOS 10.1.x, Touch ID may not work."
            IPSW_PATH=$(zenity --file-selection --title="Select the iOS 10.3.3 IPSW file" --file-filter="*.ipsw")

            if [[ -z "$IPSW_PATH" ]]; then
                echo "[!] No IPSW selected. Aborting."
                exit 1
            fi
            read -p "Press any key to continue."
        fi
        restoredir="restorefiles/$IDENTIFIER/$IOS_VERSION"
        echo "first, your device needs to be in pwndfu mode. pwning with gaster"
        ./bin/gaster pwn
        ./bin/gaster reset
        echo "[*] Verifying PWNDFU mode..."
        irecovery_output=$(./bin/irecovery -q)
        if echo "$irecovery_output" | grep -q "PWND"; then
            echo "[*] Device is in PWNDFU mode"
        else
            echo "[!] Device is NOT in PWNDFU mode"
            echo "[!] Aborting restore. Please re-enter DFU and try again."
            exit 1
        fi
        echo "Fetching shsh blobs for iOS $LATEST_VERSION, this is just so it will restore. skip-blob flag is used"
        mkdir -p shsh
        sudo ./bin/tsschecker -d $IDENTIFIER -s -e $ECID -i $LATEST_VERSION --save-path shsh

        # Find the .shsh2 file in the shsh directory
        shshpath=$(find shsh -type f -name "*.shsh2" | head -n 1)
        if [[ -z "$shshpath" ]]; then
            echo "[!] No .shsh2 blob found in shsh folder. Aborting."
            exit 1
        fi

        echo "[*] Using SHSH blob: $shshpath"
        echo "running futurerestore"
        sudo ./futurerestore/futurerestore -t $shshpath --skip-blob --use-pwndfu --rdsk $restoredir/ramdisk.im4p --rkrn $restoredir/kernel.im4p --latest-baseband --latest-sep --no-rsep $restoredir/custom.ipsw
        echo "Restore has finished! Read above if there's any errors"
        exit 1
        ;;
    --ota-downgrade)
        if [[ $# -ne 2 ]]; then
            echo "[!] Usage: --ota-downgrade [IPSW FILE]"
            exit 1
        fi
        sudo rm -rf "shsh"
        IPSW="$2"
        echo "[*] Restoring to iOS 10.3.3..."
        echo "first, your device needs to be in pwndfu mode. pwning with gaster"
        ./bin/gaster pwn
        ./bin/gaster reset
        echo "[*] Verifying PWNDFU mode..."
        irecovery_output=$(./bin/irecovery -q)
        if echo "$irecovery_output" | grep -q "PWND"; then
            echo "[*] Device is in PWNDFU mode"
        else
            echo "[!] Device is NOT in PWNDFU mode"
            echo "[!] Aborting restore. Please re-enter DFU and try again."
            exit 1
        fi
        echo "extracting ipsw"
        unzip $IPSW -d tmp
        SEP_PATH="tmp/Firmware/all_flash/$SEP"
        echo "Fetching shsh blobs for iOS 10.3.3"
        mkdir -p shsh
        sudo ./bin/tsschecker -d $IDENTIFIER -s -e $ECID -i 10.3.3 -o -m "$mnifst" --save-path shsh

        # Find the .shsh2 file in the shsh directory
        shshpath=$(find shsh -type f -name "*.shsh2" | head -n 1)
        if [[ -z "$shshpath" ]]; then
            echo "[!] No .shsh2 blob found in shsh folder. Aborting."
            exit 1
        fi

        echo "[*] Using SHSH blob: $shshpath"
        echo "running futurerestore"
        # required
        sudo FUTURERESTORE_I_SOLEMNLY_SWEAR_THAT_I_AM_UP_TO_NO_GOOD=1 ./futurerestore/futurerestore -t $shshpath --use-pwndfu --latest-baseband --sep "$SEP_PATH" --sep-manifest "$mnifst" --no-rsep $IPSW
        echo "Restore has finished! Read above if there's any errors"
        echo "Removing tmp folder"
        sudo rm -rf "tmp"
        exit 1
        ;;

    --boot)
        if [[ $# -ne 2 ]]; then
            echo "[!] Usage: --boot [iOS_VERSION]"
            exit 1
        fi
        IOS_VERSION="$2"
        echo "[*] Tethered boot of iOS $IOS_VERSION..."
        echo "[!] Note: Kernel patches are applied for restoring only, not normal booting."
        # Find the .shsh2 file in the shsh directory
        shshpath=$(find shsh -type f -name "*.shsh2" | head -n 1)
        if [[ -z "$shshpath" ]]; then
            echo "[!] No .shsh2 blob found in shsh folder. Aborting."
            exit 1
        fi
           

        # Check for boot files
        BOOT_DIR="boot/$IDENTIFIER/$IOS_VERSION"
        if [[ ! -d "$BOOT_DIR" ]]; then
            echo "[*] Boot files not found. Creating new boot files at $BOOT_DIR..."
            mkdir -p "$BOOT_DIR"

            # Read decryption keys
            KEY_FILE="keys/$IDENTIFIER.txt"
            if [[ ! -f "$KEY_FILE" ]]; then
                echo "[!] Key file $KEY_FILE not found. Aborting."
                exit 1
            fi

            # Extract iBSS and iBEC keys
            IBSS_KEY=$(grep "ibss-$IOS_VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)
            IBEC_KEY=$(grep "ibec-$IOS_VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)

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
            ./bin/iBoot64Patcher to_patch/iBSS.dec to_patch/iBSS.patched
            ./bin/img4 -i to_patch/iBSS.patched -o $BOOT_DIR/iBSS.img4 -M "$im4m" -A -T ibss
            ./bin/iBoot64Patcher to_patch/iBEC.dec to_patch/iBEC.patched -b "rd=disk0s1s1 -v"
            ./bin/img4 -i to_patch/iBEC.patched -o $BOOT_DIR/iBEC.img4 -M "$im4m" -A -T ibec
            ./bin/img4 -i to_patch/kernelcache -o $BOOT_DIR/Kernelcache.img4 -M "$im4m" -T rkrn
            ./bin/img4 -i to_patch/DeviceTree.im4p -o $BOOT_DIR/DeviceTree.img4 -M "$im4m" -T rdtr
            rm -rf "to_patch"
        else
            echo "[*] Existing boot files found in $BOOT_DIR"
        fi

        # Placeholder for tethered boot command
        echo "[*] Proceeding to tethered boot..."
        ./bin/gaster pwn
        ./bin/gaster reset
        echo "[*] Verifying PWNDFU mode..."
        irecovery_output=$(./bin/irecovery -q)
        if echo "$irecovery_output" | grep -q "PWND"; then
            echo "[*] Device is in PWNDFU mode"
        else
            echo "[!] Device is NOT in PWNDFU mode"
            echo "[!] You cannot send the bootchain in regular DFU"
            exit 1
        fi
        ./bin/irecovery -f "$BOOT_DIR/iBSS.img4"
        ./bin/irecovery -f "$BOOT_DIR/iBEC.img4"
        ./bin/irecovery -f "$BOOT_DIR/DeviceTree.img4"
        ./bin/irecovery -c devicetree
        ./bin/irecovery -f "$BOOT_DIR/Kernelcache.img4"
        ./bin/irecovery -c bootx
        echo "Your device should now boot."
        exit 1
        ;;

    -h|--help)
        usage
        exit 0
        ;;

    *)
        echo "[!] Unknown option: $1"
        usage
        exit 1
        ;;
esac
