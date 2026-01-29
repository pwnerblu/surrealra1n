#!/bin/bash
CURRENT_VERSION="v1.2 RC 16"

echo "surrealra1n - $CURRENT_VERSION"
echo "Tether Downgrader for some checkm8 64bit devices, iOS 7.0 - 15.8.5"
echo ""
echo "Uses latest SHSH blobs (for tethered downgrades)"
echo "iSuns9 fork of asr64_patcher is used for patching ASR"
echo "Huge thanks to bodyc1m (discord username: cashcart1capone) for iPod touch 6 support, including the Arch Linux port they did."
echo "iPh0ne4s fork of SSHRD_Script is used to back up and restore activation tickets for iOS 11.0 - 11.2.6 restores on iPhone 5S"

# Request sudo password upfront
echo "Enter your user password when prompted to"
sudo -v || exit 1


echo "Please select the Distro you are on:"
echo "1. Ubuntu"
echo "2. Arch"
read -p "Please enter an answer (1-2): " dist 

# Dependency check
echo "Checking for required dependencies..."

if [[ $dist == 1 ]]; then
    DEPENDENCIES=(libusb-1.0-0-dev libusbmuxd-tools libimobiledevice-utils usbmuxd libimobiledevice6 zenity git curl make gcc)
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
elif [[ $dist == 2 ]]; then
    DEPENDENCIES=(libusb libusbmuxd libimobiledevice usbmuxd zenity git curl make gcc base-devel)
    MISSING_PACKAGES=()


    for pkg in "${DEPENDENCIES[@]}"; do
        if ! pacman -Qi "$pkg" &>/dev/null; then
            MISSING_PACKAGES+=("$pkg")
        fi
    done

    if [ ${#MISSING_PACKAGES[@]} -ne 0 ]; then
        echo "Missing packages detected: ${MISSING_PACKAGES[*]}"
        echo "Installing missing dependencies..."
        sudo pacman -Syu --needed "${MISSING_PACKAGES[@]}"
    else
        echo "All dependencies are already installed."
    fi
fi

echo "Checking for updates..."
rm -rf update/latest.txt
curl -L -o update/latest.txt https://github.com/pwnerblu/surrealra1n/raw/refs/heads/development/update/latest.txt
LATEST_VERSION=$(head -n 1 "update/latest.txt" | tr -d '\r\n')
RELEASE_NOTES=$(awk '/^RELEASE NOTES:/{flag=1; next} flag' "update/latest.txt")

if [[ $LATEST_VERSION != $CURRENT_VERSION ]]; then
    echo "A new version of surrealra1n is available: $LATEST_VERSION"
    echo "RELEASE NOTES:"
    echo "$RELEASE_NOTES"
    echo ""
    echo "It is strongly recommended to update to get the latest features + bug fixes."
    read -p "Would you like to update now? (y/n): " update
    if [[ $update == y || $update == Y ]]; then
        mkdir updatefiles
        rm -rf bin
        rm -rf futurerestore
        rm -rf "keys"
        rm -rf "manifest"
        curl -L -o updatefiles/surrealra1n.sh https://github.com/pwnerblu/surrealra1n/raw/refs/heads/development/surrealra1n.sh
        rm -rf surrealra1n.sh
        mv updatefiles/surrealra1n.sh surrealra1n.sh
        chmod +x surrealra1n.sh
        cd updatefiles
        git clone --branch development https://github.com/pwnerblu/surrealra1n --recursive
        mv surrealra1n/keys keys
        mv surrealra1n/manifest manifest
        cd ..
        mv updatefiles/manifest manifest
        mv updatefiles/keys keys
        rm -rf "updatefiles"
        echo "surrealra1n has been updated! Please run the script again"
        exit 1
    else
        echo "You have declined the update."
        echo "Until you update, you will continue to get the update prompt every time you use surrealra1n."
        sleep 4
    fi
else
    echo "surrealra1n is up to date."
    sleep 1
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
      -f "./bin/Kernel64Patcher" && \
      -f "./bin/Kernel64Patcher2" && \
      -f "./bin/dmg" && \
      -f "./bin/iBoot64Patcher" && \
      -f "./bin/asr64_patcher" && \
      -f "./bin/ipx_restored_patcher" && \
      -f "./bin/restored_external64_patcher" && \
      -f "./bin/restoredpatcher" && \
      -f "./bin/hfsplus" && \
      -f "./bin/tsschecker" && \
      -f "./bin/ipatcher" && \
      -f "./bin/dsc64patcher" && \
      -f "./bin/idevicerestore" && \
      -f "./bin/ldid" && \
      -f "./activate.sh" && \
      -f "./backup.sh" && \
      -f "./futurerestore/futurerestore" ]]; then
    echo "Found necessary binaries."
