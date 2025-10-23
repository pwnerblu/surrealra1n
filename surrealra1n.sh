#!/bin/bash

echo "surrealra1n - v1.2 beta"
echo "Tether Downgrader for iPhone 5S - iOS 10.1 - 12.5.6"
echo ""
echo "Uses latest SHSH blobs (for tethered downgrades)"
echo "All restores will use the latest baseband firmware, except for iOS 10.x downgrades on A7. On certain A7 devices, iOS 10.3.3 SEP will be used to do an OTA downgrade to 10.3.3"
echo "No, you do not need to have Python installed"
echo "zoe-vb fork of asr64_patcher is used for patching ASR"
echo "iPh0ne4s fork of SSHRD_Script is used to back up and restore activation tickets for iOS 11.0 - 11.2.6 restores on iPhone 5S"

# Request sudo password upfront
echo "Enter your user password when prompted to"
sudo -v || exit 1

# Dependency check
echo "Checking for required dependencies..."

DEPENDENCIES=(libusb-1.0-0-dev libusbmuxd-tools libimobiledevice-utils usbmuxd libimobiledevice6 zenity git)
MISSING_PACKAGES=()

for pkg in "${DEPENDENCIES[@]}"; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        MISSING_PACKAGES+=("$pkg")
    fi
done

if [ ${#MISSING_PACKAGES[@]} -ne 0 ]; then
    echo "Missing packages detected: ${MISSING_PACKAGES[*]}"
    echo "Installing missing dependencies..."
    sudo apt update
    sudo apt install -y "${MISSING_PACKAGES[@]}"
else
    echo "All dependencies are installed." 
fi

echo "Checking if SSHRD_Script exists..."

if [[ -f "./SSHRD_Script/sshrd.sh" ]]; then
    echo "SSHRD_Script is installed."
else
    echo ""
    git clone https://github.com/iPh0ne4s/SSHRD_Script --recursive
fi

echo "Checking for existing binaries..."

#!/bin/bash

# Check if all required binaries exist
if [[ -f "./bin/img4" && \
      -f "./bin/img4tool" && \
      -f "./bin/irecovery" && \
      -f "./bin/kairos" && \
      -f "./bin/kerneldiff" && \
      -f "./bin/KPlooshFinder" && \
      -f "./bin/gaster" && \
      -f "./bin/iBoot64Patcher" && \
      -f "./bin/asr64_patcher" && \
      -f "./bin/hfsplus" && \
      -f "./bin/tsschecker" && \
      -f "./bin/ldid" && \
      -f "./futurerestore/futurerestore" ]]; then
    echo "Found necessary binaries."
else
    echo "Binaries do not exist"
    echo "Downloading binaries..."

    mkdir -p bin futurerestore

    curl -L -o bin/img4 https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/img4
    curl -L -o bin/img4tool https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/img4tool
    curl -L -o bin/KPlooshFinder https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/KPlooshFinder
    curl -L -o bin/kerneldiff https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/kerneldiff
    curl -L -o bin/irecovery https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/irecovery
    curl -L -o bin/iBoot64Patcher https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/iBoot64Patcher
    curl -L -o bin/hfsplus https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/hfsplus
    curl -L -o bin/asr64_patcher https://github.com/zoe-vb/asr64_patcher_linux/releases/download/linux/asr64_patcher
    curl -L -o bin/gaster https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/linux/x86_64/gaster
    curl -L -o bin/tsschecker https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/linux/x86_64/tsschecker
    curl -L -o bin/ldid https://github.com/ProcursusTeam/ldid/releases/download/v2.1.5-procursus7/ldid_linux_x86_64
    curl -L -o bin/kairos https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/kairos
    curl -L -o futurerestore/futurerestore.zip https://github.com/LukeeGD/futurerestore/releases/download/latest/futurerestore-Linux-x86_64-RELEASE-main.zip

    chmod +x bin/*

    cd futurerestore || exit
    unzip -o futurerestore.zip
    tar -xf futurerestore-Linux-x86_64-v2.0.0-Build_326-RELEASE.tar.xz
    cp futurerestore-Linux-x86_64-v2.0.0-Build_326-RELEASE/* .
    chmod +x linux_fix.sh
    sudo ./linux_fix.sh
    rm -rf linux_fix.sh
    chmod +x futurerestore
    rm -rf *.tar.xz
    rm -rf *.sh
    rm -rf *.zip
    rm -rf "futurerestore-Linux-x86_64-v2.0.0-Build_326-RELEASE" 
    cd ..
fi


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
    BASEBAND10="Mav7Mav8-7.60.00.Release.bbfw"
    IBOOT="iBoot.iphone6.RELEASE.im4p"
    IBSS="iBSS.iphone6.RELEASE.im4p"
    IBEC="iBEC.iphone6.RELEASE.im4p"
fi

if [[ $IDENTIFIER == iPhone6* || $IDENTIFIER == iPhone7* ]]; then
    LATEST_VERSION="12.5.7"
    DOWNGRADE_RANGE="11.3 to 12.5.6 - 10.1 - 10.3.3 also for some A7 devices"
else
    echo "Unsupported device, press any key to continue if you are going to do an untethered downgrade with saved SHSH (use --downgrade [IPSW FILE] [SHSH BLOB])"
    read -p ""
fi

if [[ $IDENTIFIER == iPhone7* ]]; then
    echo "Firmware key list is not complete, you cannot boot a tethered downgrade at this time for this device"
    read -p "Press any key to continue, if you are going to do an untethered downgrade instead with shsh blobs."
fi

if [[ $IDENTIFIER == iPhone6,1 ]]; then
    SEP="sep-firmware.n51.RELEASE.im4p"
    IBSS10="iBSS.n51.RELEASE.im4p"
    IBEC10="iBEC.n51.RELEASE.im4p"
    IBOOT10="iBoot.n51.RELEASE.im4p"
    LLB10="LLB.n51.RELEASE.im4p"
    ALLFLASH="all_flash.n51ap.production"
    KERNELCACHE10="kernelcache.release.n51"
    DEVICETREE="DeviceTree.n51ap.im4p"
    sudo rm -rf "tmpmanifest"
    mkdir -p tmpmanifest
    cd tmpmanifest
    curl -L -o Manifest.plist https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/resources/manifest/BuildManifest_iPhone6,1_10.3.3.plist
    cd ..
fi

if [[ $IDENTIFIER == iPhone6,2 ]]; then
    SEP="sep-firmware.n53.RELEASE.im4p"
    IBOOT10="iBoot.n53.RELEASE.im4p"
    LLB10="LLB.n53.RELEASE.im4p"
    ALLFLASH="all_flash.n53ap.production"
    KERNELCACHE10="kernelcache.release.n53"
    IBSS10="iBSS.n53.RELEASE.im4p"
    IBEC10="iBEC.n53.RELEASE.im4p"
    DEVICETREE="DeviceTree.n53ap.im4p"
    sudo rm -rf "tmpmanifest"
    mkdir -p tmpmanifest
    cd tmpmanifest
    curl -L -o Manifest.plist https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/resources/manifest/BuildManifest_iPhone6,2_10.3.3.plist
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
        - PUT YOUR DEVICE INTO DFU MODE before proceeding

  --ota-downgrade [IPSW FILE]
        Restore the device to iOS 10.3.3 without saved blobs
        - For certain A7 devices that still have iOS 10.3.3 signed via OTA
        - PUT YOUR DEVICE INTO DFU MODE before proceeding

  --downgrade [IPSW FILE] [SHSH BLOB]
        Downgrade a device with SHSH blobs.
        - NOTE: the shsh blob must be for the iOS version you're downgrading to! 
        - if you dont have shsh blobs for the version you want to downgrade to, please make a custom ipsw and use the restore flag instead to do a tethered downgrade.

  --boot [iOS_VERSION]
        Perform a tethered boot of the specified iOS version.
        - You must be on that iOS version already.
        - PUT YOUR DEVICE INTO DFU MODE before proceeding
   
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
        if [[ "$IDENTIFIER" == iPhone6* ]] && [[ "$IOS_VERSION" == 10.0* || "$IOS_VERSION" == 9.* || "$IOS_VERSION" == 8.* || "$IOS_VERSION" == 7.* ]]; then
            echo "[!] SEP is incompatible"
            echo "[!] You cannot restore to this version or make a custom IPSW for it"
            echo "[!] On this device, you can use --ota-downgrade flag to restore to iOS 10.3.3 without saved blobs"
            exit 1
        fi
        if [[ "$IDENTIFIER" == iPhone6* ]] && [[ "$IOS_VERSION" == 11.2* || "$IOS_VERSION" == 11.1* || "$IOS_VERSION" == 11.0* ]]; then
            echo "[!] SEP is partially compatible"
            echo "[!] Restoring to iOS $IOS_VERSION will use iOS 10.3.3 SEP (because iOS 12 SEP is fully incompatible with 11.2.6 and below)"
            echo "[!] The following issues will occur after the restore: Activation issues, Touch ID not working, unable to connect to password-protected Wi-Fi networks, etc. Device passcode may work though."
            echo "[!] This is ONLY recommended for advanced users, saving activation tickets with an SSH ramdisk is required before restoring to this version"
            echo "[!] PLEASE. PLEASE! DO NOT use this to bypass iCloud, only save activation tickets on a device you legally own"
            read -p "Press any key to continue"
        fi
        if [[ "$IDENTIFIER" == iPhone7* ]] && [[ "$IOS_VERSION" == 11.2* || "$IOS_VERSION" == 11.1* || "$IOS_VERSION" == 11.0* || "$IOS_VERSION" == 10.* || "$IOS_VERSION" == 9.* || "$IOS_VERSION" == 8.* ]]; then
            echo "[!] SEP is incompatible"
            echo "[!] You cannot restore to this version or make a custom IPSW for it"
            exit 1
        fi

        if [[ "$IDENTIFIER" == iPhone6* ]] && [[ "$IOS_VERSION" == 10.3.3 ]]; then
            echo "[!] iOS 10.3.3 can be restored untethered via OTA downgrade"
            echo "[!] It is recommended to use --ota-downgrade [iOS 10.3.3 ipsw] to OTA downgrade to 10.3.3"
            read -p "Press any key to continue with iOS 10.3.3 tethered downgrade"
        fi


        echo "[*] Making custom IPSW..."
        savedir="restorefiles/$IDENTIFIER/$IOS_VERSION"
        mkdir -p "$savedir"
        echo ""
        unzip "$TARGET_IPSW" -d tmp1
        unzip "$BASE_IPSW" -d tmp2
        if [[ "$IOS_VERSION" == 10.1* || "$IOS_VERSION" == 10.2* ]]; then
            echo "iOS 10.3 iBSS and iBEC will be used."
            IPSW_PATH=$(zenity --file-selection --title="Select the iOS 10.3 IPSW file (for iBSS and iBEC)" --file-filter="*.ipsw")
            rm -rf tmp1/Firmware/dfu/$IBSS10
            rm -rf tmp1/Firmware/dfu/$IBEC10
            unzip -j "$IPSW_PATH" "Firmware/dfu/$IBSS" -d tmp1/Firmware/dfu
            unzip -j "$IPSW_PATH" "Firmware/dfu/$IBEC" -d tmp1/Firmware/dfu
            mv tmp1/Firmware/dfu/$IBSS tmp1/Firmware/dfu/$IBSS10
            mv tmp1/Firmware/dfu/$IBEC tmp1/Firmware/dfu/$IBEC10
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
            find tmp1/Firmware/all_flash/ -type f ! -name '*DeviceTree*' -exec rm -f {} +
            find tmp2/Firmware/all_flash/ -type f ! -name '*DeviceTree*' -exec cp {} tmp1/Firmware/all_flash/ \;
        fi
        cd tmp1
        zip -0 -r ../custom.ipsw *
        cd ..
        mv custom.ipsw "$savedir/custom.ipsw"
        rm -rf "tmp2"
        
        # Find smallest .dmg in tmp1 and copy to work/RestoreRamdisk.orig
        smallest_dmg=$(find tmp1 -type f -name '*.dmg' ! -name '._*' -printf '%s %p\n' | sort -n | head -n 1 | cut -d' ' -f2-)
        mkdir -p work
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
        ../bin/img4 -i kernel.orig -o kernel.im4p -T rkrn -P kernel.bpatch -J
        mv kernel.im4p ../$savedir/kernel.im4p
        # build ramdisk
        cd ..
        sudo ./bin/img4 -i "$smallest_dmg" -o ramdisk.raw
        rm -rf "tmp1" 
        if [[ "$IDENTIFIER" == iPhone6,* ]] && [[ "$IOS_VERSION" == 10.* || "$IOS_VERSION" == 11.0* || "$IOS_VERSION" == 11.1* || "$IOS_VERSION" == 11.2* ]]; then
            echo "growing ramdisk"
            sudo ./bin/hfsplus ramdisk.raw grow 60000000
        else
            echo "skipping ramdisk grow"
        fi
        echo "extracting asr to patch"
        sudo ./bin/hfsplus ramdisk.raw extract usr/sbin/asr 
        echo "patching asr"
        sudo ./bin/asr64_patcher asr patched_asr
        sudo ./bin/ldid -e asr > ents.plist
        sudo ./bin/ldid -Sents.plist patched_asr
        echo "replacing asr with patched asr"
        sudo ./bin/hfsplus ramdisk.raw rm usr/sbin/asr
        sleep 4
        sudo ./bin/hfsplus ramdisk.raw add patched_asr usr/sbin/asr
        sleep 4
        if [[ "$IDENTIFIER" == iPhone6,* ]] && [[ "$IOS_VERSION" == 10.* ]]; then
            sudo ./bin/hfsplus ramdisk.raw chmod 100755 usr/sbin/asr
        else
            sudo ./bin/hfsplus ramdisk.raw chmod 755 usr/sbin/asr 
        fi
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
        restoredir="restorefiles/$IDENTIFIER/$IOS_VERSION"
        echo "first, your device needs to be in pwndfu mode. pwning with gaster"
        echo "[!] Linux has low success rate for the checkm8 exploit on A6-A7. If possible, you should connect your device to a Mac or iOS device and pwn with ipwnder"
        read -p "[!] Do you want to continue pwning with gaster? (LOW SUCCESS RATE) y/n " response
        if [[ $response == y ]]; then
            ./bin/gaster pwn
        else
            echo "Now, disconnect your device and connect it to a Mac or iOS device to pwn with ipwnder."
            echo "For more information about pwning with an iOS device, go to <https://github.com/LukeZGD/Legacy-iOS-Kit/wiki/Pwning-Using-Another-iOS-Device>"
            read -p "Press any key after the device is pwned with ipwnder and reconnected to this computer"
        fi
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
        if [[ $IDENTIFIER == iPhone6* ]] && [[ $IOS_VERSION == 11.0* || $IOS_VERSION == 11.1* || $IOS_VERSION == 11.2* ]]; then
            echo "since this restore requires the iOS 10 SEP to restore successfully, and we are restoring iOS 11.0 - 11.2.6, we need to save activation records so we can activate (because of SEP compatibility problems we cannot activate normally)"
            echo "iPh0ne4s fork of SSHRD_Script will be used"
            sleep 4
            ./bin/gaster pwn
            ./bin/gaster reset
            cd SSHRD_Script
            sudo ./sshrd.sh 12.0
            read -p "Was there an error while making the ramdisk? (y/n) " error_response
            if [[ $error_response == y ]]; then
                sudo ./sshrd.sh 12.0
            else
                echo ""
            fi
            sudo ./sshrd.sh boot
            sleep 10
            sudo ./sshrd.sh --backup-activation
            sudo ./sshrd.sh reboot
            cd ..
            read -p "Press any key after you have placed your device into DFU mode"
            ./bin/gaster pwn
            ./bin/gaster reset
        fi
        echo "running futurerestore"
        if [[ "$IDENTIFIER" == iPhone6,* ]] && [[ "$IOS_VERSION" == 10.* || "$IOS_VERSION" == 11.0* || "$IOS_VERSION" == 11.1* || "$IOS_VERSION" == 11.2* ]]; then
            echo "iOS 10 sep will be used"
            IPSW_PATH=$(zenity --file-selection --title="Select the iOS 10.3.3 IPSW file (for SEP firmware)" --file-filter="*.ipsw")
            mkdir tmp
            mkdir tmp/Firmware
            mkdir tmp/Firmware/all_flash
            unzip -j "$IPSW_PATH" "Firmware/all_flash/$SEP" -d tmp/Firmware/all_flash
            unzip -j "$IPSW_PATH" "Firmware/$BASEBAND10" -d tmp/Firmware
            SEP_PATH="tmp/Firmware/all_flash/$SEP"
            BASEBAND_PATH="tmp/Firmware/$BASEBAND10"
            if [[ $IOS_VERSION == 11.0* || $IOS_VERSION == 11.1* || $IOS_VERSION == 11.2* ]]; then
                sudo FUTURERESTORE_I_SOLEMNLY_SWEAR_THAT_I_AM_UP_TO_NO_GOOD=1 ./futurerestore/futurerestore -t $shshpath --skip-blob --use-pwndfu --rdsk $restoredir/ramdisk.im4p --rkrn $restoredir/kernel.im4p --no-cache --latest-baseband --sep "$SEP_PATH" --sep-manifest "$mnifst" --no-rsep $restoredir/custom.ipsw
                rm -rf "tmp"
                echo "Restore has finished! Read above if there's any errors"
                echo "YOU WILL FACE A LOT OF ISSUES REGARDING STUFF THAT REQUIRES SEP TO FULLY WORK"
                exit 1
            fi
            sudo FUTURERESTORE_I_SOLEMNLY_SWEAR_THAT_I_AM_UP_TO_NO_GOOD=1 ./futurerestore/futurerestore -t $shshpath --skip-blob --use-pwndfu --rdsk $restoredir/ramdisk.im4p --rkrn $restoredir/kernel.im4p --no-cache --baseband "$BASEBAND_PATH" --baseband-manifest "$mnifst" --sep "$SEP_PATH" --sep-manifest "$mnifst" --no-rsep $restoredir/custom.ipsw
            rm -rf "tmp"
            echo "Restore has finished! Read above if there's any errors"
            exit 1
        else
            sudo ./futurerestore/futurerestore -t $shshpath --skip-blob --use-pwndfu --no-cache --rdsk $restoredir/ramdisk.im4p --rkrn $restoredir/kernel.im4p --latest-baseband --latest-sep --no-rsep $restoredir/custom.ipsw
        fi
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
        echo "[!] Linux has low success rate for the checkm8 exploit on A6-A7. If possible, you should connect your device to a Mac or iOS device and pwn with ipwnder"
        read -p "[!] Do you want to continue pwning with gaster? (LOW SUCCESS RATE) y/n " response
        if [[ $response == y ]]; then
            ./bin/gaster pwn
        else
            echo "Now, disconnect your device and connect it to a Mac or iOS device to pwn with ipwnder."
            echo "For more information about pwning with an iOS device, go to <https://github.com/LukeZGD/Legacy-iOS-Kit/wiki/Pwning-Using-Another-iOS-Device>"
            read -p "Press any key after the device is pwned with ipwnder and reconnected to this computer"
        fi
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
        mkdir tmp
        mkdir tmp/Firmware
        mkdir tmp/Firmware/all_flash
        unzip -j "$IPSW" "Firmware/all_flash/$SEP" -d tmp/Firmware/all_flash
        unzip -j "$IPSW" "Firmware/$BASEBAND10" -d tmp/Firmware
        BASEBAND_PATH="tmp/Firmware/$BASEBAND10"
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
        sudo FUTURERESTORE_I_SOLEMNLY_SWEAR_THAT_I_AM_UP_TO_NO_GOOD=1 ./futurerestore/futurerestore -t $shshpath --use-pwndfu --no-cache --baseband "$BASEBAND_PATH" --baseband-manifest "$mnifst" --sep "$SEP_PATH" --sep-manifest "$mnifst" --no-rsep $IPSW
        echo "Restore has finished! Read above if there's any errors"
        echo "Removing tmp folder"
        sudo rm -rf "tmp"
        exit 1
        ;;

    --downgrade)
        if [[ $# -ne 3 ]]; then
            echo "[!] Usage: --downgrade [IPSW FILE] [SHSH BLOB]"
            exit 1
        fi
        IPSW="$2"
        SHSHBLOB="$3"
        read -p "What is the iOS version you are downgrading to: " vers
        if [[ $vers == 10.2* || $vers == 10.1* ]]; then
            echo "[!] Unsupported currently"
            exit 1
        fi
        echo "[*] Restoring to iOS $vers..."
        echo "first, your device needs to be in pwndfu mode. pwning with gaster"
        echo "[!] Linux has low success rate for the checkm8 exploit on A6-A7. If possible, you should connect your device to a Mac or iOS device and pwn with ipwnder"
        read -p "[!] Do you want to continue pwning with gaster? (LOW SUCCESS RATE) y/n " response
        if [[ $response == y ]]; then
            ./bin/gaster pwn
        else
            echo "Now, disconnect your device and connect it to a Mac or iOS device to pwn with ipwnder."
            echo "For more information about pwning with an iOS device, go to <https://github.com/LukeZGD/Legacy-iOS-Kit/wiki/Pwning-Using-Another-iOS-Device>"
            read -p "Press any key after the device is pwned with ipwnder and reconnected to this computer"
        fi
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

        echo "[*] Using SHSH blob: $SHSHBLOB"
        echo "running futurerestore"
        if [[ $vers == 11.3* || $vers == 11.4* || $vers == 12.* || $vers == 13.* || $vers == 14.* || $vers == 15.* || $vers == 16.* ]]; then
           echo "Using latest SEP and baseband!"
           sudo ./futurerestore/futurerestore -t $SHSHBLOB --use-pwndfu --latest-baseband --latest-sep --no-rsep $IPSW
        elif [[ $IDENTIFIER == iPhone6* ]] && [[ $vers == 10.1* || $vers == 10.2* || $vers == 10.3* ]]; then
           echo "iOS 10 SEP needs to be used"
           IPSW_PATH=$(zenity --file-selection --title="Select the iOS 10.3.3 IPSW file (for SEP firmware)" --file-filter="*.ipsw")
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
        ;;

    --boot)
        if [[ $# -ne 2 ]]; then
            echo "[!] Usage: --boot [iOS_VERSION]"
            exit 1
        fi
        IOS_VERSION="$2"
        echo "[*] Tethered boot of iOS $IOS_VERSION..."
        echo "[!] Note: Kernel patches are applied for restoring only usually"
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
            IPSW_PATH=$(zenity --file-selection --title="Select the iOS $IOS_VERSION IPSW file" --file-filter="*.ipsw")
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
            if [[ "$IOS_VERSION" == 12.* ]]; then
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
            if [[ "$IOS_VERSION" == 10.2* || "$IOS_VERSION" == 10.1* ]]; then
                ./bin/kairos to_patch/iBSS.dec to_patch/iBSS.patched
            else
                ./bin/iBoot64Patcher to_patch/iBSS.dec to_patch/iBSS.patched
            fi
            if [[ "$IOS_VERSION" == 10.* ]]; then
                echo "Using kairos to patch iBEC instead of iBoot64Patcher"
                ./bin/kairos to_patch/iBEC.dec to_patch/iBEC.patched -n -b "-v debug=0x09" -c "go" 0x830000300
            else
                ./bin/iBoot64Patcher to_patch/iBEC.dec to_patch/iBEC.patched -b "rd=disk0s1s1 -v"
            fi
            ./bin/img4 -i to_patch/DeviceTree.im4p -o $BOOT_DIR/DeviceTree.img4 -M "$im4m" -T rdtr
            ./bin/img4 -i to_patch/kernelcache -o $BOOT_DIR/Kernelcache.img4 -M "$im4m" -T rkrn
            ./bin/img4 -i to_patch/iBSS.patched -o $BOOT_DIR/iBSS.img4 -M "$im4m" -A -T ibss
            ./bin/img4 -i to_patch/iBEC.patched -o $BOOT_DIR/iBEC.img4 -M "$im4m" -A -T ibec
            if [[ "$IOS_VERSION" == 12.* ]]; then
                ./bin/img4 -i to_patch/trustcache -o $BOOT_DIR/Trustcache.img4 -M "$im4m" -T rtsc
            fi
            rm -rf "to_patch"
        else
            echo "[*] Existing boot files found in $BOOT_DIR"
        fi

        # Placeholder for tethered boot command
        echo "[*] Proceeding to tethered boot..."
        echo "first, your device needs to be in pwndfu mode. pwning with gaster"
        echo "[!] Linux has low success rate for the checkm8 exploit on A6-A7. If possible, you should connect your device to a Mac or iOS device and pwn with ipwnder"
        read -p "[!] Do you want to continue pwning with gaster? (LOW SUCCESS RATE) y/n " response
        if [[ $response == y ]]; then
            ./bin/gaster pwn
        else
            echo "Now, disconnect your device and connect it to a Mac or iOS device to pwn with ipwnder."
            echo "For more information about pwning with an iOS device, go to <https://github.com/LukeZGD/Legacy-iOS-Kit/wiki/Pwning-Using-Another-iOS-Device>"
            read -p "Press any key after the device is pwned with ipwnder and reconnected to this computer"
        fi
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
        if [[ $IDENTIFIER == iPhone9* || $IDENTIFIER == iPhone10* ]]; then
            ./bin/irecovery -c go
            sleep 6
        fi
        ./bin/irecovery -f "$BOOT_DIR/DeviceTree.img4"
        ./bin/irecovery -c devicetree
        if [[ "$IOS_VERSION" == 12.* ]]; then
          ./bin/irecovery -f "$BOOT_DIR/Trustcache.img4"
          ./bin/irecovery -c firmware
        fi
        ./bin/irecovery -f "$BOOT_DIR/Kernelcache.img4"
        ./bin/irecovery -c bootx
        echo "Your device should now boot."
        if [[ $IDENTIFIER == iPhone6* ]] && [[ $IOS_VERSION == 11.0* || $IOS_VERSION == 11.1* || $IOS_VERSION == 11.2* ]]; then
            echo "If it's your first boot after downgrading, wait for the Hello screen, then proceed with the next step"
            read -p "Is this your first time booting? (y/n): " bootresponse
            if [[ $bootresponse == y ]]; then
                read -p "Press any key after your device is in DFU mode, we will need to inject activation"
                sleep 4
                ./bin/gaster pwn
                ./bin/gaster reset
                cd SSHRD_Script
                sudo ./sshrd.sh 11.0
                read -p "Was there an error while making the ramdisk? (y/n) " error_response
                if [[ $error_response == y ]]; then
                    sudo ./sshrd.sh 11.0
                else
                    echo ""
                fi
                sudo ./sshrd.sh boot
                sleep 10
                sudo ./sshrd.sh --restore-activation
                sudo ./sshrd.sh reboot
                cd ..
                echo "activation records have been restored! now run ./surrealra1n.sh --boot $IOS_VERSION to boot"
                exit 1
            fi
        fi
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
