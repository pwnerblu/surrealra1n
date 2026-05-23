#!/usr/bin/env bash

prepare_runtime_environment() {
    echo "surrealra1n - $CURRENT_VERSION"
    echo "Tether Downgrader for some checkm8 64bit devices, iOS 7.0 - 16.6.1"
    echo ""
    echo "Uses latest SHSH blobs (for tethered downgrades)"
    echo "iSuns9 fork of asr64_patcher is used for patching ASR"
    echo "Huge thanks to bodyc1m (discord username: cashcart1capone) for iPod touch 6 support, including the Arch Linux port they did."
    echo "Huge thanks to Mineek for openra1n and seprmvr64."

    # Request sudo password upfront
    echo "Enter your user password when prompted to"
    sudo -v || exit 1

    macmodel=$(sysctl -n hw.model) || true

    # Outdated macOS ver check
    macos_ver=$(sw_vers -productVersion) || true

    dist=0

    JAILBREAK=0

    DISTRO="Unsupported"
    ARCH="$(uname -m)"

    # macOS detection
    if [[ "$(uname)" == "Darwin" ]]; then
        DISTRO="macOS"

        if [[ "$ARCH" == "arm64" ]]; then
            echo "You are running surrealra1n on an Apple Silicon Mac."
            echo "Please read the following guide before continuing: https://github.com/pwnerblu/surrealra1n/wiki/Getting-started-with-surrealra1n-(macOS)"
            read -n 1 -s -r -p "Press any key to continue"
            dist=3
            echo
        elif [[ "$ARCH" == "x86_64" ]]; then
            echo "You are running surrealra1n on Intel macOS."
            echo "Please read the following guide before continuing: https://github.com/pwnerblu/surrealra1n/wiki/Getting-started-with-surrealra1n-(macOS)"
            read -n 1 -s -r -p "Press any key to continue"
            dist=4
            echo
        fi

    # Linux detection
    elif [[ -r /etc/os-release ]]; then
        . /etc/os-release

        if [[ "$ID" == "arch" || "$ID_LIKE" == *arch* ]]; then
            DISTRO="Arch"
            dist=2
        elif [[ "$ID" == "debian" || "$ID_LIKE" == *debian* ]]; then
            DISTRO="Debian"
            dist=1
            read -n 1 -s -r -p "Press any key to continue"
        fi
    fi

    if [[ $dist == 3 || $dist == 4 ]] && [[ "$(printf) '%s\n' "10.11" "$macos_ver" | sort -V | head -n1)" != "$macos_ver" ]]; then
        echo "Your macOS version $macos_ver is supported."
    else
        echo "surrealra1n only supports macOS versions after 10.11. Learn more at https://github.com/pwnerblu/surrealra1n"
        echo "You can continue however features WILL be broken."
        echo "Your macOS X version:$macos_ver"
        read -n 1 -s -r -p "Press any key to continue"
        echo
    fi

    if [[ "$macmodel" == "Mac17,5" ]]; then
        echo "There is a problem with the MacBook Neo in which openra1n fails to compile."
        echo "You cannot boot jailbroken with palera1n on tethered downgrades without openra1n, however for everything else it should be fine."
        echo "It will be fixed soon enough."
        read -n 1 -s -r -p "Press any key to continue"
        echo
    fi


    # Unsupported check
    if [[ "$DISTRO" == "Unsupported" ]]; then
        echo "Unsupported Linux distribution."
        echo "This script only supports Debian-based, Arch-based and macOS systems."
        exit 1
    fi

    echo "Detected distro family: $DISTRO"

    if [[ $dist == 3 || $dist == 4 ]]; then
        zenity="./bin/zenity"
    else
        zenity="zenity"
    fi


    # Dependency check
    echo "Checking for required dependencies..."

    if [[ $dist == 1 ]]; then
        DEPENDENCIES=(libusb-1.0-0-dev libusbmuxd-tools libimobiledevice-utils usbmuxd zenity git curl make gcc)
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
    elif [[ "$DISTRO" == "unknown" ]]; then
        echo "Unsupported Linux distribution."
        echo "This script only supports Debian-based and Arch-based systems."
        exit 1
    fi

    #
    stat_size() {
        if stat -c %s "$1" >/dev/null 2>&1; then
            stat -c %s "$1"     # Linux (GNU)
        else
            stat -f %z "$1"     # macOS / BSD
        fi
    }

    find_dmg() {
        dir="$1"          # directory to search
        mode="$2"         # smallest | largest
        max_size="${3:-}"     # optional (bytes)

        find "$dir" -type f -name '*.dmg' ! -name '._*' -print |
        while IFS= read -r f; do
            size=$(stat_size "$f") || continue
            if [[ -n "$max_size" && "$size" -ge "$max_size" ]]; then
                continue
            fi
            printf '%s %s\n' "$size" "$f"
        done |
        if [[ "$mode" == "smallest" ]]; then
            sort -n
        else
            sort -nr
        fi |
        head -n 1 |
        cut -d' ' -f2-
    }

    # boot file error handling improvements

    require_file() {
        if [[ ! -f "$1" ]]; then
            echo "[!] Required file missing: $1"
            exit 1
        fi
    }

    require_dir() {
        if [[ ! -d "$1" ]]; then
            echo "[!] Required directory missing: $1"
            exit 1
        fi
    }

    #

    # Updates are handled centrally by scripts/core/lib/auto_update.sh.

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
          -f "./bin/pzb" && \
          -f "./bin/zenity" && \
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
    elif [[ $dist == 3 ]]; then
        echo "Binaries do not exist"
        echo "Downloading binaries..."

        mkdir -p bin futurerestore

        curl -L -o bin/img4 https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/img4
        curl -L -o bin/img4tool https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/img4tool
        curl -L -o bin/pzb https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/pzb
        curl -L -o bin/KPlooshFinder https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/KPlooshFinder
        curl -L -o bin/dsc64patcher https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/dsc64patcher
        curl -L -o bin/kerneldiff https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/kerneldiff
        curl -L -o bin/irecovery https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/irecovery
        curl -L -o bin/iBoot64Patcher https://github.com/edwin170/downr1n/raw/refs/heads/main/binaries/Darwin/iBoot64Patcher
        curl -L -o bin/Kernel64Patcher2 https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/Kernel64Patcher
        curl -L -o bin/hfsplus https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/macos/hfsplus
        curl -L -o bin/zenity https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/macos/zenity
        # sshpass
        curl -L -o bin/sshpass https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/macos/sshpass
        curl -L -o bin/dmg https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/dmg
        curl -L -o bin/ipatcher https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/iPatcher
        # install additional restored_external patcher (iPhone X only)
        curl -L -o bin/ipx_restored_patcher https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/macos/arm64/ipx_restored_patcher
        # restored patcher for seprmvr64 A8+ restores, my fork of mineek's restored patcher but repurposed
        curl -L -o main.c https://gist.githubusercontent.com/pwnerblu/d2adc5adee74a679704577ddd64508bf/raw/991a74e2bbbdebdb1dd2d49d82f0829e7553f02f/main.c
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
        # install libimg4 patcher for tethered restores to iOS 14/15, primarily convert to localboot
        git clone https://github.com/iSuns9/libimg4_patcher --recursive
        cd libimg4_patcher
        make
        mv libimg4_patcher ../bin/libimg4_patcher
        cd ..
        rm -rf "libimg4_patcher"
        # the favor goes to openra1n by Mineek (pongoOS on unsigned bootchains), uses Nick Chan fork of openra1n
        git clone https://github.com/asdfugil/openra1n -b ipad6
        cd openra1n
        curl -L -o Makefile https://github.com/mineek/openra1n/raw/refs/heads/sigcheck/Makefile
        make || true
        mv openra1n ../bin/openra1n || true
        cd ..
        rm -rf "openra1n"
        # palera1n macOS bin
        curl -L -o bin/palera1n https://github.com/palera1n/palera1n/releases/download/v2.2.1/palera1n-macos-universal
        # install Kernel64Patcher for tether booting iOS 13+
        curl -L -o bin/Kernel64Patcher https://github.com/edwin170/downr1n/raw/refs/heads/main/binaries/Darwin/Kernel64Patcher
        curl -L -o bin/gaster https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/macos/gaster
        curl -L -o bin/tsschecker https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/macos/tsschecker
        curl -L -o bin/ldid https://github.com/ProcursusTeam/ldid/releases/download/v2.1.5-procursus7/ldid_macosx_arm64
        curl -L -o bin/kairos https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/kairos
        # download activate.sh and backup.sh from hiylx's eclipsera1n, for backing up and restoring iOS 16+ activation files on 14.0-15.7(.2)
        curl -L -o activate.sh https://github.com/hiylx/eclipsera1n/raw/refs/heads/main/activate.sh
        curl -L -o backup.sh https://github.com/hiylx/eclipsera1n/raw/refs/heads/main/backup.sh
        curl -L -o futurerestore/futurerestore.zip https://github.com/LukeeGD/futurerestore/releases/download/latest/futurerestore-macOS-RELEASE-main.zip
        # fetch idevicerestore for 7.0-9.3.5 restores 
        curl -L -o bin/idevicerestore https://github.com/NyanSatan/SundanceInH2A/raw/refs/heads/master/executables/Darwin/idevicerestore
        # libs
        chmod +x bin/*
        chmod +x *.sh

        cd futurerestore || exit
        unzip -o futurerestore.zip
        tar -xf futurerestore-macOS-v2.0.0-Build_329-RELEASE.tar.xz
        cp futurerestore-macOS-v2.0.0-Build_329-RELEASE/* . || true
        chmod +x futurerestore
        rm -rf *.tar.xz
        rm -rf *.sh
        rm -rf *.zip
        rm -rf "futurerestore-macOS-v2.0.0-Build_329-RELEASE" 
        cd ..
        xattr -c bin/*
        xattr -c futurerestore/futurerestore
    elif [[ $dist == 4 ]]; then
        echo "Binaries do not exist"
        echo "Downloading binaries..."

        mkdir -p bin futurerestore

        curl -L -o bin/img4 https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/img4
        curl -L -o bin/img4tool https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/img4tool
        curl -L -o bin/pzb https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/pzb
        curl -L -o bin/KPlooshFinder https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/KPlooshFinder
        curl -L -o bin/dsc64patcher https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/dsc64patcher
        curl -L -o bin/kerneldiff https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/kerneldiff
        curl -L -o bin/irecovery https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/irecovery
        curl -L -o bin/iBoot64Patcher https://github.com/edwin170/downr1n/raw/refs/heads/main/binaries/Darwin/iBoot64Patcher
        curl -L -o bin/Kernel64Patcher2 https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/Kernel64Patcher
        curl -L -o bin/hfsplus https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/macos/hfsplus
        curl -L -o bin/zenity https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/macos/zenity
        # sshpass
        curl -L -o bin/sshpass https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/macos/sshpass
        curl -L -o bin/dmg https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/dmg
        curl -L -o bin/ipatcher https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/iPatcher
        # install additional restored_external patcher (iPhone X only)
        curl -L -o bin/ipx_restored_patcher https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/macos/ipx_restored_patcher
        # palera1n macOS bin
        curl -L -o bin/palera1n https://github.com/palera1n/palera1n/releases/download/v2.2.1/palera1n-macos-universal
        # the favor goes to openra1n by Mineek (pongoOS on unsigned bootchains), uses Nick Chan fork of openra1n
        git clone https://github.com/asdfugil/openra1n -b ipad6
        cd openra1n
        curl -L -o Makefile https://github.com/mineek/openra1n/raw/refs/heads/sigcheck/Makefile
        make OBJCOPY=$(brew --prefix)/opt/binutils/bin/gobjcopy || true
        mv openra1n ../bin/openra1n || true
        cd ..
        rm -rf "openra1n" 
        # restored patcher for seprmvr64 A8+ restores, my fork of mineek's restored patcher but repurposed
        curl -L -o main.c https://gist.githubusercontent.com/pwnerblu/d2adc5adee74a679704577ddd64508bf/raw/991a74e2bbbdebdb1dd2d49d82f0829e7553f02f/main.c
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
        # install libimg4 patcher for tethered restores to iOS 14/15, primarily convert to localboot
        git clone https://github.com/iSuns9/libimg4_patcher --recursive
        cd libimg4_patcher
        make
        mv libimg4_patcher ../bin/libimg4_patcher
        cd ..
        rm -rf "libimg4_patcher"
        # install Kernel64Patcher for tether booting iOS 13+
        curl -L -o bin/Kernel64Patcher https://github.com/edwin170/downr1n/raw/refs/heads/main/binaries/Darwin/Kernel64Patcher
        curl -L -o bin/gaster https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/macos/gaster
        curl -L -o bin/tsschecker https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/macos/tsschecker
        curl -L -o bin/ldid https://github.com/ProcursusTeam/ldid/releases/download/v2.1.5-procursus7/ldid_macosx_x86_64
        curl -L -o bin/kairos https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/kairos
        # download activate.sh and backup.sh from hiylx's eclipsera1n, for backing up and restoring iOS 16+ activation files on 14.0-15.7(.2)
        curl -L -o activate.sh https://github.com/hiylx/eclipsera1n/raw/refs/heads/main/activate.sh
        curl -L -o backup.sh https://github.com/hiylx/eclipsera1n/raw/refs/heads/main/backup.sh
        curl -L -o futurerestore/futurerestore.zip https://github.com/LukeeGD/futurerestore/releases/download/latest/futurerestore-macOS-RELEASE-main.zip
        # fetch idevicerestore for 7.0-9.3.5 restores 
        curl -L -o bin/idevicerestore https://github.com/NyanSatan/SundanceInH2A/raw/refs/heads/master/executables/Darwin/idevicerestore
        # libs
        chmod +x bin/*
        chmod +x *.sh

        cd futurerestore || exit
        unzip -o futurerestore.zip
        tar -xf futurerestore-macOS-v2.0.0-Build_329-RELEASE.tar.xz
        cp futurerestore-macOS-v2.0.0-Build_329-RELEASE/* . || true
        chmod +x futurerestore
        rm -rf *.tar.xz
        rm -rf *.sh
        rm -rf *.zip
        rm -rf "futurerestore-macOS-v2.0.0-Build_329-RELEASE" 
        cd ..
        xattr -c bin/*
        xattr -c futurerestore/futurerestore
    else
        echo "Binaries do not exist"
        echo "Downloading binaries..."

        mkdir -p bin futurerestore

        curl -L -o bin/img4 https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/img4
        curl -L -o bin/img4tool https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/img4tool
        curl -L -o bin/KPlooshFinder https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/KPlooshFinder
        curl -L -o bin/pzb https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/pzb
        curl -L -o bin/dsc64patcher https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/dsc64patcher
        curl -L -o bin/kerneldiff https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/kerneldiff
        curl -L -o bin/irecovery https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/irecovery
        curl -L -o bin/iBoot64Patcher https://github.com/edwin170/downr1n/raw/refs/heads/main/binaries/Linux/iBoot64Patcher
        curl -L -o bin/Kernel64Patcher2 https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/Kernel64Patcher
        curl -L -o bin/hfsplus https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/hfsplus
        # sshpass
        curl -L -o bin/sshpass https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/linux/x86_64/sshpass
        curl -L -o bin/zenity https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/linux/x86_64/zenity
        curl -L -o bin/dmg https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/dmg
        curl -L -o bin/ipatcher https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/ipatcher
        # install additional restored_external patcher (iPhone X only)
        curl -L -o bin/ipx_restored_patcher https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/linux/x86_64/ipx_restored_patcher
        # restored patcher for seprmvr64 A8+ restores, my fork of mineek's restored patcher but repurposed
        curl -L -o main.c https://gist.githubusercontent.com/pwnerblu/d2adc5adee74a679704577ddd64508bf/raw/991a74e2bbbdebdb1dd2d49d82f0829e7553f02f/main.c
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
        # install libimg4 patcher for tethered restores to iOS 14/15, primarily convert to localboot
        git clone https://github.com/iSuns9/libimg4_patcher --recursive
        cd libimg4_patcher
        make
        mv libimg4_patcher ../bin/libimg4_patcher
        cd ..
        rm -rf "libimg4_patcher"
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
        tar -xf futurerestore-Linux-x86_64-v2.0.0-Build_329-RELEASE.tar.xz
        cp futurerestore-Linux-x86_64-v2.0.0-Build_329-RELEASE/* . || true
        chmod +x linux_fix.sh || true
        sudo ./linux_fix.sh || true
        rm -rf linux_fix.sh || true
        chmod +x futurerestore
        rm -rf *.tar.xz || true
        rm -rf *.sh || true
        rm -rf *.zip || true
        rm -rf "futurerestore-Linux-x86_64-v2.0.0-Build_329-RELEASE" 
        cd ..
    fi


}