else
    echo "Binaries do not exist"
    echo "Downloading binaries..."

    mkdir -p bin futurerestore

    curl -L -o bin/img4 https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/img4
    curl -L -o bin/img4tool https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/img4tool
    curl -L -o bin/KPlooshFinder https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/KPlooshFinder
    curl -L -o bin/dsc64patcher https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/dsc64patcher
    curl -L -o bin/kerneldiff https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/kerneldiff
    curl -L -o bin/irecovery https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/irecovery
    curl -L -o bin/iBoot64Patcher https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/iBoot64Patcher
    curl -L -o bin/Kernel64Patcher2 https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/Kernel64Patcher
    curl -L -o bin/hfsplus https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/hfsplus
    curl -L -o bin/dmg https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/dmg
    curl -L -o bin/ipatcher https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/ipatcher
    # install additional restored_external patcher (iPhone X only)
    curl -L -o bin/ipx_restored_patcher https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/linux/x86_64/ipx_restored_patcher
    # restored patcher for seprmvr64 A8+ restores, my fork of mineek's restored patcher but repurposed
    curl -L -o main.c https://gist.githubusercontent.com/pwnerblu/d2adc5adee74a679704577ddd64508bf/raw/c8ca1a75847a16e6a1bbc20894750a20d3b33097/main.c
    gcc main.c -o bin/restoredpatcher
    rm -rf main.c
    # install asr patcher for tethered restores
    git clone https://github.com/iSuns9/asr64_patcher --recursive
    cd asr64_patcher
    make
    mv asr64_patcher ../bin/asr64_patcher
    cd ..
    rm -rf "asr64_patcher"
    # install restored_external patcher for tethered restores to iOS 14+
    git clone https://github.com/iSuns9/restored_external64patcher --recursive
    cd restored_external64patcher
    make
    mv restored_external64_patcher ../bin/restored_external64_patcher
    cd ..
    rm -rf "restored_external64patcher"
    # install Kernel64Patcher for tether booting iOS 13+
    curl -L -o bin/Kernel64Patcher https://github.com/edwin170/downr1n/raw/refs/heads/main/binaries/Linux/Kernel64Patcher
    curl -L -o bin/gaster https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/linux/x86_64/gaster
    curl -L -o bin/tsschecker https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/linux/x86_64/tsschecker
    curl -L -o bin/ldid https://github.com/ProcursusTeam/ldid/releases/download/v2.1.5-procursus7/ldid_linux_x86_64
    curl -L -o bin/kairos https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/kairos
    # download activate.sh and backup.sh from hiylx's eclipsera1n, for backing up and restoring iOS 16+ activation files on 14.0-15.7(.2)
    curl -L -o activate.sh https://github.com/hiylx/eclipsera1n/raw/refs/heads/main/activate.sh
    curl -L -o backup.sh https://github.com/hiylx/eclipsera1n/raw/refs/heads/main/backup.sh
    curl -L -o futurerestore/futurerestore.zip https://github.com/LukeeGD/futurerestore/releases/download/latest/futurerestore-Linux-x86_64-RELEASE-main.zip
    # fetch idevicerestore for 7.0-9.3.5 restores 
    curl -L -o bin/idevicerestore https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/linux/x86_64/idevicerestore2
    # libs
    rm -rf "lib"
    mkdir lib
    curl -L -o lib/libcrypto.so.35 https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/linux/x86_64/lib/libcrypto.so.35
    curl -L -o lib/libssl.so.35 https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/linux/x86_64/lib/libssl.so.35
    chmod +x bin/*
    chmod +x *.sh

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
IDEVICE_INFO=$(ideviceinfo -s 2>&1)
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
        echo "[!] You can run in no-device/surrealra1n test mode though, but please don't restore devices in no-device/surrealra1n test mode"
        read -p "Please enter the Identifier you would like to use (example: iPhone10,1): " IDENTIFIER
        IS_IN_TEST="yes"
    fi
fi

if [[ $IS_IN_TEST == yes ]]; then
    echo "[!] surrealra1n is running in no-device/test mode. Please do not restore any devices with this."
    echo "You may test some functionality though other than restoring."
    sleep 4
fi

if [[ $IDENTIFIER == iPhone6* ]]; then
    KERNELCACHE="kernelcache.release.iphone6"
    LLB="LLB.iphone6.RELEASE.im4p"
    BASEBAND10="Mav7Mav8-7.60.00.Release.bbfw"
    IBOOT="iBoot.iphone6.RELEASE.im4p"
    IBSS="iBSS.iphone6.RELEASE.im4p"
    IBEC="iBEC.iphone6.RELEASE.im4p"
fi

if [[ $IDENTIFIER == iPhone10,1 || $IDENTIFIER == iPhone10,4 ]]; then
    IBSS="iBSS.d20.RELEASE.im4p"
    IBEC="iBEC.d20.RELEASE.im4p"
    LLB="LLB.d20.RELEASE.im4p"
    BASEBAND10="Mav7Mav8-7.60.00.Release.bbfw"
    IBOOT="iBoot.d20.RELEASE.im4p"
fi

if [[ $IDENTIFIER == iPhone10,3 || $IDENTIFIER == iPhone10,6 ]]; then
    IBSS="iBSS.d22.RELEASE.im4p"
    IBEC="iBEC.d22.RELEASE.im4p"
fi

if [[ $IDENTIFIER == iPhone10,2 || $IDENTIFIER == iPhone10,5 ]]; then
    IBSS="iBSS.d21.RELEASE.im4p"
    IBEC="iBEC.d21.RELEASE.im4p"
fi

# devicetree determiner, for iPhone 8 and X

if [[ $IDENTIFIER == iPhone10,1 ]]; then
    DEVICETREE="DeviceTree.d20ap.im4p"
fi

if [[ $IDENTIFIER == iPhone10,2 ]]; then
    DEVICETREE="DeviceTree.d21ap.im4p"
fi

if [[ $IDENTIFIER == iPhone10,5 ]]; then
    DEVICETREE="DeviceTree.d211ap.im4p"
fi

if [[ $IDENTIFIER == iPhone10,4 ]]; then
    DEVICETREE="DeviceTree.d201ap.im4p"
fi

if [[ $IDENTIFIER == iPhone10,3 ]]; then
    DEVICETREE="DeviceTree.d22ap.im4p"
fi

if [[ $IDENTIFIER == iPhone10,6 ]]; then
    DEVICETREE="DeviceTree.d221ap.im4p"
fi

# devicetree determiner, for iPad air 2 and mini 4

if [[ $IDENTIFIER == iPad5,1 ]]; then
    DEVICETREE="DeviceTree.j96ap.im4p"
fi

if [[ $IDENTIFIER == iPad5,2 ]]; then
    DEVICETREE="DeviceTree.j97ap.im4p"
fi

if [[ $IDENTIFIER == iPad5,3 ]]; then
    DEVICETREE="DeviceTree.j81ap.im4p"
fi

if [[ $IDENTIFIER == iPad5,4 ]]; then
    DEVICETREE="DeviceTree.j82ap.im4p"
fi

if [[ $IDENTIFIER == iPhone* ]]; then
    USE_BASEBAND="--latest-baseband"
fi 

# iBSS and iBEC specification for iPhone 6, and DeviceTree. finish A8 support

if [[ $IDENTIFIER == iPhone7,2 ]]; then
    IBSS="iBSS.n61.RELEASE.im4p"
    IBEC="iBEC.n61.RELEASE.im4p"
    DEVICETREE="DeviceTree.n61ap.im4p"
fi

# iBSS and iBEC specification for iPhone 6 Plus, and DeviceTree. finish A8 support

if [[ $IDENTIFIER == iPhone7,1 ]]; then
    IBSS="iBSS.n56.RELEASE.im4p"
    IBEC="iBEC.n56.RELEASE.im4p"
    DEVICETREE="DeviceTree.n56ap.im4p"
fi

# important, for iPad air 2 and mini 4 tethered restores
if [[ $IDENTIFIER == iPad5,2 || $IDENTIFIER == iPad5,4 ]]; then
    USE_BASEBAND="--latest-baseband"
fi 

if [[ $IDENTIFIER == iPad5,1 || $IDENTIFIER == iPad5,3 ]]; then
    USE_BASEBAND="--no-baseband"
fi 

if [[ $IDENTIFIER == iPhone6* ]]; then
    LATEST_VERSION="12.5.8"
    DOWNGRADE_RANGE="10.1 to 12.5.7"
    NOSEP_DOWNGRADE="7.0.1 to 9.3.5"
elif [[ $IDENTIFIER == iPhone7* ]]; then
    LATEST_VERSION="12.5.8"
    DOWNGRADE_RANGE="11.3 to 12.5.7"
    NOSEP_DOWNGRADE="8.0 to 9.3.5"
    KERNELCACHE="kernelcache.release.iphone7"
elif [[ $IDENTIFIER == iPhone10,1 || $IDENTIFIER == iPhone10,4 || $IDENTIFIER == iPhone10,2 || $IDENTIFIER == iPhone10,5 ]]; then
    LATEST_VERSION="16.7.12"
    DOWNGRADE_RANGE="14.3 to 15.6.1"
    KERNELCACHE="kernelcache.release.iphone10"
elif [[ $IDENTIFIER == iPhone10,3 || $IDENTIFIER == iPhone10,6 ]]; then
    LATEST_VERSION="16.7.12"
    DOWNGRADE_RANGE="14.3 to 15.6.1"
    KERNELCACHE="kernelcache.release.iphone10b"
elif [[ $IDENTIFIER == iPod7,1 ]]; then
    # ipod touch 6 support, huge thanks to bodyc1m
    LATEST_VERSION="12.5.8"
    DOWNGRADE_RANGE="11.3 to 12.5.7"
    NOSEP_DOWNGRADE="8.4 to 9.3.5"
    KERNELCACHE="kernelcache.release.n102"
    KERNELCACHE10="kernelcache.release.n102"
    IBSS="iBSS.n102.RELEASE.im4p"
    IBEC="iBEC.n102.RELEASE.im4p"
    DEVICETREE="DeviceTree.n102ap.im4p"
    # parser for iOS 8.4-9.3.5 no SEP tethered (ios 7 doesnt exist on that device ik)
    IBSS10="iBSS.n102.RELEASE.im4p"
    IBEC10="iBEC.n102.RELEASE.im4p"
    IBSS7="iBSS.n102ap.RELEASE.im4p"
    IBEC7="iBEC.n102ap.RELEASE.im4p"
    ALLFLASH="all_flash.n102ap.production"
    USE_BASEBAND="--no-baseband"
elif [[ $IDENTIFIER == iPad7,5 ]]; then
    LATEST_VERSION="17.7.10"
    DOWNGRADE_RANGE="13.4 to 15.7"
    KERNELCACHE="kernelcache.release.ipad7b"
    IBSS="iBSS.ipad7b.RELEASE.im4p"
    IBEC="iBEC.ipad7b.RELEASE.im4p"
    DEVICETREE="DeviceTree.j71bap.im4p"
    USE_BASEBAND="--no-baseband"
elif [[ $IDENTIFIER == iPad5,1 || $IDENTIFIER == iPad5,2 ]]; then
    LATEST_VERSION="15.8.6"
    DOWNGRADE_RANGE="13.4 to 15.8.5"
    NOSEP_DOWNGRADE="8.1 to 9.3.5"
    IBSS="iBSS.ipad5.RELEASE.im4p"
    IBEC="iBEC.ipad5.RELEASE.im4p"
    KERNELCACHE="kernelcache.release.ipad5"
elif [[ $IDENTIFIER == iPad5,3 || $IDENTIFIER == iPad5,4 ]]; then
    LATEST_VERSION="15.8.6"
    DOWNGRADE_RANGE="13.4 to 15.8.5"
    NOSEP_DOWNGRADE="8.1 to 9.3.5"
    IBSS="iBSS.ipad5b.RELEASE.im4p"
    IBEC="iBEC.ipad5b.RELEASE.im4p"
    KERNELCACHE="kernelcache.release.ipad5b"
else
    echo "Unsupported device, press any key to continue if you are going to do an untethered downgrade with saved SHSH (use --downgrade [IPSW FILE] [SHSH BLOB])"
    read -p ""
fi

if [[ $IDENTIFIER == iPhone6,1 ]]; then
    SEP="sep-firmware.n51.RELEASE.im4p"
    IBSS10="iBSS.n51.RELEASE.im4p"
    IBEC10="iBEC.n51.RELEASE.im4p"
    IBSS7="iBSS.n51ap.RELEASE.im4p"
    IBEC7="iBEC.n51ap.RELEASE.im4p"
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

  --seprmvr64-ipsw [TARGET_IPSW_PATH] [BASE_IPSW_PATH] [iOS_VERSION]
        Create a custom IPSW for tethered restore, with seprmvr64.
        - TARGET_IPSW_PATH: Path for the stock IPSW for target version
        - BASE_IPSW_PATH: Must be iOS $LATEST_VERSION IPSW
        - iOS_VERSION: Target iOS version to restore ($NOSEP_DOWNGRADE)

  --restore [iOS_VERSION]
        Restore the device to a previously created custom IPSW.
        - You can also choose to tethered update (no data loss, but may only work if going from a lower version to a newer version (13.6 to 15.4.1 for example)
        - Requires a custom IPSW already built for the specified iOS version.
        - Put your device into DFU mode before proceeding.
        
  --fix-ios8
        Fix slide to upgrade, springboard and other issues with 8.0-8.4.1 seprmvr64.
        - Your device MUST be freshly restored and never booted to 8.0-8.4.1 seprmvr64.
        - Put your device into DFU mode before proceeding.

  --seprmvr64-restore [iOS_VERSION]
        Restore the device to a previously created custom IPSW for seprmvr64.
        - Requires a custom IPSW already built for the specified iOS version.
        - Put your device into DFU mode before proceeding.

  --seprmvr64-boot [iOS_VERSION]
        Perform a tethered boot of the specified iOS version with seprmvr64.
        - You must be on that iOS version already.
        - Put your device into DFU mode before proceeding.

  --ota-downgrade [IPSW FILE]
        Restore the device to iOS 10.3.3 without saved blobs
        - For certain A7 devices that still have iOS 10.3.3 signed via OTA
        - Put your device into DFU mode before proceeding.

  --downgrade [IPSW FILE] [SHSH BLOB]
        Downgrade a device with SHSH blobs.
        - NOTE: the shsh blob must be for the iOS version you're downgrading to! 
        - if you dont have shsh blobs for the version you want to downgrade to, please make a custom ipsw and use the restore flag instead to do a tethered downgrade.

  --boot [iOS_VERSION]
        Perform a tethered boot of the specified iOS version.
        - You must be on that iOS version already.
        - Put your device into DFU mode before proceeding.
   
  -h, --help
        Show this help message and exit.

EOF
}

if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

case "$1" in
    --fix-ios8)
        echo "[!] WARNING: Your device must be freshly restored to iOS 8.0-8.4.1 with the seprmvr64 restore, and NEVER booted!"
        sleep 5
        cd SSHRD_Script
        sudo ./sshrd.sh 12.0
        read -p "Was there an error while making the ramdisk? (y/n) " error_response
        if [[ $error_response == y ]]; then
            sudo ./sshrd.sh 12.0
        else
            echo ""
        fi
        cd ..
        echo "first, your device needs to be in pwndfu mode. pwning with gaster"
        echo "[!] Linux has low success rate for the checkm8 exploit on A6-A7. If possible, you should connect your device to a Mac or iOS device and pwn with ipwnder"
        echo "You can ignore this message if you are restoring an A8(X) device or newer."
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
        cd SSHRD_Script
        sudo ./sshrd.sh boot
        sleep 17
        sudo gnome-terminal -- bash -c "sudo ./sshrd.sh ssh"
        sleep 3
        echo "This may TAKE up to 15-30 MINUTES to complete! Please be patient during this time."
        ./Linux/sshpass -p "alpine" ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs /dev/disk0s1s1 /mnt1 || true"
        sleep 6
        ./Linux/sshpass -p "alpine" scp -P2222 -o StrictHostKeyChecking=no root@localhost:/mnt1/System/Library/Caches/com.apple.dyld/dyld_shared_cache_arm64 dyld.raw
        ../bin/dsc64patcher dyld.raw dyld.patched -8
        ./Linux/sshpass -p "alpine" scp -P2222 -o StrictHostKeyChecking=no dyld.patched root@localhost:/mnt1/System/Library/Caches/com.apple.dyld/dyld_shared_cache_arm64
        sleep 12
        rm -rf dyld.raw
        rm -rf dyld.patched
        sudo ./sshrd.sh reboot
        echo "All done! You can now boot your fixed iOS 8 install with: ./surrealra1n.sh --seprmvr64-boot [your ios 8 version]"
        exit 0
        ;;
    --seprmvr64-ipsw)
        if [[ $# -ne 4 ]]; then
            echo "[!] Usage: --seprmvr64-ipsw [TARGET_IPSW_PATH] [BASE_IPSW_PATH] [iOS_VERSION]"
            exit 1
        fi
        TARGET_IPSW="$2"
        BASE_IPSW="$3"
        IOS_VERSION="$4"
        echo "[!] IMPORTANT: This feature is only supported on iOS 7.0 - 9.3.5. DO NOT TRY THIS on 10.0 or later"
        echo "[!] Warning: Before you proceed with a seprmvr64 restore, please understand the following issues you will have afterwards:"
        echo "[!] 1. Touch ID will NOT work, at all."
        echo "[!] 2. Passcode will NOT work, at all. Your passcode is technically NULL."
        echo "[!] 3. Encrypted Wi-Fi networks will not work. Use an open network instead."
        echo "[!] 4. You will have deep sleep issues, and POTENTIALLY other issues."
        read -p "Press any key to continue. Or press CTRL + C to cancel."
        if [[ $IOS_VERSION == 9.* ]]; then
            echo "[!] iOS $IOS_VERSION detected."
            echo "[!] The restore ramdisk from this version might cause issues with restoring the device (especially if the mART is corrupt)"
            echo "[!] It is STRONGLY recommended to use iOS 8.4 - 8.4.1 ramdisk option when restoring to this version."
            if [[ $IDENTIFIER == iPod7* ]]; then
                echo "Using 8.4.x ramdisk method regardless because of issues when restoring with 9 ramdisk."
            else
                read -p "Use iOS 8.4.x ramdisk method? (y/n): " ios8ramdisk
            fi
            if [[ $ios8ramdisk == y || $ios8ramdisk == Y || $IDENTIFIER == iPod7* ]]; then
                read -p "iOS version for ramdisk? " ramdiskversion
                rdskipsw=$(zenity --file-selection --title="Select the iOS $ramdiskversion IPSW file" --file-filter="*.ipsw")

                echo "[*] Making custom IPSW..."
                savedir="noseprestore/$IDENTIFIER/$IOS_VERSION"
                mkdir -p "$savedir"
                echo ""
                unzip "$TARGET_IPSW" -d tmp1
                unzip "$BASE_IPSW" -d tmp2
                unzip "$rdskipsw" -d tmp3
                # Read decryption keys
                KEY_FILE="keys/$IDENTIFIER.txt"
                if [[ ! -f "$KEY_FILE" ]]; then
                    echo "[!] Key file $KEY_FILE not found. Aborting."
                    exit 1
                fi

                # Extract iBSS and iBEC keys
                IBSS_KEY=$(grep "ibss-$ramdiskversion:" "$KEY_FILE" | cut -d':' -f2 | xargs)
                IBEC_KEY=$(grep "ibec-$ramdiskversion:" "$KEY_FILE" | cut -d':' -f2 | xargs)
                DTRE_KEY=$(grep "dtre-$ramdiskversion:" "$KEY_FILE" | cut -d':' -f2 | xargs)
                RDSK_KEY=$(grep "rdsk-$ramdiskversion:" "$KEY_FILE" | cut -d':' -f2 | xargs)
                KRNL_KEY=$(grep "krnl-$ramdiskversion:" "$KEY_FILE" | cut -d':' -f2 | xargs)
                ROOT_KEY=$(grep "fstm-$IOS_VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)

                if [[ -z "$IBSS_KEY" || -z "$IBEC_KEY" ]]; then
                    echo "[!] Missing iBSS or iBEC key for iOS $IOS_VERSION in $KEY_FILE. Aborting."
                    exit 1
                fi

                echo "[*] Found keys:"
                echo "    iBSS Key: $IBSS_KEY"
                echo "    iBEC Key: $IBEC_KEY"

                smallest_dmg=$(find tmp3 -type f -name '*.dmg' ! -name '._*' -printf '%s %p\n' | sort -n | head -n 1 | cut -d' ' -f2-)
                smallest12_dmg=$(find tmp2 -type f -name '*.dmg' ! -name '._*' -printf '%s %p\n' | sort -n | head -n 1 | cut -d' ' -f2-)
                rootfs_dmg=$(find tmp1 -type f -name '*.dmg' ! -name '._*' -printf '%s %p\n' | sort -nr | head -n 1 | cut -d' ' -f2-)
                rootfs12_dmg=$(find tmp2 -type f -name '*.dmg' ! -name '._*' -printf '%s %p\n' | sort -nr | head -n 1 | cut -d' ' -f2-)

                mkdir work
                rm -rf "$rootfs12_dmg"
                ./bin/dmg extract "$rootfs_dmg" "tmp1/rootfs.raw" -k $ROOT_KEY
                ./bin/dmg build "tmp1/rootfs.raw" "$rootfs12_dmg"

                ./bin/img4 -i "$smallest_dmg" -o "work/ramdisk.raw" -k $RDSK_KEY 
                ./bin/hfsplus "work/ramdisk.raw" grow 30000000
                ./bin/hfsplus "work/ramdisk.raw" extract usr/sbin/asr
                ./bin/asr64_patcher asr asr_patched
                ./bin/ldid -e asr > ents.plist
                ./bin/ldid -Sents.plist asr_patched
                ./bin/hfsplus "work/ramdisk.raw" rm usr/sbin/asr
                ./bin/hfsplus "work/ramdisk.raw" add asr_patched usr/sbin/asr
                ./bin/hfsplus "work/ramdisk.raw" chmod 100755 usr/sbin/asr
                if [[ $IDENTIFIER == iPod7* ]]; then
                    ./bin/hfsplus "work/ramdisk.raw" extract usr/local/bin/restored_external
                    ./bin/restoredpatcher restored_external restored_patch -b
                    ./bin/ldid -e restored_external > ents.plist
                    ./bin/ldid -Sents.plist restored_patch
                    ./bin/hfsplus "work/ramdisk.raw" rm usr/local/bin/restored_external
                    ./bin/hfsplus "work/ramdisk.raw" add restored_patch usr/local/bin/restored_external
                    ./bin/hfsplus "work/ramdisk.raw" chmod 100755 usr/local/bin/restored_external
                fi
                ./bin/img4 -i "work/ramdisk.raw" -o "$smallest12_dmg" -A -T rdsk
                rm -rf "asr asr_patched ents.plist"
                ./bin/img4 -i "tmp3/Firmware/all_flash/$ALLFLASH/$DEVICETREE" -o "work/dtre.raw" -k $DTRE_KEY

                # patch content-protect string devicetree, to prevent restore freezes at keybag step
                perl -pi -e 's/content-protect/content-protecV/g' work/dtre.raw 

                ./bin/img4 -i "work/dtre.raw" -o "tmp2/Firmware/all_flash/$DEVICETREE" -A -T rdtr

                if [[ $ramdiskversion != 7.* ]]; then
                    mv "tmp3/Firmware/dfu/$IBSS10" "tmp3/Firmware/dfu/$IBSS7"
                    mv "tmp3/Firmware/dfu/$IBEC10" "tmp3/Firmware/dfu/$IBEC7"
                fi

                ./bin/img4 -i "tmp3/Firmware/dfu/$IBSS7" -o "work/iBSS.dec" -k "$IBSS_KEY"
                ./bin/img4 -i "tmp3/Firmware/dfu/$IBEC7" -o "work/iBEC.dec" -k "$IBEC_KEY"

                if [[ $ramdiskversion == 7.* || $ramdiskversion == 8.* ]]; then
                    ./bin/ipatcher work/iBSS.dec work/iBSS.patched
                    ./bin/ipatcher work/iBEC.dec work/iBEC.patched -b "rd=md0 debug=0x2014e -v wdt=-1 nand-enable-reformat=1 -restore amfi=0xff cs_enforcement_disable=1"
                else
                    ./bin/kairos work/iBSS.dec work/iBSS.patched
                    ./bin/kairos work/iBEC.dec work/iBEC.patched -b "rd=md0 debug=0x2014e -v wdt=-1 nand-enable-reformat=1 -restore amfi=0xff cs_enforcement_disable=1"
                fi

                ./bin/img4 -i "work/iBSS.patched" -o "tmp2/Firmware/dfu/$IBSS" -A -T ibss   
                ./bin/img4 -i "work/iBEC.patched" -o "tmp2/Firmware/dfu/$IBEC" -A -T ibec 

                ./bin/img4 -i "tmp3/$KERNELCACHE10" -o "work/kcache.raw" -k $KRNL_KEY  
                ./bin/img4 -i "tmp3/$KERNELCACHE10" -o "work/kcache.im4p" -k $KRNL_KEY -D

                if [[ $ramdiskversion == 7.* ]]; then
                    ./bin/Kernel64Patcher2 "work/kcache.raw" "work/kcache.patched" -u 7 -m 7 -e 7 -f 7 -k
                elif [[ $ramdiskversion == 8.* ]]; then
                    ./bin/Kernel64Patcher2 "work/kcache.raw" "work/kcache.patched" -u 8 -t -p -e 8 -f 8 -a -m 8 -g -s -d
                else
                    ./bin/Kernel64Patcher2 "work/kcache.raw" "work/kcache.patched" -u 9 -f 9 -k
                fi     

                ./bin/kerneldiff "work/kcache.raw" "work/kcache.patched" "work/kcache.bpatch"

                # wrap kcache into im4p
                ./bin/img4 -i "work/kcache.im4p" -o "tmp2/$KERNELCACHE" -T rkrn -P "work/kcache.bpatch" -J

                echo "Patching complete!"
                rm -rf "work"
                rm -rf "tmp1"
                rm -rf "tmp3"

                cd tmp2
                zip -0 -r ../$savedir/custom.ipsw *
                cd ..

                rm -rf "tmp2"
                echo "Custom IPSW is created! You can restore with: ./surrealra1n.sh --seprmvr64-restore $IOS_VERSION"
                exit 0
            else
                echo "Continuing without iOS 8.4.x ramdisk method"
                sleep 4
            fi
        fi
        echo "[*] Making custom IPSW..."
        savedir="noseprestore/$IDENTIFIER/$IOS_VERSION"
        mkdir -p "$savedir"
        echo ""
        unzip "$TARGET_IPSW" -d tmp1
        unzip "$BASE_IPSW" -d tmp2
        # Read decryption keys
        KEY_FILE="keys/$IDENTIFIER.txt"
        if [[ ! -f "$KEY_FILE" ]]; then
            echo "[!] Key file $KEY_FILE not found. Aborting."
            exit 1
        fi

        # Extract iBSS and iBEC keys
        IBSS_KEY=$(grep "ibss-$IOS_VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)
        IBEC_KEY=$(grep "ibec-$IOS_VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)
        DTRE_KEY=$(grep "dtre-$IOS_VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)
        RDSK_KEY=$(grep "rdsk-$IOS_VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)
        KRNL_KEY=$(grep "krnl-$IOS_VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)
        ROOT_KEY=$(grep "fstm-$IOS_VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)

        if [[ -z "$IBSS_KEY" || -z "$IBEC_KEY" ]]; then
            echo "[!] Missing iBSS or iBEC key for iOS $IOS_VERSION in $KEY_FILE. Aborting."
            exit 1
        fi

        echo "[*] Found keys:"
        echo "    iBSS Key: $IBSS_KEY"
        echo "    iBEC Key: $IBEC_KEY"
        if [[ $IOS_VERSION == 7.1* || $IOS_VERSION == 8.* || $IOS_VERSION == 9.* ]]; then
            smallest_dmg=$(find tmp1 -type f -name '*.dmg' ! -name '._*' -printf '%s %p\n' | sort -n | head -n 1 | cut -d' ' -f2-)
        else
            smallest_dmg=$(find tmp1 -type f -name '*.dmg' ! -name '._*' -size -10370000c -printf '%s %p\n' | sort -nr | head -n 1 | cut -d' ' -f2-)
        fi
        smallest12_dmg=$(find tmp2 -type f -name '*.dmg' ! -name '._*' -printf '%s %p\n' | sort -n | head -n 1 | cut -d' ' -f2-)
        rootfs_dmg=$(find tmp1 -type f -name '*.dmg' ! -name '._*' -printf '%s %p\n' | sort -nr | head -n 1 | cut -d' ' -f2-)
        rootfs12_dmg=$(find tmp2 -type f -name '*.dmg' ! -name '._*' -printf '%s %p\n' | sort -nr | head -n 1 | cut -d' ' -f2-)
        mkdir work
        rm -rf "$rootfs12_dmg"
        ./bin/img4 -i "$smallest_dmg" -o "$smallest12_dmg" -k $RDSK_KEY -D
        if [[ $IOS_VERSION == 8.* ]] && [[ $IDENTIFIER == iPod7* ]]; then
            # patch asr, and if A8, patch restored_external FDR step
            ./bin/img4 -i "$smallest_dmg" -o "work/ramdisk.raw" -k $RDSK_KEY 
            ./bin/hfsplus "work/ramdisk.raw" grow 30000000
            ./bin/hfsplus "work/ramdisk.raw" extract usr/sbin/asr
            ./bin/asr64_patcher asr asr_patch 
            ./bin/ldid -e asr > ents.plist
            ./bin/ldid -Sents.plist asr_patch
            ./bin/hfsplus "work/ramdisk.raw" rm usr/sbin/asr
            ./bin/hfsplus "work/ramdisk.raw" add asr_patch usr/sbin/asr
            ./bin/hfsplus "work/ramdisk.raw" chmod 100755 usr/sbin/asr
            if [[ $IDENTIFIER == iPod7* ]]; then
                ./bin/hfsplus "work/ramdisk.raw" extract usr/local/bin/restored_external
                ./bin/restoredpatcher restored_external restored_patch -b
                ./bin/ldid -e restored_external > ents.plist
                ./bin/ldid -Sents.plist restored_patch
                ./bin/hfsplus "work/ramdisk.raw" rm usr/local/bin/restored_external
                ./bin/hfsplus "work/ramdisk.raw" add restored_patch usr/local/bin/restored_external
                ./bin/hfsplus "work/ramdisk.raw" chmod 100755 usr/local/bin/restored_external
                ./bin/img4 -i "work/ramdisk.raw" -o "$smallest12_dmg" -A -T rdsk
            fi
            ./bin/dmg extract "$rootfs_dmg" "tmp1/rootfs.raw" -k $ROOT_KEY
            ./bin/dmg build "tmp1/rootfs.raw" "$rootfs12_dmg"
        elif [[ $IOS_VERSION == 9.* ]] && [[ $IDENTIFIER == iPod7* ]]; then
            # patch asr, and if A8, patch restored_external FDR step
            ./bin/img4 -i "$smallest_dmg" -o "work/ramdisk.raw" -k $RDSK_KEY 
            ./bin/hfsplus "work/ramdisk.raw" grow 40000000
            ./bin/hfsplus "work/ramdisk.raw" extract usr/sbin/asr
            ./bin/asr64_patcher asr asr_patch 
            ./bin/ldid -e asr > ents.plist
            ./bin/ldid -Sents.plist asr_patch
            ./bin/hfsplus "work/ramdisk.raw" rm usr/sbin/asr
            ./bin/hfsplus "work/ramdisk.raw" add asr_patch usr/sbin/asr
            ./bin/hfsplus "work/ramdisk.raw" chmod 100755 usr/sbin/asr
            if [[ $IDENTIFIER == iPod7* ]]; then
                ./bin/hfsplus "work/ramdisk.raw" extract usr/local/bin/restored_external
                ./bin/restoredpatcher restored_external restored_patch -b
                ./bin/ldid -e restored_external > ents.plist
                ./bin/ldid -Sents.plist restored_patch
                ./bin/hfsplus "work/ramdisk.raw" rm usr/local/bin/restored_external
                ./bin/hfsplus "work/ramdisk.raw" add restored_patch usr/local/bin/restored_external
                ./bin/hfsplus "work/ramdisk.raw" chmod 100755 usr/local/bin/restored_external
                ./bin/img4 -i "work/ramdisk.raw" -o "$smallest12_dmg" -A -T rdsk
            fi
            ./bin/dmg extract "$rootfs_dmg" "tmp1/rootfs.raw" -k $ROOT_KEY
            ./bin/dmg build "tmp1/rootfs.raw" "$rootfs12_dmg"
        else
            mv "$rootfs_dmg" "$rootfs12_dmg"
        fi
        ./bin/img4 -i "tmp1/Firmware/all_flash/$ALLFLASH/$DEVICETREE" -o "work/dtre.raw" -k $DTRE_KEY
        # patch content-protect string devicetree, to prevent restore freezes at keybag step
        perl -pi -e 's/content-protect/content-protecV/g' work/dtre.raw 
        ./bin/img4 -i "work/dtre.raw" -o "tmp2/Firmware/all_flash/$DEVICETREE" -A -T rdtr
        if [[ $IOS_VERSION != 7.* ]]; then
            mv "tmp1/Firmware/dfu/$IBSS10" "tmp1/Firmware/dfu/$IBSS7"
            mv "tmp1/Firmware/dfu/$IBEC10" "tmp1/Firmware/dfu/$IBEC7"
        fi
        ./bin/img4 -i "tmp1/Firmware/dfu/$IBSS7" -o "work/iBSS.dec" -k "$IBSS_KEY"
        ./bin/img4 -i "tmp1/Firmware/dfu/$IBEC7" -o "work/iBEC.dec" -k "$IBEC_KEY"
        if [[ $IOS_VERSION == 7.* || $IOS_VERSION == 8.* ]]; then
            ./bin/ipatcher work/iBSS.dec work/iBSS.patched
            ./bin/ipatcher work/iBEC.dec work/iBEC.patched -b "rd=md0 debug=0x2014e -v wdt=-1 nand-enable-reformat=1 -restore amfi=0xff cs_enforcement_disable=1"
        else
            ./bin/kairos work/iBSS.dec work/iBSS.patched
            ./bin/kairos work/iBEC.dec work/iBEC.patched -b "rd=md0 debug=0x2014e -v wdt=-1 nand-enable-reformat=1 -restore amfi=0xff cs_enforcement_disable=1"
        fi
        ./bin/img4 -i "work/iBSS.patched" -o "tmp2/Firmware/dfu/$IBSS" -A -T ibss   
        ./bin/img4 -i "work/iBEC.patched" -o "tmp2/Firmware/dfu/$IBEC" -A -T ibec 
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
        # wrap kcache into im4p
        ./bin/img4 -i "work/kcache.im4p" -o "tmp2/$KERNELCACHE" -T rkrn -P "work/kcache.bpatch" -J
        echo "Patching complete!"
        rm -rf "work"
        rm -rf "tmp1"
        cd tmp2
        zip -0 -r ../$savedir/custom.ipsw *
        cd ..
        rm -rf "tmp2"
        echo "Custom IPSW is created! You can restore with: ./surrealra1n.sh --seprmvr64-restore $IOS_VERSION"
        exit 0
        ;;

    --seprmvr64-restore)
        if [[ $# -ne 2 ]]; then
            echo "[!] Usage: --seprmvr64-restore [iOS_VERSION]"
            exit 1
        fi
        IOS_VERSION="$2"
        echo "[!] IMPORTANT: This feature is only supported on iOS 7.0 - 9.3.5. DO NOT TRY THIS on 10.0 or later"
        echo "[!] Warning: Before you proceed with a seprmvr64 restore, please understand the following issues you will have afterwards:"
        echo "[!] 1. Touch ID will NOT work, at all."
        echo "[!] 2. Passcode will NOT work, at all. Your passcode is technically NULL. Any time you're asked for a passcode, input anything."
        echo "[!] 3. Encrypted Wi-Fi networks will not work. Use an open network instead."
        echo "[!] 4. You will have deep sleep issues, and POTENTIALLY other issues."
        echo "[!] 5. iOS 7.0 - 7.0.6 will likely freeze a lot after tether booting. It is recommended to do iOS 7.1 or later instead."
        echo "[!] 6. iOS 8.x will be stuck at Slide to Upgrade afterwards. It is recommended to do 7.x or 9.x instead"
        read -p "Press any key to continue. Or press CTRL + C to cancel."
        echo "[*] Starting Restore to iOS $IOS_VERSION..."
        savedir="noseprestore/$IDENTIFIER/$IOS_VERSION"
        echo "Fetching shsh blobs for iOS $LATEST_VERSION (to extract im4m later)"
        rm -rf "shsh"
        mkdir -p shsh
        sudo ./bin/tsschecker -d $IDENTIFIER -s -e $ECID -i $LATEST_VERSION --save-path shsh

        # Find the .shsh2 file in the shsh directory
        shshpath=$(find shsh -type f -name "*.shsh2" | head -n 1)
        if [[ -z "$shshpath" ]]; then
            echo "[!] No .shsh2 blob found in shsh folder. Aborting."
            exit 1
        fi
        echo "first, your device needs to be in pwndfu mode. pwning with gaster"
        echo "[!] Linux has low success rate for the checkm8 exploit on A6-A7. If possible, you should connect your device to a Mac or iOS device and pwn with ipwnder"
        echo "You can ignore this message if you are restoring an A8(X) device or newer."
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
        sudo LD_LIBRARY_PATH="lib" ./bin/idevicerestore -e $savedir/custom.ipsw -y
        echo "Restore has completed! If it's successful, you can boot with: ./surrealra1n.sh --seprmvr64-boot $IOS_VERSION"
        exit 0
        ;;

    --seprmvr64-boot)
        if [[ $# -ne 2 ]]; then
            echo "[!] Usage: --seprmvr64-boot [iOS_VERSION]"
            exit 1
        fi
        IOS_VERSION="$2"
        savedir="seprmvr64boot/$IDENTIFIER/$IOS_VERSION"
        shshpath=$(find shsh -type f -name "*.shsh2" | head -n 1)
        if [[ -z "$shshpath" ]]; then
            echo "[!] No .shsh2 blob found in shsh folder. Aborting."
            exit 1
        fi
        if [[ ! -d "$savedir" ]]; then
            echo "[!] New boot files must be created."
            sleep 2
        else
            echo "first, your device needs to be in pwndfu mode. pwning with gaster"
            echo "[!] Linux has low success rate for the checkm8 exploit on A6-A7. If possible, you should connect your device to a Mac or iOS device and pwn with ipwnder"
            echo "You can ignore this message if you are restoring an A8(X) device or newer."
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
        IPSW_PATH=$(zenity --file-selection --title="Select the iOS $IOS_VERSION IPSW file" --file-filter="*.ipsw")
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
        IBSS_KEY=$(grep "ibss-$IOS_VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)
        IBEC_KEY=$(grep "ibec-$IOS_VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)
        DTRE_KEY=$(grep "dtre-$IOS_VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)
        KRNL_KEY=$(grep "krnl-$IOS_VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)

        if [[ -z "$IBSS_KEY" || -z "$IBEC_KEY" ]]; then
            echo "[!] Missing iBSS or iBEC key for iOS $IOS_VERSION in $KEY_FILE. Aborting."
            exit 1
        fi

        echo "[*] Found keys:"
        echo "    iBSS Key: $IBSS_KEY"
        echo "    iBEC Key: $IBEC_KEY"
        mkdir work
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
            ./bin/ipatcher work/iBEC.dec work/iBEC.patched -b "-v rd=disk0s1s1 amfi=0xff cs_enforcement_disable=1 keepsyms=1 debug=0x2014e wdt=-1 PE_i_can_has_debugger=1 amfi_get_out_of_my_way=0x1 amfi_unrestrict_task_for_pid=0x0"
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
        ./bin/img4 -i "work/kcache.im4p" -o "$savedir/Kernelcache.img4" -T rkrn -P "work/kcache.bpatch" -J -M $im4m
        echo "Patching complete!"
        rm -rf "work"
        rm -rf "tmp1"
        echo "first, your device needs to be in pwndfu mode. pwning with gaster"
        echo "[!] Linux has low success rate for the checkm8 exploit on A6-A7. If possible, you should connect your device to a Mac or iOS device and pwn with ipwnder"
        echo "You can ignore this message if you are restoring an A8(X) device or newer."
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
        ./bin/irecovery -f $savedir/iBSS.img4
        ./bin/irecovery -f $savedir/iBEC.img4
        ./bin/irecovery -f $savedir/DeviceTree.img4
        ./bin/irecovery -c devicetree
        ./bin/irecovery -f $savedir/Kernelcache.img4
        ./bin/irecovery -c bootx
        echo "Your device should now boot."
        exit 0
        ;;

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

        if [[ "$IDENTIFIER" == iPod7* ]] && [[ "$IOS_VERSION" == 11.2* || "$IOS_VERSION" == 11.1* || "$IOS_VERSION" == 11.0* || "$IOS_VERSION" == 10.* || "$IOS_VERSION" == 9.* || "$IOS_VERSION" == 8.* ]]; then
            echo "[!] SEP is incompatible"
            echo "[!] You cannot restore to this version or make a custom IPSW for it"
            exit 1
        fi

        if [[ "$IDENTIFIER" == iPhone6* ]] && [[ "$IOS_VERSION" == 10.3.3 ]]; then
            echo "[!] iOS 10.3.3 can be restored untethered via OTA downgrade"
            echo "[!] It is recommended to use --ota-downgrade [iOS 10.3.3 ipsw] to OTA downgrade to 10.3.3"
            read -p "Press any key to continue with iOS 10.3.3 tethered downgrade"
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
            read -p "Press any key to continue"
        fi 
        if [[ "$IDENTIFIER" == iPad5* ]] && [[ $IOS_VERSION == 13.4* || $IOS_VERSION == 13.5* || $IOS_VERSION == 13.6* || $IOS_VERSION == 13.7* ]]; then
            echo "[!] SEP is partially incompatible"
            echo "[!] The iPadOS $LATEST_VERSION SEP is not fully compatible with this version."
            echo "[!] The following issues may occur:"
            echo "[!] Touch ID will cease to function fully."
            echo "[!] And if you are restoring to iPadOS 13.4 - 13.7, you will be stuck in a blank screen after the restore. Put the device into real DFU mode and boot it normally."
            read -p "Press any key to continue"
        fi 
        if [[ "$IDENTIFIER" == iPad5* ]] && [[ $IOS_VERSION == 13.3* || $IOS_VERSION == 13.2* || $IOS_VERSION == 13.1* || $IOS_VERSION == 13.0* || $IOS_VERSION == 12.* || $IOS_VERSION == 11.* || $IOS_VERSION == 10.* || $IOS_VERSION == 9.* || $IOS_VERSION == 8.* ]]; then
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
            if [[ $IDENTIFIER == iPhone10,3 || $IDENTIFIER == iPhone10,6 ]]; then
                echo "[!] The iPhone X may or may not work with surrealra1n, your mileage may vary! Please use at your own risk. Mineek's restored_external patcher will be used."
            fi
            read -p "Press any key to continue"
        fi 
        if [[ "$IDENTIFIER" == iPhone10* ]] && [[ $IOS_VERSION == 13.* || $IOS_VERSION == 12.* || $IOS_VERSION == 11.* ]]; then
            echo "[!] SEP is incompatible"
            echo "[!] You cannot restore to this version or make a custom IPSW for it"
            exit 1
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
            if [[ $IOS_VERSION == 14.0* || $IOS_VERSION == 14.1* || $IOS_VERSION == 14.2* ]] && [[ $IDENTIFIER == iPhone10* ]]; then
                # A11 hax to tether restore 14.0-14.2 on 16 SEP, 14.3 iBoot method (thanks to verygenericname for pointing that out)
                IPSW_PATH=$(zenity --file-selection --title="Select the iOS 14.3 IPSW file (for iBSS and iBEC)" --file-filter="*.ipsw")
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
            if [[ $IDENTIFIER == iPod7* ]] && [[ $IOS_VERSION == 11.0* || $IOS_VERSION == 11.1* || $IOS_VERSION == 11.2* ]]; then
                echo "content-protect haxx lol (to maybe fix 11.2.x restores on 12 sep?)"
                ./bin/img4 -i "tmp1/Firmware/all_flash/$DEVICETREE" -o dtre.raw
                perl -pi -e 's/content-protect/content-protecV/g' dtre.raw
                echo "Devicetree haxx complete!"
                sleep 4
                echo "Packing devicetree into im4p!"
                ./bin/img4 -i dtre.raw -o "tmp1/Firmware/all_flash/$DEVICETREE" -A -T rdtr
                rm -rf dtre.raw
            fi
        fi
        rm -rf "tmp2"
        cd tmp1
        zip -0 -r ../custom.ipsw *
        cd ..
        mv custom.ipsw "$savedir/custom.ipsw"
        
        # determine restore ramdisk
        smallest_dmg=$(find tmp1 -type f -name '*.dmg' ! -name '._*' -printf '%s %p\n' | sort -n | head -n 1 | cut -d' ' -f2-)
        # determine update ramdisk (experimental tethered updates?)
        update_dmg=$(
    find tmp1 -type f -name '*.dmg' ! -name '._*' \
        -printf '%s %p\n' \
    | awk '$1 < 1073741824' \
    | sort -nr \
    | head -n 1 \
    | cut -d' ' -f2-
)
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
        if [[ "$IDENTIFIER" == iPhone6,* || $IDENTIFIER == iPod7* ]] && [[ "$IOS_VERSION" == 10.* || "$IOS_VERSION" == 11.0* || "$IOS_VERSION" == 11.1* || "$IOS_VERSION" == 11.2* ]]; then
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
        if [[ $IOS_VERSION == 14.* || $IOS_VERSION == 15.* ]]; then
            echo "patching restored_external"
            sudo ./bin/hfsplus ramdisk.raw extract usr/local/bin/restored_external 
            if [[ $IDENTIFIER == iPhone10,3 || $IDENTIFIER == iPhone10,6 ]]; then
                echo "[!] You are trying to restore an iPhone X to iOS $IOS_VERSION"
                echo "An additional patch is required!"
                sudo ./bin/ipx_restored_patcher restored_external patched_external
                sudo ./bin/restored_external64_patcher patched_external patched_restored_external
            else
                sudo ./bin/restored_external64_patcher restored_external patched_restored_external
            fi
            sudo ./bin/ldid -e restored_external > ents.plist
            sudo ./bin/ldid -Sents.plist patched_restored_external
            echo "replacing restored_external with patched restored_external"
            sudo ./bin/hfsplus ramdisk.raw rm usr/local/bin/restored_external
            sleep 4 
            sudo ./bin/hfsplus ramdisk.raw add patched_restored_external usr/local/bin/restored_external
            sleep 4
            sudo ./bin/hfsplus ramdisk.raw chmod 755 usr/local/bin/restored_external
        fi
        sleep 4
        echo "Packing patched Ramdisk as im4p"
        sudo ./bin/img4 -i ramdisk.raw -o ramdisk.im4p -T rdsk -A
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
        sudo ./bin/img4 -i "$update_dmg" -o ramdisk.raw
        rm -rf "tmp1" 
        if [[ "$IDENTIFIER" == iPhone6,* || $IDENTIFIER == iPod7* ]] && [[ "$IOS_VERSION" == 10.* || "$IOS_VERSION" == 11.0* || "$IOS_VERSION" == 11.1* || "$IOS_VERSION" == 11.2* ]]; then
            echo "growing ramdisk"
            sudo ./bin/hfsplus ramdisk.raw grow 70000000
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
        # restored_external in update ramdisk is restored_update
        if [[ $IOS_VERSION == 14.* || $IOS_VERSION == 15.* ]]; then
            echo "patching restored_update"
            sudo ./bin/hfsplus ramdisk.raw extract usr/local/bin/restored_update 
            if [[ $IDENTIFIER == iPhone10,3 || $IDENTIFIER == iPhone10,6 ]]; then
                echo "[!] You are trying to restore an iPhone X to iOS $IOS_VERSION"
                echo "An additional patch is required!"
                sudo ./bin/ipx_restored_patcher restored_update patched_external
                sudo ./bin/restored_external64_patcher patched_external patched_restored_external
            else
                sudo ./bin/restored_external64_patcher restored_update patched_restored_external
            fi
            sudo ./bin/ldid -e restored_update > ents.plist
            sudo ./bin/ldid -Sents.plist patched_restored_external
            echo "replacing restored_update with patched restored_update"
            sudo ./bin/hfsplus ramdisk.raw rm usr/local/bin/restored_update
            sleep 4 
            sudo ./bin/hfsplus ramdisk.raw add patched_restored_external usr/local/bin/restored_update
            sleep 4
            sudo ./bin/hfsplus ramdisk.raw chmod 755 usr/local/bin/restored_update
        fi
        sleep 4
        echo "Packing patched Ramdisk as im4p"
        sudo ./bin/img4 -i ramdisk.raw -o ramdisk.im4p -T rdsk -A
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
        read -p "Do you want to do an update install? (y/n): " update_prompt
        if [[ $IDENTIFIER == iPhone6* ]] && [[ $IOS_VERSION == 11.0* || $IOS_VERSION == 11.1* || $IOS_VERSION == 11.2* ]] && [[ $update_prompt == N || $update_prompt == n ]]; then
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
        if [[ $IDENTIFIER == iPhone10* ]] && [[ $IOS_VERSION == 14.* || $IOS_VERSION == 15.* ]] && [[ $update_prompt == N || $update_prompt == n ]]; then
            echo "We must save activation tickets in order to activate on this version. Please read what is below."
            echo "If you are on iOS 16.0 or later, note the following:"
            echo "eclipsera1n from hiylx will be used to save activation tickets. Make sure you are jailbroken with palera1n (or Dopamine if you're on 16.6.1 or earlier), and that OpenSSH is installed."
            echo "If you are on iOS 15 or earlier, the SSHRD method will be used instead."
            echo ""
            echo "Press any key to continue, or press Ctrl + C to cancel."
            read -p ""
            echo "What is the iOS version of this device?"
            read -p " " version
            if [[ $version == 16.* ]]; then
                echo "Assuming device is jailbroken with palera1n and OpenSSH installed"
                sudo ./backup.sh
            else
                echo "Put your device from Normal mode into DFU mode! Press any key after you have done so"
                read -p ""
                cd SSHRD_Script
                sudo ./sshrd.sh $version
                read -p "Was there an error while making the ramdisk? (y/n) " error_response
                if [[ $error_response == y ]]; then
                    sudo ./sshrd.sh $version
                else
                    echo ""
                fi
                sudo ./sshrd.sh boot
                sleep 10
                sudo ./sshrd.sh --backup-activation
                sudo ./sshrd.sh reboot
                cd ..
            fi
        fi
        if [[ $IDENTIFIER == iPad7* ]] && [[ $IOS_VERSION == 14.* || $IOS_VERSION == 15.* ]] && [[ $update_prompt == N || $update_prompt == n ]]; then
            echo "We must save activation tickets in order to activate on this version. Please read what is below."
            echo "If you are on iPadOS 16.0 or later, note the following:"
            echo "eclipsera1n from hiylx will be used to save activation tickets. Make sure you are jailbroken with palera1n (or Dopamine if you're on 16.6.1 or earlier), and that OpenSSH is installed."
            echo "If you are on iPadOS 15 or earlier, the SSHRD method will be used instead."
            echo ""
            echo "Press any key to continue, or press Ctrl + C to cancel."
            read -p ""
            echo "What is the iOS version of this device?"
            read -p " " version
            if [[ $version == 16.* || $version == 17.* ]]; then
                echo "Assuming device is jailbroken with palera1n and OpenSSH installed"
                sudo ./backup.sh
            else
                echo "Put your device from Normal mode into DFU mode! Press any key after you have done so"
                read -p ""
                cd SSHRD_Script
                sudo ./sshrd.sh $version
                read -p "Was there an error while making the ramdisk? (y/n) " error_response
                if [[ $error_response == y ]]; then
                    sudo ./sshrd.sh $version
                else
                    echo ""
                fi
                sudo ./sshrd.sh boot
                sleep 10
                sudo ./sshrd.sh --backup-activation
                sudo ./sshrd.sh reboot
                cd ..
            fi
        fi
        echo "first, your device needs to be in pwndfu mode. pwning with gaster"
        echo "[!] Linux has low success rate for the checkm8 exploit on A6-A7. If possible, you should connect your device to a Mac or iOS device and pwn with ipwnder"
        echo "You can ignore this message if you are restoring an A8(X) device or newer."
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
        # Potential future iOS 16.x tethered support, send rsep always if restoring iPhone X to fix FDR SEP panic
        if [[ $IOS_VERSION == 16.* || $IDENTIFIER == iPhone10,3 || $IDENTIFIER == iPhone10,6 ]]; then
            use_rsep=""
        else
            use_rsep="--no-rsep"
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
                if [[ $update_prompt == y || $update_prompt == Y ]]; then
                    sudo FUTURERESTORE_I_SOLEMNLY_SWEAR_THAT_I_AM_UP_TO_NO_GOOD=1 ./futurerestore/futurerestore -t $shshpath --skip-blob --use-pwndfu --no-cache --rdsk $restoredir/updateramdisk.im4p --rkrn $restoredir/kernel.im4p --latest-baseband --sep "$SEP_PATH" --sep-manifest "$mnifst" --no-rsep $restoredir/custom.ipsw
                    echo "Restore has finished! Read above if there's any errors"
                    echo "YOU WILL FACE A LOT OF ISSUES REGARDING STUFF THAT REQUIRES SEP TO FULLY WORK"
                    exit 1
                fi
                sudo FUTURERESTORE_I_SOLEMNLY_SWEAR_THAT_I_AM_UP_TO_NO_GOOD=1 ./futurerestore/futurerestore -t $shshpath --skip-blob --use-pwndfu --rdsk $restoredir/ramdisk.im4p --rkrn $restoredir/kernel.im4p --no-cache --latest-baseband --sep "$SEP_PATH" --sep-manifest "$mnifst" --no-rsep $restoredir/custom.ipsw
                rm -rf "tmp"
                echo "Restore has finished! Read above if there's any errors"
                echo "YOU WILL FACE A LOT OF ISSUES REGARDING STUFF THAT REQUIRES SEP TO FULLY WORK"
                exit 1
            fi
            if [[ $update_prompt == y || $update_prompt == Y ]]; then
                sudo FUTURERESTORE_I_SOLEMNLY_SWEAR_THAT_I_AM_UP_TO_NO_GOOD=1 ./futurerestore/futurerestore -t $shshpath --skip-blob --use-pwndfu --no-cache --rdsk $restoredir/updateramdisk.im4p --rkrn $restoredir/kernel.im4p --baseband "$BASEBAND_PATH" --baseband-manifest "$mnifst" --sep "$SEP_PATH" --sep-manifest "$mnifst" --no-rsep $restoredir/custom.ipsw
                echo "Restore has finished! Read above if there's any errors"
                exit 1
            fi
            sudo FUTURERESTORE_I_SOLEMNLY_SWEAR_THAT_I_AM_UP_TO_NO_GOOD=1 ./futurerestore/futurerestore -t $shshpath --skip-blob --use-pwndfu --rdsk $restoredir/ramdisk.im4p --rkrn $restoredir/kernel.im4p --no-cache --baseband "$BASEBAND_PATH" --baseband-manifest "$mnifst" --sep "$SEP_PATH" --sep-manifest "$mnifst" --no-rsep $restoredir/custom.ipsw
            rm -rf "tmp"
            echo "Restore has finished! Read above if there's any errors"
            exit 1
        else
            if [[ $update_prompt == y || $update_prompt == Y ]]; then
                sudo ./futurerestore/futurerestore -t $shshpath --skip-blob --use-pwndfu --no-cache --rdsk $restoredir/updateramdisk.im4p --rkrn $restoredir/kernel.im4p $USE_BASEBAND --latest-sep $use_rsep $restoredir/custom.ipsw
                echo "Restore has finished! Read above if there's any errors"
                exit 1
            fi
            sudo ./futurerestore/futurerestore -t $shshpath --skip-blob --use-pwndfu --no-cache --rdsk $restoredir/ramdisk.im4p --rkrn $restoredir/kernel.im4p $USE_BASEBAND --latest-sep $use_rsep $restoredir/custom.ipsw 
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
           sudo ./futurerestore/futurerestore -t $SHSHBLOB --use-pwndfu $USE_BASEBAND --latest-sep --no-rsep $IPSW
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
            if [[ $IDENTIFIER == iPhone10* ]] && [[ $IOS_VERSION == 14.2* || $IOS_VERSION == 14.1* || $IOS_VERSION == 14.0* ]]; then
                IPSW_PATH="restorefiles/$IDENTIFIER/$IOS_VERSION/custom.ipsw"
            else
                IPSW_PATH=$(zenity --file-selection --title="Select the iOS $IOS_VERSION IPSW file" --file-filter="*.ipsw")
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
                ./bin/img4 -i to_patch/kernel.patched -o $BOOT_DIR/Kernelcache.img4 -M "$im4m" -A -T rkrn -J        
            fi
            if [[ $IOS_VERSION == 13.* ]]; then
                ./bin/img4 -i to_patch/kernelcache -o to_patch/kernel.raw
                ./bin/Kernel64Patcher to_patch/kernel.raw to_patch/kernel.patched -b13 -n
                ./bin/img4 -i to_patch/kernel.patched -o $BOOT_DIR/Kernelcache.img4 -M "$im4m" -A -T rkrn -J        
            fi
            if [[ $IOS_VERSION == 15.* ]]; then
                ./bin/img4 -i to_patch/kernelcache -o to_patch/kernel.raw
                ./bin/Kernel64Patcher to_patch/kernel.raw to_patch/kernel.patched -e -o -r -b15 
                ./bin/img4 -i to_patch/kernel.patched -o $BOOT_DIR/Kernelcache.img4 -M "$im4m" -A -T rkrn -J    
            fi
            ./bin/img4 -i to_patch/iBSS.patched -o $BOOT_DIR/iBSS.img4 -M "$im4m" -A -T ibss
            ./bin/img4 -i to_patch/iBEC.patched -o $BOOT_DIR/iBEC.img4 -M "$im4m" -A -T ibec
            if [[ "$IOS_VERSION" == 12.* || $IOS_VERSION == 13.* || $IOS_VERSION == 14.* || $IOS_VERSION == 15.* ]]; then
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
        if [[ $IDENTIFIER == iPad7* || $IDENTIFIER == iPhone10* ]] && [[ $IOS_VERSION == 14.* || $IOS_VERSION == 15.* ]]; then
            echo "If it's your first boot after downgrading, wait for the Hello screen, then proceed with the next step"
            read -p "Is this your first time booting? (y/n): " bootresponse
            if [[ $bootresponse == y ]]; then
                if [[ $IDENTIFIER == iPhone10* ]] && [[ $IOS_VERSION == 14.2* || $IOS_VERSION == 14.1* || $IOS_VERSION == 14.0* ]]; then
                    # Use 14.3 ramdisk to send activation files, on 14.0-14.2 restores on A11
                    ramdisk_version="14.3"
                else
                    ramdisk_version="$IOS_VERSION"                 
                fi
                read -p "Press any key after your device is in DFU mode, we will need to inject activation"
                sleep 4
                cd SSHRD_Script
                sudo ./sshrd.sh $ramdisk_version
                read -p "Was there an error while making the ramdisk? (y/n) " error_response
                if [[ $error_response == y ]]; then
                    sudo ./sshrd.sh $ramdisk_version
                else
                    echo ""
                fi
                sudo ./sshrd.sh boot
                sleep 10
                echo "What is the iOS version that you saved activation records with?"
                read -p " " version
                if [[ $version == 16.* || $version == 17.* ]]; then
                    echo "Open another terminal window in the SSHRD directory and type: sudo ./sshrd.sh ssh (then press any key to continue)"
                    read -p ""
                    cd ..
                    sudo ./activate.sh --skip-rdboot
                    echo "activation records have been restored! now run ./surrealra1n.sh --boot $IOS_VERSION to boot"
                    exit 1
                else
                    sudo ./sshrd.sh --restore-activation
                fi
                read -p "would you like to install TrollStore (strongly recommended, if you want to sideload on this version)? (Y/n): " install_troll
                if [[ $install_troll == Y || $install_troll == y ]]; then
                    sudo ./sshrd.sh --install-trollstore
                fi
                sudo ./sshrd.sh reboot
                cd ..
                echo "activation records have been restored! now run ./surrealra1n.sh --boot $IOS_VERSION to boot"
                exit 1
            fi
        fi
        if [[ $IOS_VERSION == 14.* || $IOS_VERSION == 15.* ]]; then
            echo "This iOS/iPadOS version supports TrollStore"
            read -p "Would you like to install TrollStore (recommended, ignore if you've already installed TrollStore)? (y/n): " troll
            if [[ $troll == y ]]; then
                read -p "Press any key after your device is in DFU mode"
                sleep 4
                cd SSHRD_Script
                sudo ./sshrd.sh 14.3
                read -p "Was there an error while making the ramdisk? (y/n) " error_response
                if [[ $error_response == y ]]; then
                    sudo ./sshrd.sh 14.3
                else
                    echo ""
                fi
                sudo ./sshrd.sh boot
                sleep 10
                sudo ./sshrd.sh --install-trollstore
                sudo ./sshrd.sh reboot
                cd ..
                echo "TrollStore has been installed! now run ./surrealra1n.sh --boot $IOS_VERSION to boot"
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
