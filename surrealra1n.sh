#!/bin/bash
CURRENT_VERSION="v2.0 beta 6"

if [ "$EUID" -eq 0 ]; then
  echo "ERROR: Do not run this script with sudo or as root."
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

clear

IPSW_PATH=""
IPSW_PATH_LATEST=""
SHSH_PATH=""
dfu_instructions=""
restorefiles_remake=""
VERSION=""
BUILD=""
VERSION_LATEST=""
outdated=""

set -euo pipefail

error_handler() {
    local exit_code=$?
    local failed_command="$BASH_COMMAND"
    local line_number="${BASH_LINENO[0]}"
    local script_file="${BASH_SOURCE[1]:-$0}"

    {
        echo "[!] surrealra1n has crashed due to an issue"
        echo "[!] Exit code: $exit_code"
        echo "[!] Script: $script_file"
        echo "[!] Line: $line_number"
        echo "[!] Failed command: $failed_command"
        echo
        echo "[!] It is recommended to report this issue here:"
        echo "    https://github.com/pwnerblu/surrealra1n/issues"
        echo "Here's the recommended way to report this:"
        echo "Title should be a brief and clear summary of the issue you are trying to report"
        echo "Issue description should mention all relevant details to such issue if possible, and also a full terminal log attached."
        echo "[!] Issues THAT DO NOT CONTAIN PROPER LOGS, DETAILS, OR ANYTHING RELEVANT, WILL BE CLOSED AS INVALID."
        echo 
        echo "[!] To attach this log into your issue, do the following:"
        if [[ $dist == 3 || $dist == 4 ]]; then
            echo "Cmd + A -> Cmd + C, then paste the entire log into your issue you're opening"
        else
            echo "Ctrl + Shift + A -> Ctrl + Shift + C, then paste the entire log into the issue you're opening"
        fi
    } 

    exit "$exit_code"
}

trap 'error_handler $LINENO' ERR

echo "Your surrealra1n version: $CURRENT_VERSION"
# Request sudo password upfront
echo "Enter your user password when prompted to"
sudo -v || exit 1

sudo rm -rf "tmp"
sudo rm -rf "tmp1"
sudo rm -rf "tmp2"
sudo rm -rf "work"

dist=0

JAILBREAK=0

DISTRO="Unsupported"
ARCH="$(uname -m)"

# macOS detection
if [[ "$(uname)" == "Darwin" ]]; then
    DISTRO="macOS"
    if [[ "$ARCH" == "arm64" ]]; then
        echo "You are running surrealra1n on an Apple Silicon Mac."
        dist=3
        echo
    elif [[ "$ARCH" == "x86_64" ]]; then
        echo "You are running surrealra1n on Intel macOS."
        dist=4
        echo
    fi
# Linux detection
elif [[ -r /etc/os-release ]]; then
    . /etc/os-release

    if [[ "$ID" == "arch" || "${ID_LIKE:-}" == *arch* ]]; then
        DISTRO="Arch"
        dist=2
    elif [[ "$ID" == "debian" || "${ID_LIKE:-}" == *debian* ]]; then
        DISTRO="Debian"
        dist=1
        read -n 1 -s -r -p "Press any key to continue"
    elif [[ "$ID" == "fedora" || "${ID_LIKE:-}" == *fedora* || "${ID_LIKE:-}" == *rhel* ]]; then
        DISTRO="Fedora"
        dist=5
        read -n 1 -s -r -p "Press any key to continue"
    # generic Linux fallback
    elif command -v apt-get &>/dev/null; then
        DISTRO="Debian"
        dist=1
        echo "Unrecognized distro; treating as Debian-based (apt-get detected)."
        read -n 1 -s -r -p "Press any key to continue"
    elif command -v pacman &>/dev/null; then
        DISTRO="Arch"
        dist=2
        echo "Unrecognized distro; treating as Arch-based (pacman detected)."
    elif command -v dnf &>/dev/null; then
        DISTRO="Fedora"
        dist=5
        echo "Unrecognized distro; treating as Fedora-based (dnf detected)."
        read -n 1 -s -r -p "Press any key to continue"
    elif command -v zypper &>/dev/null; then
        DISTRO="Fedora"
        dist=5
        echo "Unrecognized distro; treating as Fedora-based (zypper detected, using dnf flow)."
        read -n 1 -s -r -p "Press any key to continue"
    fi
fi

if [[ $dist == 3 || $dist == 4 ]]; then
    # prevent finder from annoying you
    killall -STOP AMPDevicesAgent AMPDeviceDiscoveryAgent MobileDeviceUpdater 2>/dev/null
fi

# Run macOS version check only if you're on macOS, should fix Linux
if [[ $dist == 3 || $dist == 4 ]]; then
    macmodel=$(sysctl -n hw.model) 

    # Outdated macOS ver check
    macos_ver=$(sw_vers -productVersion) 
fi

if [[ $dist == 3 || $dist == 4 ]]; then
    if [[ "$(printf '%s\n' "10.15" "$macos_ver" | sort -V | head -n1)" == "10.15" ]]; then
        echo "Your macOS version $macos_ver is supported."
    else
        echo "surrealra1n only supports macOS 10.15 and later."
        exit 1
    fi
fi

if [[ $dist == 3 || $dist == 4 ]]; then
    # Check for Xcode Command Line Tools
    if ! xcode-select -p &>/dev/null; then
        echo "Xcode Command Line Tools are not installed. Installing..."
        xcode-select --install
        echo "Please re-run surrealra1n after the installation completes."
        exit 1
    else
        echo "Xcode Command Line Tools are installed."
    fi

    # Check for Homebrew
    if ! command -v brew &>/dev/null; then
        echo "[!] Homebrew is not installed. You will need to install Homebrew from https://brew.sh"
        exit 1
    else
        echo "Homebrew is installed."
    fi

    # Check for missing brew dependencies
    BREW_DEPS=("libimobiledevice" "libirecovery" "binutils")
    for dep in "${BREW_DEPS[@]}"; do
        if ! brew list "$dep" &>/dev/null; then
            echo "[$dep] is not installed. Installing..."
            brew install "$dep"
        else
            echo "[$dep] is installed."
        fi
    done
fi

# Check for Rosetta 2 (Apple Silicon only)
if [[ $dist == 3 ]]; then
    if ! /usr/bin/pgrep -q oahd; then
        echo "Rosetta 2 is not installed. Installing..."
        softwareupdate --install-rosetta --agree-to-license
    else
        echo "Rosetta 2 is installed."
    fi
fi

# Unsupported check
if [[ "$DISTRO" == "Unsupported" ]]; then
    echo "Unsupported Linux distribution."
    echo "Could not detect a compatible package manager (apt-get, pacman, dnf, or zypper)."
    echo "This script only supports Debian-based, Arch-based, Fedora-based and macOS systems."
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
        sudo apt update || true # issue workarounds
        sudo apt install -y "${MISSING_PACKAGES[@]}" || true # issue workarounds
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
elif [[ $dist == 5 ]]; then
    DEPENDENCIES=(libusb1-devel usbmuxd libimobiledevice-utils zenity git curl make gcc)
    MISSING_PACKAGES=()

    for pkg in "${DEPENDENCIES[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            MISSING_PACKAGES+=("$pkg")
        fi
    done

    if [ ${#MISSING_PACKAGES[@]} -ne 0 ]; then
        echo "Missing packages detected: ${MISSING_PACKAGES[*]}"
        echo "Installing missing dependencies..."
        sudo dnf install -y "${MISSING_PACKAGES[@]}"
    else
        echo "All dependencies are already installed."
    fi
elif [[ "$DISTRO" == "unknown" ]]; then
    echo "Unsupported Linux distribution."
    echo "This script only supports Debian-based, Arch-based, Fedora-based and macOS systems."
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

    find "$dir" -type f -name '*.dmg*' ! -name '._*' -print |
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

echo "Checking for updates..."
rm -rf update/latest.txt
curl -L -o update/latest.txt https://github.com/pwnerblu/surrealra1n/raw/refs/heads/development/update/latest.txt
LATEST_VERSION=$(head -n 1 "update/latest.txt" | tr -d '\r\n')
RELEASE_NOTES=$(awk '/^RELEASE NOTES:/{flag=1; next} flag' "update/latest.txt")

if [[ $LATEST_VERSION == $CURRENT_VERSION ]]; then
    echo "A new version of surrealra1n is available: $LATEST_VERSION"
    echo "RELEASE NOTES:"
    echo "$RELEASE_NOTES"
    echo ""
    echo "It is strongly recommended to update to get the latest features + bug fixes."
    read -p "Would you like to update now? (y/n): " update
    if [[ $update == y || $update == Y ]]; then
        rm -rf "updatefiles"
        mkdir updatefiles
        rm -rf "updatefiles/repo"
        git clone --branch development https://github.com/pwnerblu/surrealra1n updatefiles/repo --recursive
        if [[ ! -d updatefiles/repo ]]; then
            echo "Failed to clone repository."
            exit 1
        fi
        rm -rf "surrealra1n.old"
        mkdir -p surrealra1n.old # make folder to back up old surrealra1n installation
        echo "$CURRENT_VERSION" > surrealra1n.old/oldversion.txt
        echo "Backing up your current surrealra1n installation..."
        mv -v bin surrealra1n.old/
        mv -v futurerestore surrealra1n.old/
        mv -v keys surrealra1n.old/
        mv -v surrealra1n.sh surrealra1n.old/
        rm -rf "bin"
        rm -rf "futurerestore"
        rm -rf "keys"
        echo "Copying new files..."
        cp -av updatefiles/repo/. ./
        chmod +x surrealra1n.sh

        rm -rf "updatefiles"
        echo "surrealra1n has been updated! Please run the script again"
        exit 0
    else
        echo "You have declined the update."
        echo "This version of surrealra1n is no longer supported, so it is recommended to update as soon as possible."
        outdated=1
        read -p "Press enter to continue"
    fi
else
    echo "surrealra1n is up to date."
    sleep 1
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
      -f "./bin/iproxy" && \
      -f "./bin/dtree_patcher" && \
      -f "./bin/sshpass" && \
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
    curl -L -o bin/dtree_patcher https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/dtree_patcher
    curl -L -o bin/irecovery https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/irecovery
    curl -L -o bin/iBoot64Patcher https://github.com/edwin170/downr1n/raw/refs/heads/main/binaries/Darwin/iBoot64Patcher
    curl -L -o bin/Kernel64Patcher2 https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/Kernel64Patcher
    curl -L -o bin/hfsplus https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/macos/hfsplus
    curl -L -o bin/zenity https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/macos/zenity
    # sshpass
    curl -L -o bin/sshpass https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/macos/sshpass
    curl -L -o bin/iproxy https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/iproxy
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
    # fetch pwnerblu fork of Kernel64Patcher and iBootpatch2 for tether booting iOS 14.x on A12 device.
    git clone https://github.com/pwnerblu/Kernel64Patcher --recursive
    cd Kernel64Patcher
    make
    cp Kernel64Patcher ../bin/Kernel64Patcher3
    cd ..
    rm -rf "Kernel64Patcher"
    git clone https://github.com/pwnerblu/iBootpatch2 -b ipad6
    cd iBootpatch2
    make
    cp iBootpatch2 ../bin/iBootpatch2
    cd ..
    rm -rf "iBootpatch2"
    # done!
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
    curl -L -o bin/dtree_patcher https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/dtree_patcher
    curl -L -o bin/irecovery https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/irecovery
    curl -L -o bin/iBoot64Patcher https://github.com/edwin170/downr1n/raw/refs/heads/main/binaries/Darwin/iBoot64Patcher
    curl -L -o bin/Kernel64Patcher2 https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/Kernel64Patcher
    curl -L -o bin/hfsplus https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/macos/hfsplus
    curl -L -o bin/zenity https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/macos/zenity
    # sshpass
    curl -L -o bin/sshpass https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/macos/sshpass
    curl -L -o bin/iproxy https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Darwin/iproxy
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
    # fetch pwnerblu fork of Kernel64Patcher and iBootpatch2 for tether booting iOS 14.x on A12 device.
    git clone https://github.com/pwnerblu/Kernel64Patcher --recursive
    cd Kernel64Patcher
    make
    cp Kernel64Patcher ../bin/Kernel64Patcher3
    cd ..
    rm -rf "Kernel64Patcher"
    git clone https://github.com/pwnerblu/iBootpatch2 -b ipad6
    cd iBootpatch2
    make
    cp iBootpatch2 ../bin/iBootpatch2
    cd ..
    rm -rf "iBootpatch2"
    # done!
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
    curl -L -o bin/dtree_patcher https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/dtree_patcher
    curl -L -o bin/irecovery https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/irecovery
    curl -L -o bin/iBoot64Patcher https://github.com/edwin170/downr1n/raw/refs/heads/main/binaries/Linux/iBoot64Patcher
    curl -L -o bin/Kernel64Patcher2 https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/Kernel64Patcher
    curl -L -o bin/hfsplus https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/hfsplus
    # sshpass
    curl -L -o bin/sshpass https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/linux/x86_64/sshpass
    curl -L -o bin/iproxy https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/Linux/iproxy
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

echo "Checking for dependencies that are required for usbliter8ctl, assuming Python3 is on your system"
# Check required packages
PACKAGES=("pyusb")
for pkg in "${PACKAGES[@]}"; do
    if pip3 show "$pkg" &>/dev/null; then
        version=$(pip3 show "$pkg" | grep Version | awk '{print $2}')
        echo "$pkg: $version"
    else
        echo "$pkg not installed"
        echo "Running: pip3 install $pkg"
        if pip3 install "$pkg" 2>&1 | grep -q "externally-managed"; then
            echo "Externally managed environment detected, retrying with --break-system-packages"
            pip3 install "$pkg" --break-system-packages
        fi
    fi
done

IDEVICE_INFO=$(ideviceinfo 2>&1) || true
IDEVICE_STATUS=$?
if [[ $IDEVICE_STATUS -eq 0 && "$IDEVICE_INFO" != *"No device found!"* && "$IDEVICE_INFO" != *"ERROR:"* ]]; then
    IDENTIFIER=$(echo "$IDEVICE_INFO" | grep "^ProductType:" | cut -d ':' -f2 | xargs)
    ECID=$(echo "$IDEVICE_INFO" | grep "^UniqueChipID:" | cut -d ':' -f2 | xargs)
    SERIAL=$(echo "$IDEVICE_INFO" | grep "^SerialNumber:" | cut -d ':' -f2 | xargs)
    DEVICE_VERSION=$(echo "$IDEVICE_INFO" | grep "^ProductVersion:" | cut -d ':' -f2 | xargs)
    MODE="Normal"
elif [[ $IDEVICE_STATUS -ne 0 && "$IDEVICE_INFO" != *"No device found!"* ]] || [[ "$IDEVICE_INFO" == *"ERROR:"* && "$IDEVICE_INFO" != *"No device found!"* ]]; then
    # ideviceinfo ran but failed for another reason, try -s
    IDEVICE_INFO=$(ideviceinfo -s 2>&1) || true
    IDEVICE_STATUS=$?
    if [[ $IDEVICE_STATUS -eq 0 && "$IDEVICE_INFO" != *"No device found!"* ]]; then
        IDENTIFIER=$(echo "$IDEVICE_INFO" | grep "^ProductType:" | cut -d ':' -f2 | xargs)
        ECID=$(echo "$IDEVICE_INFO" | grep "^UniqueChipID:" | cut -d ':' -f2 | xargs)
        DEVICE_VERSION=$(echo "$IDEVICE_INFO" | grep "^ProductVersion:" | cut -d ':' -f2 | xargs)
        SERIAL="none"
        MODE="Normal"
    else
        echo "ideviceinfo failed after two attempts."
        exit 1
    fi
else
    echo "[*] Device is not in normal mode. Trying recovery/DFU mode..."
    # Try irecovery
    IRECOVERY_INFO=$(./bin/irecovery -q 2>/dev/null) || true
    if [[ -n "$IRECOVERY_INFO" ]]; then
        echo "[*] Device is in Recovery or DFU mode."
        IDENTIFIER=$(echo "$IRECOVERY_INFO" | grep "^PRODUCT:" | cut -d ':' -f2 | xargs)
        ECID=$(echo "$IRECOVERY_INFO" | grep "^ECID:" | cut -d ':' -f2 | xargs)
        MODE=$(echo "$IRECOVERY_INFO" | grep "^MODE:" | cut -d ':' -f2 | xargs)
        echo "[+] Device Identifier: $IDENTIFIER"
        echo "[+] ECID: $ECID"
    else
        echo "[!] No device detected in normal or recovery mode."
        IDENTIFIER="NONE"
        MODE="None"
        ECID="None"
        REFER2=""
        BOARDID2=""
        REFER=""
        BOARDID=""
        NAME="No device"
    fi
fi

if [[ -d "seprmvr64boot" ]]; then
    mkdir -p boot
    mv -v seprmvr64boot/* boot/
    rm -rf "seprmvr64boot"
fi

if [[ $IDENTIFIER == iPad4,7 || $IDENTIFIER == iPad4,8 || $IDENTIFIER == iPad4,9 ]]; then
    echo "iPad mini 3 is not supported yet"
    exit 1
fi

KEY_FILE="keys/$IDENTIFIER.txt"

# BB update determine check

if [[ $IDENTIFIER == iPhone* || $IDENTIFIER == iPad4,2 || $IDENTIFIER == iPad4,3 || $IDENTIFIER == iPad4,5 || $IDENTIFIER == iPad4,6 || $IDENTIFIER == iPad4,8 || $IDENTIFIER == iPad4,9 || $IDENTIFIER == iPad5,2 || $IDENTIFIER == iPad5,4 ]]; then
    updatebb_flag="--latest-baseband"
elif [[ $IDENTIFIER == iPod* || $IDENTIFIER == iPad4,1 || $IDENTIFIER == iPad4,4 || $IDENTIFIER == iPad4,7 || $IDENTIFIER == iPad5,1 || $IDENTIFIER == iPad5,3 ]]; then
    updatebb_flag="--no-baseband"
fi

# changes to device detection stuff

if [[ $IDENTIFIER == iPhone6* ]]; then
    REFER="iphone6"
    REFER2="iphone6"
elif [[ $IDENTIFIER == iPhone7* ]]; then
    REFER="iphone7"
elif [[ $IDENTIFIER == iPod7* ]]; then
    REFER="n102"
    REFER2="n102"
    BOARDID="n102ap"
    BOARDID2="n102"
    NAME="iPod touch 6 ($BOARDID) - $IDENTIFIER"
elif [[ $IDENTIFIER == iPhone11,8 ]]; then
    REFER="iphone11b"
    REFER2="n841"
    BOARDID="n841ap"
    BOARDID2="n841"
    NAME="iPhone XR ($BOARDID)"
    AOP14="aopfw-iphone11baop.im4p"
    AOP="aopfw-iphone11baop.RELEASE.im4p"
    IOFW="SmartIOFirmware_ASCv2.im4p"
    GFX="armfw_g11p.im4p"
    ISP="adc-petra-n84.im4p"
    ANE="h11_ane_fw_quin.im4p"
    AVE="AppleAVE2FW_H11.im4p"
    CALLAN="N841_CallanFirmware.im4p"
    HAPTICASSET="N841_HapticAssets.im4p"
    MTFW="N841_Multitouch.im4p"
    WIRELESS="WirelessPower.iphone11b.im4p"
    KERNEL2="kernelcache.release.iphone11x"
elif [[ $IDENTIFIER == iPhone10,1 || $IDENTIFIER == iPhone10,4 || $IDENTIFIER == iPhone10,2 || $IDENTIFIER == iPhone10,5 ]]; then
    REFER="iphone10"
elif [[ $IDENTIFIER == iPhone10,3 || $IDENTIFIER == iPhone10,6 ]]; then
    REFER="iphone10b"
elif [[ $IDENTIFIER == iPad4,1 || $IDENTIFIER == iPad4,2 || $IDENTIFIER == iPad4,3 ]]; then
    REFER="ipad4"
    REFER2="ipad4"
elif [[ $IDENTIFIER == iPad4,4 || $IDENTIFIER == iPad4,5 || $IDENTIFIER == iPad4,6 ]]; then
    REFER="ipad4b"
    REFER2="ipad4b"
elif [[ $IDENTIFIER == iPad4,7 || $IDENTIFIER == iPad4,8 || $IDENTIFIER == iPad4,9 ]]; then
    REFER="ipad4bm"
    REFER2="ipad4bm"
elif [[ $IDENTIFIER == iPad5,1 || $IDENTIFIER == iPad5,2 ]]; then
    REFER="ipad5"
    REFER2="ipad5"
elif [[ $IDENTIFIER == iPad5,3 || $IDENTIFIER == iPad5,4 ]]; then
    REFER="ipad5b"
    REFER2="ipad5b"
else
    echo "Unsupported device"
    exit 1
fi

if [[ $IDENTIFIER == iPhone6,1 ]]; then
    BOARDID="n51ap"
    BOARDID2="n51"
    NAME="iPhone 5S (GSM, $BOARDID) - $IDENTIFIER"
elif [[ $IDENTIFIER == iPhone6,2 ]]; then
    BOARDID="n53ap"
    BOARDID2="n53"
    NAME="iPhone 5S (Global, $BOARDID) - $IDENTIFIER"
elif [[ $IDENTIFIER == iPhone7,2 ]]; then
    BOARDID="n61ap"
    BOARDID2="n61"
    REFER2="$BOARDID2"
    NAME="iPhone 6 ($BOARDID) - $IDENTIFIER"
elif [[ $IDENTIFIER == iPhone7,1 ]]; then
    BOARDID="n56ap"
    BOARDID2="n56"
    REFER2="$BOARDID2"
    NAME="iPhone 6 Plus ($BOARDID) - $IDENTIFIER"
elif [[ $IDENTIFIER == iPhone10,1 ]]; then
    BOARDID="d20ap"
    BOARDID2="d20"
    REFER2="$BOARDID2"
    NAME="iPhone 8 (Global, $BOARDID) - $IDENTIFIER"
elif [[ $IDENTIFIER == iPhone10,4 ]]; then
    BOARDID="d201ap"
    BOARDID2="d20"
    REFER2="$BOARDID2"
    NAME="iPhone 8 (GSM, $BOARDID) - $IDENTIFIER"
elif [[ $IDENTIFIER == iPhone10,2 ]]; then
    BOARDID="d21ap"
    BOARDID2="d21"
    REFER2="$BOARDID2"
    NAME="iPhone 8 Plus (Global, $BOARDID) - $IDENTIFIER"
elif [[ $IDENTIFIER == iPhone10,5 ]]; then
    BOARDID="d211ap"
    BOARDID2="d21"
    REFER2="$BOARDID2"
    NAME="iPhone 8 Plus (GSM, $BOARDID) - $IDENTIFIER"
elif [[ $IDENTIFIER == iPhone10,3 ]]; then
    BOARDID="d22ap"
    BOARDID2="d22"
    REFER2="$BOARDID2"
    NAME="iPhone X (Global, $BOARDID) - $IDENTIFIER"
elif [[ $IDENTIFIER == iPhone10,6 ]]; then
    BOARDID="d221ap"
    BOARDID2="d22"
    REFER2="$BOARDID2"
    NAME="iPhone X (GSM, $BOARDID) - $IDENTIFIER"
elif [[ $IDENTIFIER == iPad4,1 ]]; then
    BOARDID="j71ap"
    BOARDID2="j71"
    NAME="iPad Air (Wi-Fi only, $BOARDID) - $IDENTIFIER"
elif [[ $IDENTIFIER == iPad4,2 ]]; then
    BOARDID="j72ap"
    BOARDID2="j72"
    NAME="iPad Air (Cellular, $BOARDID) - $IDENTIFIER"
elif [[ $IDENTIFIER == iPad4,3 ]]; then
    BOARDID="j73ap"
    BOARDID2="j73"
    NAME="iPad Air (China, $BOARDID) - $IDENTIFIER"
elif [[ $IDENTIFIER == iPad4,4 ]]; then
    BOARDID="j85ap"
    BOARDID2="j85"
    NAME="iPad mini 2 (Wi-Fi only, $BOARDID) - $IDENTIFIER"
elif [[ $IDENTIFIER == iPad4,5 ]]; then
    BOARDID="j86ap"
    BOARDID2="j86"
    NAME="iPad mini 2 (Cellular, $BOARDID) - $IDENTIFIER"
elif [[ $IDENTIFIER == iPad4,6 ]]; then
    BOARDID="j87ap"
    BOARDID2="j87"
    NAME="iPad mini 2 (China, $BOARDID) - $IDENTIFIER"
elif [[ $IDENTIFIER == iPad4,7 ]]; then
    BOARDID="j85map"
    BOARDID2="j85m"
    NAME="iPad mini 3 (Wi-Fi only, $BOARDID) - $IDENTIFIER"
elif [[ $IDENTIFIER == iPad4,8 ]]; then
    BOARDID="j86map"
    BOARDID2="j86m"
    NAME="iPad mini 3 (Cellular, $BOARDID) - $IDENTIFIER"
elif [[ $IDENTIFIER == iPad4,9 ]]; then
    BOARDID="j87map"
    BOARDID2="j87m"
    NAME="iPad mini 3 (China, $BOARDID) - $IDENTIFIER"
elif [[ $IDENTIFIER == iPad5,1 ]]; then
    BOARDID="j96ap"
    BOARDID2="j96"
    NAME="iPad mini 4 (Wi-Fi only, $BOARDID) - $IDENTIFIER"
elif [[ $IDENTIFIER == iPad5,2 ]]; then
    BOARDID="j97ap"
    BOARDID2="j97"
    NAME="iPad mini 4 (Cellular, $BOARDID) - $IDENTIFIER"
elif [[ $IDENTIFIER == iPad5,3 ]]; then
    BOARDID="j81ap"
    BOARDID2="j81"
    NAME="iPad Air 2 (Wi-Fi only, $BOARDID) - $IDENTIFIER"
elif [[ $IDENTIFIER == iPad5,4 ]]; then
    BOARDID="j82ap"
    BOARDID2="j82"
    NAME="iPad Air 2 (Cellular, $BOARDID) - $IDENTIFIER"
fi

if [[ $IDENTIFIER == iPad5* ]]; then
    LATEST_VERSION="15.8.8"
elif [[ $IDENTIFIER == iPhone10* ]]; then
    LATEST_VERSION="16.7.16"
elif [[ $IDENTIFIER == iPhone11* ]]; then
    LATEST_VERSION="18.7.9"
else
    LATEST_VERSION="12.5.8"
fi

IBSS="iBSS.$REFER2.RELEASE.im4p"
IBEC="iBEC.$REFER2.RELEASE.im4p"
LLB="LLB.$REFER2.RELEASE.im4p"
IBOOT="iBoot.$REFER2.RELEASE.im4p"
LLB10="LLB.$BOARDID2.RELEASE.im4p"
IBOOT10="iBoot.$BOARDID2.RELEASE.im4p"
DEVICETREE="DeviceTree.$BOARDID.im4p"
ALLFLASH="all_flash.$BOARDID.production"
KERNEL="kernelcache.release.$REFER"
IBSS10="iBSS.$BOARDID2.RELEASE.im4p"
IBEC10="iBEC.$BOARDID2.RELEASE.im4p"
IBSS7="iBSS.$BOARDID.RELEASE.im4p"
IBEC7="iBEC.$BOARDID.RELEASE.im4p"
KERNEL10="kernelcache.release.$BOARDID2"

INFO_TEXT="surrealra1n - $CURRENT_VERSION
Tether Downgrader for some checkm8 64bit devices, iOS 7.0 - 15.8.5
This build is an early beta. Use at your own risk, and expect bugs.

Uses latest SHSH blobs (for tethered downgrades)
iSuns9 fork of asr64_patcher is used for patching ASR
Huge thanks to bodyc1m for iPod touch 6 support, including the Arch Linux/Fedora port they did.
Huge thanks to Mineek for openra1n and seprmvr64.

Device: $NAME
ECID: $ECID

Device is in $MODE mode."

misc_utils(){

clear
echo "$INFO_TEXT"
echo ""
echo "Options:"
echo ""
echo "1. Reinstall surrealra1n"
echo "2. Clear all created boot files and restore files"
if [[ -d "surrealra1n.old" ]]; then
    echo "3. Go back to previous version of surrealra1n"
    echo "4. Back"
else
    echo "3. Back"
fi
if [[ -d "surrealra1n.old" ]]; then
    read -p "Please input an option (1-4): " misc_utils_options
else
    read -p "Please input an option (1-3): " misc_utils_options
fi
if [[ $misc_utils_options == 1 ]]; then
    echo "WARNING: All of your boot files, and other things will be deleted (if any files are in the surrealra1n directory, they will be erased), and surrealra1n will be fresh installed."
    read -p "Are you sure you want to reinstall surrealra1n? (y/N): " surrealra1n_reinstall
    if [[ $surrealra1n_reinstall == Y || $surrealra1n_reinstall == y ]]; then
        sudo rm -rf ./*
        git clone --branch development https://github.com/pwnerblu/surrealra1n repo --recursive
        if [[ ! -d repo ]]; then
            echo "Failed to clone repository. You will need to fetch surrealra1n from releases on GitHub"
            exit 1
        fi
        echo "Copying new files..."
        cp -av repo/. ./
        chmod +x surrealra1n.sh

        rm -rf "repo"
        echo "surrealra1n has been reinstalled! Please run the script again"
        exit 0
    else
        echo "surrealra1n reinstall has been canceled."
        misc_utils
    fi
elif [[ $misc_utils_options == 2 ]]; then
    echo "WARNING: All of your boot files and restore files will be deleted. You will need to re-create them afterwards if you proceed."
    echo "This may be useful if you want more disk space."
    read -p "Are you sure you want to clear these files? (y/N): " clear_files    
    if [[ $clear_files == y || $clear_files == Y ]]; then
        sudo rm -rf "boot"
        sudo rm -rf "restorefiles"
        sudo rm -rf "noseprestore"
    else
        echo "Clearing boot files/restore files has been canceled"
        misc_utils
    fi
elif [[ $misc_utils_options == 3 ]] && [[ -d "surrealra1n.old" ]]; then
    old_version=$(cat surrealra1n.old/oldversion.txt)
    if [[ "$old_version" == *beta* ]]; then
        echo "Rollback feature is not supported if you update from a beta."
        rm -rf "surrealra1n.old"
        sleep 4
        misc_utils
        return
    fi
    echo "WARNING: This will restore surrealra1n to the previous version backed up in surrealra1n.old."
    echo "Any new features from this surrealra1n release may not exist in the previous version"
    read -p "Are you sure you want to go back to the previous version? (y/N): " rollback_confirm
    if [[ $rollback_confirm == Y || $rollback_confirm == y ]]; then
        rm -rf "bin"
        rm -rf "futurerestore"
        rm -rf "keys"
        rm -rf surrealra1n.sh
        cp -av surrealra1n.old/. ./
        chmod +x surrealra1n.sh
        rm -rf "surrealra1n.old"
        echo "surrealra1n has been restored to the previous version! Please run the script again."
        echo "You can upgrade to the latest version at any time later if you want to be on latest again."
        exit 0
    else
        echo "Rollback has been canceled."
        misc_utils
    fi
elif [[ $misc_utils_options == 3 ]] || [[ $misc_utils_options == 4 ]]; then
    main_menu
else
    echo "Invalid option. Exiting."
    exit 1
fi

}

pwn_device(){

if [[ $IDENTIFIER == iPhone6* || $IDENTIFIER == iPad4* ]] && [[ $dist == 1 || $dist == 2 || $dist == 5 ]]; then
    echo "A7 devices may have issues pwning on Linux"
    echo "If you have a MacBook, use surrealra1n on that instead"
    echo "You may choose to continue attempting to pwn with Linux"
    read -p "Press enter to continue"
fi

echo "Checking if this device is in pwned DFU already"
irecovery_output=$(./bin/irecovery -q)
if echo "$irecovery_output" | grep -q "PWND"; then
    echo "Device is pwned!"
    if [[ $IDENTIFIER == iPhone11* || $IDENTIFIER == iPad11* ]]; then
        echo "Skipping gaster reset"
    else
        ./bin/gaster reset
    fi
    return
elif [[ $IDENTIFIER == iPhone11* || $IDENTIFIER == iPad11* ]]; then
    echo "Proceed to do the following:"
    echo "A12 tether downgrades are for advanced users only. If you don't know what you're doing, DO not proceed"
    echo "Disconnect your device from the computer, then connect it to your Pi Pico"
    echo "Make sure your Pi Pico has the custom firmware required to pwn the device with usbliter8."
    read -p "Press enter to continue once device is pwned successfully AND reconnected to the computer"
else
    echo "Device is not pwned yet, attempting to pwn"
    ./bin/gaster pwn 
    ./bin/gaster reset
    if [[ $IDENTIFIER == iPhone10,3 || $IDENTIFIER == iPhone10,6 ]]; then
        ./bin/irecovery -f surrealra1n.sh
        ./bin/gaster reset
    fi
fi

echo "Checking if this device has pwned successfully"
irecovery_output=$(./bin/irecovery -q)
if echo "$irecovery_output" | grep -q "PWND"; then
    echo "Device is pwned!"
else
    echo "Device has not pwned successfully"
    exit 1
fi

}

dfu_helper(){

if [[ $MODE == Normal || $MODE == Recovery ]]; then
    echo "You need to put your device into DFU mode."
    read -p "Would you like instructions on how to do this? (y/n): " dfu_instructions
    if [[ $dfu_instructions == y || $dfu_instructions == Y ]]; then
        echo "Instructions will begin in:"
        echo "3" && sleep 1 && echo "2" && sleep 1 && echo "1" && sleep 1
        echo "Hold power + home buttons." 
        echo "10" && sleep 1 && echo "9" && sleep 1 && echo "8" && sleep 1 && echo "7" && sleep 1 && echo "6" && sleep 1 && echo "5" && sleep 1 && echo "4" && sleep 1 && echo "3" && sleep 1 && echo "2" && sleep 1 && echo "1" && sleep 1
        echo "Release the power button now, but keep holding home button."
        echo "5" && sleep 1 && echo "4" && sleep 1 && echo "3" && sleep 1 && echo "2" && sleep 1 && echo "1" && sleep 1
    else
        echo "Put your device into DFU mode now"
    fi
fi

echo "Checking for DFU devices"
if [[ $dfu_instructions == Y || $dfu_instructions == y ]]; then
    MODE=$(./bin/irecovery -q | grep "^MODE:" | cut -d ':' -f2 | xargs) || true
    if [[ $MODE == DFU ]]; then
        echo "The device has entered DFU successfully!"
    else
        echo "Device has not entered DFU mode successfully"
        exit 1
    fi
else
    while true; do
      MODE=$(./bin/irecovery -q 2>/dev/null | grep "^MODE:" | cut -d ':' -f2 | xargs) || true
      if [ "$MODE" = "DFU" ]; then
        echo "Device is now in DFU mode!"
        break
      fi

      sleep 1
    done
fi

}

switch_to_main(){

echo "Fetching latest stable version info..."
curl -L -o update/latest_main.txt https://github.com/pwnerblu/surrealra1n/raw/refs/heads/main/update/latest.txt
MAIN_VERSION=$(head -n 1 "update/latest_main.txt" | tr -d '\r\n')

CURRENT_CLEAN=$(echo "$CURRENT_VERSION" | sed 's/ beta//g' | sed 's/ .*//g' | tr -d 'v')
MAIN_CLEAN=$(echo "$MAIN_VERSION" | sed 's/ beta//g' | sed 's/ .*//g' | tr -d 'v')

CURRENT_MAJOR=$(echo "$CURRENT_CLEAN" | cut -d'.' -f1)
CURRENT_MINOR=$(echo "$CURRENT_CLEAN" | cut -d'.' -f2)
CURRENT_PATCH=$(echo "$CURRENT_CLEAN" | cut -d'.' -f3)
CURRENT_PATCH=${CURRENT_PATCH:-0}

MAIN_MAJOR=$(echo "$MAIN_CLEAN" | cut -d'.' -f1)
MAIN_MINOR=$(echo "$MAIN_CLEAN" | cut -d'.' -f2)
MAIN_PATCH=$(echo "$MAIN_CLEAN" | cut -d'.' -f3)
MAIN_PATCH=${MAIN_PATCH:-0}

echo "Current version: $CURRENT_VERSION"
echo "Latest stable version: $MAIN_VERSION"
echo ""

if [[ "$CURRENT_MAJOR" == "$MAIN_MAJOR" && "$CURRENT_MINOR" == "$MAIN_MINOR" && "$CURRENT_PATCH" == "$MAIN_PATCH" ]]; then
    echo "You are already on the stable equivalent of your current version ($MAIN_VERSION)."
    echo "No action needed."
    read -p "Press enter to go back"
    main_menu
    return
fi

if [[ "$CURRENT_MAJOR" -gt "$MAIN_MAJOR" ]] || \
   [[ "$CURRENT_MAJOR" -eq "$MAIN_MAJOR" && "$CURRENT_MINOR" -gt "$MAIN_MINOR" ]]; then
    echo "WARNING: You are currently on $CURRENT_VERSION (development branch)."
    echo "The latest stable version is $MAIN_VERSION (main branch)."
    echo "Since your development version is newer than stable, switching will require a clean reinstall."
    echo "This means ALL boot files, restore files, and binaries will be deleted."
    echo ""
    read -p "Are you sure you want to switch to stable? (y/N): " switch_confirm
    if [[ $switch_confirm == Y || $switch_confirm == y ]]; then
        sudo rm -rf ./*
        git clone --branch main https://github.com/pwnerblu/surrealra1n repo --recursive
        if [[ ! -d repo ]]; then
            echo "Failed to clone repository."
            exit 1
        fi
        echo "Copying new files..."
        cp -av repo/. ./
        chmod +x surrealra1n.sh
        rm -rf "repo"
        echo "surrealra1n has been switched to stable $MAIN_VERSION! Please run the script again."
        exit 0
    else
        echo "Switch to stable has been canceled."
        main_menu
    fi
else
    echo "You are on $CURRENT_VERSION (development branch)."
    echo "Latest stable version is $MAIN_VERSION (main branch)."
    echo "This will upgrade you to stable without wiping your boot/restore files."
    echo ""
    read -p "Would you like to switch to stable? (y/N): " switch_confirm
    if [[ $switch_confirm == Y || $switch_confirm == y ]]; then
        rm -rf "surrealra1n.old"
        mkdir -p surrealra1n.old
        echo "Backing up your current surrealra1n installation..."
        echo "$CURRENT_VERSION" > surrealra1n.old/oldversion.txt
        mv -v bin surrealra1n.old/
        mv -v futurerestore surrealra1n.old/
        mv -v keys surrealra1n.old/
        mv -v surrealra1n.sh surrealra1n.old/
        git clone --branch main https://github.com/pwnerblu/surrealra1n repo --recursive
        if [[ ! -d repo ]]; then
            echo "Failed to clone repository."
            exit 1
        fi
        echo "Copying new files..."
        cp -av repo/. ./
        chmod +x surrealra1n.sh
        rm -rf "repo"
        echo "surrealra1n has been switched to stable $MAIN_VERSION! Please run the script again."
        exit 0
    else
        echo "Switch to stable has been canceled."
        main_menu
    fi
fi

}

dfu_helper_a11(){

if [[ $MODE == Normal || $MODE == Recovery ]]; then
    echo "You need to put your device into DFU mode."
    read -p "Would you like instructions on how to do this? (y/n): " dfu_instructions
    if [[ $dfu_instructions == y || $dfu_instructions == Y ]] && [[ $MODE == Recovery ]]; then
        echo "Instructions will begin in:"
        echo "3" && sleep 1 && echo "2" && sleep 1 && echo "1" && sleep 1
        echo "Hold volume down + power buttons." 
        echo "4" && sleep 1 && echo "3" && sleep 1 && ./bin/irecovery -n && echo "2" && sleep 1 && echo "1" && sleep 1
        echo "Release the power button now, but keep holding volume down button."
        echo "8" && sleep 1 && echo "7" && sleep 1 && echo "6" && sleep 1 && echo "5" && sleep 1 && echo "4" && sleep 1 && echo "3" && sleep 1 && echo "2" && sleep 1 && echo "1" && sleep 1
    elif [[ $dfu_instructions == y || $dfu_instructions == Y ]] && [[ $MODE == Normal ]]; then
        echo "Put your device into recovery mode, then continue"
        read -p "Press enter to continue once Device is in Recovery"
        echo "Instructions will begin in:"
        echo "3" && sleep 1 && echo "2" && sleep 1 && echo "1" && sleep 1
        echo "Hold volume down + power buttons." 
        echo "4" && sleep 1 && echo "3" && sleep 1 && ./bin/irecovery -n && echo "2" && sleep 1 && echo "1" && sleep 1
        echo "Release the power button now, but keep holding volume down button."
        echo "8" && sleep 1 && echo "7" && sleep 1 && echo "6" && sleep 1 && echo "5" && sleep 1 && echo "4" && sleep 1 && echo "3" && sleep 1 && echo "2" && sleep 1 && echo "1" && sleep 1
    else
        echo "Put your device into DFU mode now"
    fi
fi

echo "Checking for DFU devices"
if [[ $dfu_instructions == Y || $dfu_instructions == y ]]; then
    MODE=$(./bin/irecovery -q | grep "^MODE:" | cut -d ':' -f2 | xargs) || true
    if [[ $MODE == DFU ]]; then
        echo "The device has entered DFU successfully!"
    else
        echo "Device has not entered DFU mode successfully"
        exit 1
    fi
else
    while true; do
      MODE=$(./bin/irecovery -q 2>/dev/null | grep "^MODE:" | cut -d ':' -f2 | xargs) || true
      if [ "$MODE" = "DFU" ]; then
        echo "Device is now in DFU mode!"
        break
      fi

      sleep 1
    done
fi

}

reset_restore_vars() {
    IPSW_PATH=""
    IPSW_PATH_LATEST=""
    SHSH_PATH=""
    VERSION=""
    BUILD=""
    VERSION_LATEST=""
}

sep_checker(){

if [[ $IDENTIFIER == iPhone6* || $IDENTIFIER == iPhone7* || $IDENTIFIER == iPad5,1 || $IDENTIFIER == iPad5,2 || $IDENTIFIER == iPod7* || $IDENTIFIER == iPad4,1 || $IDENTIFIER == iPad4,2 || $IDENTIFIER == iPad4,3 || $IDENTIFIER == iPad4,4 || $IDENTIFIER == iPad4,5 ]] && [[ $VERSION == 7.* || $VERSION == 8.* || $VERSION == 9.* || $VERSION == 10.0* || $VERSION == 11.0* || $VERSION == 11.1* || $VERSION == 11.2* ]]; then
    echo "SEP is incompatible. Restore cannot continue"
    exit 1
fi
if [[ $IDENTIFIER == iPhone6* ]] && [[ $VERSION == 10.1* ]]; then
    echo "SEP is compatible but Touch ID will break"
    read -p "Press enter to continue"
fi
if [[ $IDENTIFIER == iPhone7* || $IDENTIFIER == iPad5,1 || $IDENTIFIER == iPad5,2 ]] && [[ $VERSION == 10.1* || $VERSION == 10.2* || $VERSION == 10.3* ]]; then
    echo "SEP is compatible but Touch ID will break, device may take 3-5 minutes to boot, and may hang during Setup"
    read -p "Press enter to continue"
fi
if [[ $IDENTIFIER == iPad5* ]] && [[ $VERSION == 13.* ]]; then
    echo "SEP is compatible but Touch ID will break, device may take 3-5 minutes to boot, and may hang for 30 seconds when it reaches the Touch ID part of Setup. Deep sleep issues are also very likely"
fi
if [[ $IDENTIFIER == iPad5,1 || $IDENTIFIER == iPad5,2 ]] && [[ $VERSION == 11.3* || $VERSION == 11.4* || $VERSION == 12.* ]]; then
    echo "SEP is compatible but Touch ID will break"
    read -p "Press enter to continue"
fi
if [[ $IDENTIFIER == iPad5,3 || $IDENTIFIER == iPad5,4 ]] && [[ $VERSION == 8.* || $VERSION == 9.* || $VERSION == 10.* || $VERSION == 11.* || $VERSION == 12.* ]]; then
    echo "SEP is incompatible. Restore cannot continue"
    exit 1
fi
if [[ $IDENTIFIER == iPhone10* ]] && [[ $VERSION == 14.3* || $VERSION == 14.4* || $VERSION == 14.5* || $VERSION == 14.6* || $VERSION == 14.7* || $VERSION == 14.8* || $VERSION == 15.* ]]; then
    echo "SEP is partially incompatible"
    echo "Device will be unable to activate after the restore."
    echo "And potentially other broken features"
    read -p "Press enter to continue"
fi
if [[ $IDENTIFIER == iPhone10* ]] && [[ $VERSION == 11.* || $VERSION == 12.* || $VERSION == 13.* || $VERSION == 14.0* || $VERSION == 14.1* || $VERSION == 14.2* ]]; then
    echo "SEP is incompatible. Restore cannot continue"
    exit 1
fi

}

download_tvos_sep(){

mkdir -p tmp
sep_path="tmp/sep-firmware.j42d.RELEASE.im4p"
manifest_path="tmp/BuildManifest-SEP.plist"
sep_ipsw="https://secure-appldnld.apple.com/tvos10.2.2/091-23452-20170720-5D53229C-6A56-11E7-8577-8B2C4A4DD6D5/AppleTV5,3_10.2.2_14W756_Restore.ipsw"
curl -L -o tmp/BuildManifest-SEP.plist https://github.com/pwnerblu/cursed-sep-resources/raw/refs/heads/main/BuildManifest-$IDENTIFIER.plist
sudo ./bin/pzb -g Firmware/all_flash/sep-firmware.j42d.RELEASE.im4p $sep_ipsw
sudo mv -v sep-firmware.j42d.RELEASE.im4p $sep_path

}

download_iphone6_sep(){

mkdir -p tmp
sep_path="tmp/sep-firmware.n61.RELEASE.im4p"
manifest_path="tmp/BuildManifest-SEP.plist"
sep_ipsw="https://updates.cdn-apple.com/2026WinterFCS/fullrestores/047-28352/B80B4A86-C206-4C4F-8D35-65579694AEE9/iPhone_4.7_12.5.8_16H88_Restore.ipsw"
curl -L -o tmp/BuildManifest-SEP.plist https://github.com/pwnerblu/cursed-sep-resources/raw/refs/heads/main/BuildManifest-$IDENTIFIER-12.5.8.plist
sudo ./bin/pzb -g Firmware/all_flash/sep-firmware.n61.RELEASE.im4p $sep_ipsw
sudo mv -v sep-firmware.n61.RELEASE.im4p $sep_path

}

download_1033_ota_sep(){

mkdir -p tmp
sep_path="tmp/sep-firmware.$BOARDID2.RELEASE.im4p"
sep_name="sep-firmware.$BOARDID2.RELEASE.im4p"
manifest_path="tmp/BuildManifest-SEP.plist"
if [[ $IDENTIFIER == iPhone6* ]]; then
    sep_ipsw="http://appldnld.apple.com/ios10.3.3/091-23133-20170719-CA8E78E6-6977-11E7-968B-2B9100BA0AE3/iPhone_4.0_64bit_10.3.3_14G60_Restore.ipsw"
elif [[ $IDENTIFIER == iPad4* ]]; then
    sep_ipsw="http://appldnld.apple.com/ios10.3.3/091-23378-20170719-CA983C78-6977-11E7-8922-3D9100BA0AE3/iPad_64bit_10.3.3_14G60_Restore.ipsw"
fi
curl -L -o tmp/BuildManifest-SEP.plist https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/resources/manifest/BuildManifest_${IDENTIFIER}_10.3.3.plist
sudo ./bin/pzb -g Firmware/all_flash/$sep_name $sep_ipsw
sudo mv -v $sep_name $sep_path

}

prepatch_ibssibec_fr(){

sudo mkdir -p /tmp/futurerestore
mkdir -p work
./bin/img4tool -s "$SHSH_PATH" -e -m "$IDENTIFIER-im4m"
im4m="$IDENTIFIER-im4m"
IBSS_KEY=$(grep "ibss-$VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)
IBEC_KEY=$(grep "ibec-$VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)
if [[ $IDENTIFIER == iPhone10,1 || $IDENTIFIER == iPhone10,4 ]]; then
    ipsw_url="https://updates.cdn-apple.com/2020WinterFCS/fullrestores/001-87486/23310DA1-A434-4192-87BC-31429FD2D625/iPhone_4.7_P3_14.3_18C66_Restore.ipsw"
elif [[ $IDENTIFIER == iPhone10,2 || $IDENTIFIER == iPhone10,5 ]]; then
    ipsw_url="https://updates.cdn-apple.com/2020WinterFCS/fullrestores/001-87451/EE6AEB4B-1BF7-4FBF-9D29-A8C7B970B495/iPhone_5.5_P3_14.3_18C66_Restore.ipsw"
elif [[ $IDENTIFIER == iPhone10,3 || $IDENTIFIER == iPhone10,6 ]]; then
    ipsw_url="https://updates.cdn-apple.com/2020WinterFCS/fullrestores/001-87865/458334F5-D8E1-498A-A9FD-08BBD20FE007/iPhone10,3,iPhone10,6_14.3_18C66_Restore.ipsw"
fi
if [[ $VERSION == 10.3* || $VERSION == 11.* || $VERSION == 12.* || $VERSION == 13.* || $VERSION == 14.* || $VERSION == 15.* || $VERSION == 16.* ]]; then
    unzip -j "$IPSW_PATH" "Firmware/dfu/$IBSS" -d work
    unzip -j "$IPSW_PATH" "Firmware/dfu/$IBEC" -d work
    if [[ $IDENTIFIER == iPhone10* ]] && [[ $VERSION == 14.0 ]]; then # just for 14.0 beta 4 restore
        cd work
        sudo ../bin/pzb -g Firmware/dfu/$IBSS $ipsw_url
        sudo ../bin/pzb -g Firmware/dfu/$IBEC $ipsw_url
        cd ..
    fi
    ./bin/img4 -i work/$IBSS -o work/iBSS.raw -k $IBSS_KEY
    ./bin/img4 -i work/$IBEC -o work/iBEC.raw -k $IBEC_KEY
    ./bin/iBoot64Patcher work/iBSS.raw work/iBSS.patched
    if [[ $IDENTIFIER == iPhone10* ]]; then
        ./bin/iBoot64Patcher work/iBSS.raw work/iBSS.patched -n
    fi
    ./bin/iBoot64Patcher work/iBEC.raw work/iBEC.patched -b "rd=md0 debug=0x2014e -v wdt=-1 nand-enable-reformat=1 -restore amfi=0xff cs_enforcement_disable=1" -n
    sudo ./bin/img4 -i work/iBSS.patched -o /tmp/futurerestore/ibss.$BOARDID.$BUILD.patched.img4 -A -T ibss -M $im4m
    sudo ./bin/img4 -i work/iBEC.patched -o /tmp/futurerestore/ibec.$BOARDID.$BUILD.patched.img4 -A -T ibec -M $im4m
else
    # 10.3 iBSS/iBEC workaround
    IBSS_KEY=$(grep "ibss-10.3:" "$KEY_FILE" | cut -d':' -f2 | xargs)
    IBEC_KEY=$(grep "ibec-10.3:" "$KEY_FILE" | cut -d':' -f2 | xargs)
    if [[ $IDENTIFIER == iPhone6* ]]; then
        ipsw_url="http://appldnld.apple.com/ios10.3/091-02949-20170327-7584B286-0D86-11E7-A4FA-7ECE122AC769/iPhone_4.0_64bit_10.3_14E277_Restore.ipsw"
    elif [[ $IDENTIFIER == iPhone7,2 ]]; then
        ipsw_url="http://appldnld.apple.com/ios10.3/091-02962-20170327-7584E8B4-0D86-11E7-B580-8CCE122AC769/iPhone_4.7_10.3_14E277_Restore.ipsw"
    elif [[ $IDENTIFIER == iPhone7,1 ]]; then
        ipsw_url="http://appldnld.apple.com/ios10.3/091-02950-20170327-75843ACC-0D86-11E7-ACCC-80CE122AC769/iPhone_5.5_10.3_14E277_Restore.ipsw"
    elif [[ $IDENTIFIER == iPad4* ]]; then
        ipsw_url="http://appldnld.apple.com/ios10.3/091-02965-20170327-758BACE4-0D86-11E7-9129-8ECE122AC769/iPad_64bit_10.3_14E277_Restore.ipsw"
    elif [[ $IDENTIFIER == iPad5* ]]; then
        ipsw_url="http://appldnld.apple.com/ios10.3/091-02967-20170327-758827FE-0D86-11E7-9B30-90CE122AC769/iPad_64bit_TouchID_10.3_14E277_Restore.ipsw"
    elif [[ $IDENTIFIER == iPod7* ]]; then
        ipsw_url="http://appldnld.apple.com/ios10.3/091-02958-20170327-75869E66-0D86-11E7-BF4D-88CE122AC769/iPodtouch_10.3_14E277_Restore.ipsw"
    fi
    sudo ./bin/pzb -g Firmware/dfu/$IBSS $ipsw_url
    sudo ./bin/pzb -g Firmware/dfu/$IBEC $ipsw_url
    sudo mv -v $IBSS work/
    sudo mv -v $IBEC work/
    ./bin/img4 -i work/$IBSS -o work/iBSS.raw -k $IBSS_KEY
    ./bin/img4 -i work/$IBEC -o work/iBEC.raw -k $IBEC_KEY
    ./bin/iBoot64Patcher work/iBSS.raw work/iBSS.patched
    ./bin/iBoot64Patcher work/iBEC.raw work/iBEC.patched -b "rd=md0 debug=0x2014e -v wdt=-1 nand-enable-reformat=1 -restore amfi=0xff cs_enforcement_disable=1" -n
    sudo ./bin/img4 -i work/iBSS.patched -o /tmp/futurerestore/ibss.$BOARDID.$BUILD.patched.img4 -A -T ibss -M $im4m
    sudo ./bin/img4 -i work/iBEC.patched -o /tmp/futurerestore/ibec.$BOARDID.$BUILD.patched.img4 -A -T ibec -M $im4m
fi

}

det_rsep_flag(){

if [[ $VERSION == 16.* || $IDENTIFIER == iPhone10,3 || $IDENTIFIER == iPhone10,6 ]]; then
    rsep_flag=""
else
    rsep_flag="--no-rsep"
fi

}

restore_with_blobs(){

if [[ -z "$IPSW_PATH" ]]; then
    echo "No IPSW selected. Aborting."
    exit 1
fi
if [[ ! -f "$IPSW_PATH" ]]; then
    echo "IPSW does not exist: $IPSW_PATH"
    exit 1
fi
if [[ -z "$SHSH_PATH" ]]; then
    echo "No SHSH blob selected. Aborting."
    exit 1
fi
if [[ ! -f "$SHSH_PATH" ]]; then
    echo "SHSH blob does not exist: $SHSH_PATH"
    exit 1
fi

if [[ $IDENTIFIER == iPhone10,3 || $IDENTIFIER == iPhone10,6 ]]; then
    echo "iPhone X is not supported yet."
    echo "Legacy iOS Kit *does* support iPhone X restores with blobs though"
    exit 1
fi

if [[ $IDENTIFIER == iPhone10* ]]; then
    dfu_helper_a11
else
    dfu_helper
fi

pwn_device
det_rsep_flag

sleep 5

if [[ $IDENTIFIER == iPhone7* || $IDENTIFIER == iPad5* || $IDENTIFIER == iPod7* ]] && [[ $VERSION == 10.* ]]; then
    download_tvos_sep
    if [[ $IDENTIFIER == iPad5* || $IDENTIFIER == iPhone7* ]] && [[ $VERSION == 10.3* ]]; then
        unzip -j "$IPSW_PATH" "$KERNEL" -d work
        ./bin/img4 -i work/$KERNEL -o work/kernel.raw
        ./bin/Kernel64Patcher2 work/kernel.raw work/kernel.patch -u 11 --skip-sks --skip-acm --skip-amfi
        ./bin/kerneldiff work/kernel.raw work/kernel.patch work/kernel.diff
        ./bin/img4 -i work/$KERNEL -o work/kernel.im4p -T rkrn -P work/kernel.diff -J || true
        prepatch_ibssibec_fr
        while true; do
            sudo FUTURERESTORE_I_SOLEMNLY_SWEAR_THAT_I_AM_UP_TO_NO_GOOD=1 \
                ./futurerestore/futurerestore -t $SHSH_PATH --use-pwndfu \
                --sep $sep_path --sep-manifest $manifest_path \
                --custom-latest $LATEST_VERSION \
                $updatebb_flag $rsep_flag --rkrn work/kernel.im4p $IPSW_PATH
            EXIT_CODE=$?
            if [[ $EXIT_CODE -eq 139 ]]; then
                echo "futurerestore segfaulted (exit 139), retrying..."
                sleep 2
            else
                break
            fi
        done
        if [[ $EXIT_CODE -eq 0 ]]; then
            echo "Restore has completed! Read above if there are any errors"
            exit 0
        else
            echo "futurerestore failed with exit code $EXIT_CODE"
            exit 1
        fi
    fi
    prepatch_ibssibec_fr
    while true; do
        sudo FUTURERESTORE_I_SOLEMNLY_SWEAR_THAT_I_AM_UP_TO_NO_GOOD=1 \
            ./futurerestore/futurerestore -t $SHSH_PATH --use-pwndfu \
            --sep $sep_path --sep-manifest $manifest_path \
            --custom-latest $LATEST_VERSION \
            $updatebb_flag --no-rsep $IPSW_PATH
        EXIT_CODE=$?
        if [[ $EXIT_CODE -eq 139 ]]; then
            echo "futurerestore segfaulted (exit 139), retrying..."
            sleep 2
        else
            break
        fi
    done
elif [[ $IDENTIFIER == iPad4* || $IDENTIFIER == iPhone6* ]] && [[ $VERSION == 10.* ]]; then
    download_1033_ota_sep
    prepatch_ibssibec_fr
    while true; do
        sudo FUTURERESTORE_I_SOLEMNLY_SWEAR_THAT_I_AM_UP_TO_NO_GOOD=1 \
            ./futurerestore/futurerestore -t $SHSH_PATH --use-pwndfu \
            --sep $sep_path --sep-manifest $manifest_path \
            --custom-latest $LATEST_VERSION \
            $updatebb_flag --no-rsep $IPSW_PATH
        EXIT_CODE=$?
        if [[ $EXIT_CODE -eq 139 ]]; then
            echo "futurerestore segfaulted (exit 139), retrying..."
            sleep 2
        else
            break
        fi
    done
elif [[ $IDENTIFIER == iPad5* ]] && [[ $VERSION == 11.* || $VERSION == 12.* ]]; then
    download_iphone6_sep
    prepatch_ibssibec_fr
    while true; do
        sudo FUTURERESTORE_I_SOLEMNLY_SWEAR_THAT_I_AM_UP_TO_NO_GOOD=1 \
            ./futurerestore/futurerestore -t $SHSH_PATH --use-pwndfu \
            --sep $sep_path --sep-manifest $manifest_path \
            --custom-latest $LATEST_VERSION \
            $updatebb_flag --no-rsep $IPSW_PATH
        EXIT_CODE=$?
        if [[ $EXIT_CODE -eq 139 ]]; then
            echo "futurerestore segfaulted (exit 139), retrying..."
            sleep 2
        else
            break
        fi
    done
else
    prepatch_ibssibec_fr
    while true; do
        sudo FUTURERESTORE_I_SOLEMNLY_SWEAR_THAT_I_AM_UP_TO_NO_GOOD=1 \
            ./futurerestore/futurerestore -t $SHSH_PATH --use-pwndfu \
            --latest-sep \
            --custom-latest $LATEST_VERSION \
            $updatebb_flag --no-rsep $IPSW_PATH
        EXIT_CODE=$?
        if [[ $EXIT_CODE -eq 139 ]]; then
            echo "futurerestore segfaulted (exit 139), retrying..."
            sleep 2
        else
            break
        fi
    done
fi

echo "Restore has completed! Read above if there is any errors"
exit 0

}

restore_untethered_opts(){

clear 
echo "$INFO_TEXT"
echo ""
echo "Options:"
echo ""
echo "1. Select Target IPSW"
echo "2. Select SHSH"
echo "3. Start Restore"
echo "4. Back"
read -p "Please input an option (1-4): " untether_options
if [[ $untether_options == 1 ]]; then
    IPSW_PATH=$($zenity --file-selection --title="Select an IPSW file")
    if [[ -z "$IPSW_PATH" ]]; then
        echo "No IPSW selected. Aborting."
        exit 1
    fi
    unzip -j "$IPSW_PATH" "BuildManifest.plist" -d work
    BUILD=$(grep -A1 "ProductBuildVersion" work/BuildManifest.plist | grep -o '<string>[^<]*</string>' | head -1 | sed 's/<[^>]*>//g')
    VERSION=$(grep -A1 "ProductVersion" work/BuildManifest.plist | grep -o '<string>[^<]*</string>' | head -1 | sed 's/<[^>]*>//g')
    restore_untethered_opts
elif [[ $untether_options == 2 ]]; then
    SHSH_PATH=$($zenity --file-selection --title="Select an SHSH2 file")
    if [[ -z "$SHSH_PATH" ]]; then
        echo "No SHSH blob selected. Aborting."
        exit 1
    fi
    echo "An SHSH blob is selected. Please ensure this blob is valid for iOS $VERSION, otherwise the restore will likely fail"
    read -p "Press enter to continue"
    restore_untethered_opts
elif [[ $untether_options == 3 ]]; then
    sep_checker
    restore_with_blobs
elif [[ $untether_options == 4 ]]; then
    reset_restore_vars
    restore_utils
else
    echo "Invalid option. Exiting."
    exit 1
fi

}

make_custom_ipsw_ios16(){

mkdir -p restorefiles
mkdir -p restorefiles/$IDENTIFIER
mkdir -p restorefiles/$IDENTIFIER/$VERSION
unzip "$IPSW_PATH" -d tmp1
unzip "$IPSW_PATH_LATEST" -d tmp2
find tmp1/Firmware/all_flash/ -type f ! -name '*DeviceTree*' -exec rm -f {} +
find tmp2/Firmware/all_flash/ -type f ! -name '*DeviceTree*' -exec cp {} tmp1/Firmware/all_flash/ \;
# because no AOP validation patch for iOS 16, fallback to latest AOP
if [[ $IDENTIFIER == iPhone10,3 || $IDENTIFIER == iPhone10,6 ]]; then
    mv tmp2/Firmware/AOP/aopfw-iphone10baop.im4p tmp1/Firmware/AOP/aopfw-iphone10baop.im4p
else
    mv tmp2/Firmware/AOP/aopfw-iphone10aop.im4p tmp1/Firmware/AOP/aopfw-iphone10aop.im4p
fi
./bin/img4 -i tmp1/$KERNEL -o work/kernelboot.raw
./bin/Kernel64Patcher work/kernelboot.raw work/kernelboot.patch -e -o -h
./bin/img4 -i work/kernelboot.patch -o tmp1/$KERNEL -A -T krnl -J || true
cd tmp1
zip -0 -r ../custom.ipsw *
cd ..
rm -rf "tmp2"
mv -v custom.ipsw $restoredir/custom.ipsw
mkdir -p work
cd work 
if [[ $IDENTIFIER == iPhone10,3 || $IDENTIFIER == iPhone10,6 ]]; then
    url_ios16="https://updates.cdn-apple.com/2022FallFCS/fullrestores/012-65861/0A0400A0-2174-4D49-91B7-43FC9DE24272/iPhone10,3,iPhone10,6_16.0_20A362_Restore.ipsw"
elif [[ $IDENTIFIER == iPhone10,2 || $IDENTIFIER == iPhone10,5 ]]; then
    url_ios16="https://updates.cdn-apple.com/2022FallFCS/fullrestores/012-65568/0851247C-1B06-4CD4-B3C2-5A94026970B7/iPhone_5.5_P3_16.0_20A362_Restore.ipsw"
else
    url_ios16="https://updates.cdn-apple.com/2022FallFCS/fullrestores/012-65931/BD2515B7-7802-4EB4-9377-98E3238EA5A8/iPhone_4.7_P3_16.0_20A362_Restore.ipsw"
fi
sudo ../bin/pzb -g 098-08863-001.dmg $url_ios16
sudo ../bin/pzb -g $KERNEL $url_ios16
cd ..
restore_ramdisk_dmg=$(find_dmg work smallest)
./bin/img4 -i work/$KERNEL -o work/kernel.raw
./bin/KPlooshFinder work/kernel.raw work/kernel.patched
./bin/kerneldiff work/kernel.raw work/kernel.patched work/kernel.diff
./bin/img4 -i work/$KERNEL -o $restoredir/kernel.im4p -T rkrn -P work/kernel.diff -J || true
# rdsk prep
./bin/img4 -i $restore_ramdisk_dmg -o work/ramdisk.raw
./bin/hfsplus work/ramdisk.raw extract usr/sbin/asr work/asr
./bin/asr64_patcher work/asr work/asr_patched
./bin/ldid -e work/asr > work/ents.plist
./bin/ldid -Swork/ents.plist work/asr_patched
./bin/hfsplus work/ramdisk.raw rm usr/sbin/asr 
./bin/hfsplus work/ramdisk.raw add work/asr_patched usr/sbin/asr
./bin/hfsplus work/ramdisk.raw chmod 100755 usr/sbin/asr
./bin/hfsplus work/ramdisk.raw extract usr/lib/libimg4.dylib work/libimg4.dylib
./bin/libimg4_patcher work/libimg4.dylib work/libimg4.patch
./bin/ldid -Swork/ents.plist work/libimg4.patch
./bin/hfsplus work/ramdisk.raw rm usr/lib/libimg4.dylib 
./bin/hfsplus work/ramdisk.raw add work/libimg4.patch usr/lib/libimg4.dylib
./bin/hfsplus work/ramdisk.raw chmod 100755 usr/lib/libimg4.dylib
# pack rdsk into im4p
./bin/img4 -i work/ramdisk.raw -o $restoredir/ramdisk.im4p -A -T rdsk
# Wrap up
rm -rf "tmp1"
rm -rf "work"

}

make_custom_ipsw(){

mkdir -p restorefiles
mkdir -p restorefiles/$IDENTIFIER
mkdir -p restorefiles/$IDENTIFIER/$VERSION
unzip "$IPSW_PATH" -d tmp1
unzip "$IPSW_PATH_LATEST" -d tmp2
if [[ $VERSION == 10.1* || $VERSION == 10.2* ]]; then
    cp tmp2/Firmware/all_flash/$LLB tmp1/Firmware/all_flash/$ALLFLASH/$LLB10
    cp tmp2/Firmware/all_flash/$IBOOT tmp1/Firmware/all_flash/$ALLFLASH/$IBOOT10
elif [[ $VERSION == 10.3* ]]; then
    cp tmp2/Firmware/all_flash/$LLB tmp1/Firmware/all_flash/$LLB
    cp tmp2/Firmware/all_flash/$IBOOT tmp1/Firmware/all_flash/$IBOOT
else
    find tmp1/Firmware/all_flash/ -type f ! -name '*DeviceTree*' -exec rm -f {} +
    find tmp2/Firmware/all_flash/ -type f ! -name '*DeviceTree*' -exec cp {} tmp1/Firmware/all_flash/ \;
fi
if [[ $VERSION == 14.* ]] && [[ $IDENTIFIER == iPhone10* ]]; then
    ./bin/img4 -i tmp1/$KERNEL -o work/kernelboot.raw
    ./bin/Kernel64Patcher work/kernelboot.raw work/kernelboot.patch -b
    ./bin/img4 -i work/kernelboot.patch -o tmp1/$KERNEL -A -T krnl -J || true
elif [[ $VERSION == 15.* ]] && [[ $IDENTIFIER == iPhone10* ]]; then
    ./bin/img4 -i tmp1/$KERNEL -o work/kernelboot.raw
    ./bin/Kernel64Patcher work/kernelboot.raw work/kernelboot.patch -e -o -r -b15
    ./bin/img4 -i work/kernelboot.patch -o tmp1/$KERNEL -A -T krnl -J || true
fi
cd tmp1
zip -0 -r ../custom.ipsw *
cd ..
rm -rf "tmp2"
mv -v custom.ipsw $restoredir/custom.ipsw
mkdir -p work
restore_ramdisk_dmg=$(find_dmg tmp1 smallest)
update_ramdisk_dmg=$(find_dmg tmp1 largest 1073741824)
if [[ $VERSION == 10.2* || $VERSION == 10.1* ]]; then
    cp -v tmp1/$KERNEL10 work/kernel.im4p
else
    cp -v tmp1/$KERNEL work/kernel.im4p
fi
./bin/img4 -i work/kernel.im4p -o work/kernel.raw
./bin/KPlooshFinder work/kernel.raw work/kernel.patched
if [[ $IDENTIFIER == iPad5* || $IDENTIFIER == iPhone7* ]] && [[ $VERSION == 10.* ]]; then
    mv -v work/kernel.patched work/kernel.patch
    ./bin/Kernel64Patcher2 work/kernel.patch work/kernel.patched -u 11 --skip-sks --skip-acm --skip-amfi
fi
./bin/kerneldiff work/kernel.raw work/kernel.patched work/kernel.diff
./bin/img4 -i work/kernel.im4p -o $restoredir/kernel.im4p -T rkrn -P work/kernel.diff -J || true
# rdsk prep
./bin/img4 -i $restore_ramdisk_dmg -o work/ramdisk.raw
if [[ $VERSION == 10.* ]]; then
    ./bin/hfsplus work/ramdisk.raw grow 60000000
fi
./bin/hfsplus work/ramdisk.raw extract usr/sbin/asr work/asr
./bin/asr64_patcher work/asr work/asr_patched
./bin/ldid -e work/asr > work/ents.plist
./bin/ldid -Swork/ents.plist work/asr_patched
./bin/hfsplus work/ramdisk.raw rm usr/sbin/asr 
./bin/hfsplus work/ramdisk.raw add work/asr_patched usr/sbin/asr
./bin/hfsplus work/ramdisk.raw chmod 100755 usr/sbin/asr
if [[ $VERSION == 14.* || $VERSION == 15.* ]]; then
    ./bin/hfsplus work/ramdisk.raw extract usr/lib/libimg4.dylib work/libimg4.dylib
    ./bin/libimg4_patcher work/libimg4.dylib work/libimg4.patch
    ./bin/ldid -Swork/ents.plist work/libimg4.patch
    ./bin/hfsplus work/ramdisk.raw rm usr/lib/libimg4.dylib 
    ./bin/hfsplus work/ramdisk.raw add work/libimg4.patch usr/lib/libimg4.dylib
    ./bin/hfsplus work/ramdisk.raw chmod 100755 usr/lib/libimg4.dylib
fi
if [[ $IDENTIFIER == iPhone10,3 || $IDENTIFIER == iPhone10,6 ]]; then # do some ipx patching
    ./bin/hfsplus work/ramdisk.raw extract usr/local/bin/restored_external work/restored_external
    ./bin/ipx_restored_patcher work/restored_external work/restored_patch # use restored patcher by Mineek
    ./bin/ldid -e work/restored_external > work/ents.plist
    ./bin/ldid -Swork/ents.plist work/restored_patch
    ./bin/hfsplus work/ramdisk.raw rm usr/local/bin/restored_external
    ./bin/hfsplus work/ramdisk.raw add work/restored_patch usr/local/bin/restored_external
    ./bin/hfsplus work/ramdisk.raw chmod 100755 usr/local/bin/restored_external
fi
# pack rdsk into im4p
./bin/img4 -i work/ramdisk.raw -o $restoredir/ramdisk.im4p -A -T rdsk
if [[ $IDENTIFIER == iPhone10* ]]; then
    # do update ramdisk stuff so 14.0b4 to 14.3-15.6.1 update install is possible
    ./bin/img4 -i $update_ramdisk_dmg -o work/ramdisk.raw
    ./bin/hfsplus work/ramdisk.raw extract usr/sbin/asr work/asr
    ./bin/asr64_patcher work/asr work/asr_patched
    ./bin/ldid -e work/asr > work/ents.plist
    ./bin/ldid -Swork/ents.plist work/asr_patched
    ./bin/hfsplus work/ramdisk.raw rm usr/sbin/asr 
    ./bin/hfsplus work/ramdisk.raw add work/asr_patched usr/sbin/asr
    ./bin/hfsplus work/ramdisk.raw chmod 100755 usr/sbin/asr
    ./bin/hfsplus work/ramdisk.raw extract usr/lib/libimg4.dylib work/libimg4.dylib
    ./bin/libimg4_patcher work/libimg4.dylib work/libimg4.patch
    ./bin/ldid -Swork/ents.plist work/libimg4.patch
    ./bin/hfsplus work/ramdisk.raw rm usr/lib/libimg4.dylib 
    ./bin/hfsplus work/ramdisk.raw add work/libimg4.patch usr/lib/libimg4.dylib
    ./bin/hfsplus work/ramdisk.raw chmod 100755 usr/lib/libimg4.dylib
    if [[ $IDENTIFIER == iPhone10,3 || $IDENTIFIER == iPhone10,6 ]]; then # do some ipx patching
        ./bin/hfsplus work/ramdisk.raw extract usr/local/bin/restored_update work/restored_external
        ./bin/ipx_restored_patcher work/restored_external work/restored_patch # use restored patcher by Mineek
        ./bin/ldid -e work/restored_external > work/ents.plist
        ./bin/ldid -Swork/ents.plist work/restored_patch
        ./bin/hfsplus work/ramdisk.raw rm usr/local/bin/restored_update
        ./bin/hfsplus work/ramdisk.raw add work/restored_patch usr/local/bin/restored_update
        ./bin/hfsplus work/ramdisk.raw chmod 100755 usr/local/bin/restored_update
    fi
    # pack rdsk into im4p
    ./bin/img4 -i work/ramdisk.raw -o $restoredir/updateramdisk.im4p -A -T rdsk
fi
# Wrap up
rm -rf "tmp1"
rm -rf "work"

}

make_custom_ipsw_a12_ios14(){

IBSS_KEY=$(grep "ibss-$VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)
mkdir -p restorefiles
mkdir -p restorefiles/$IDENTIFIER
mkdir -p restorefiles/$IDENTIFIER/$VERSION
mkdir -p boot
mkdir -p boot/$IDENTIFIER
mkdir -p boot/$IDENTIFIER/$VERSION
unzip "$IPSW_PATH" -d tmp1
unzip "$IPSW_PATH_LATEST" -d tmp2
mkdir -p work
# iBSS patching of course because yes
if [[ $VERSION == 14.0 ]] && [[ $BUILD != 18A373 ]]; then
    ipsw_url="https://updates.cdn-apple.com/2020SummerFCS/fullrestores/001-46828/6A00C15C-8AEB-490E-A468-04E28C68E7C9/iPhone11,8,iPhone12,1_14.0_18A373_Restore.ipsw"
    cd work 
    sudo ../bin/pzb -g Firmware/dfu/$IBSS $ipsw_url
    cd ..
    ./bin/img4 -i work/$IBSS -o work/iBSS.raw -k $IBSS_KEY
    ./bin/kairos work/iBSS.raw boot/$IDENTIFIER/iBSS.patch 
    ./bin/kairos work/iBSS.raw work/iBSS.patchboot -b "-v"
    ./bin/iBootpatch2 work/iBSS.patchboot boot/$IDENTIFIER/$VERSION/iBSS.boot
    ./bin/img4 -i boot/$IDENTIFIER/iBSS.patch -o tmp2/Firmware/dfu/$IBEC -A -T ibec
else
    ./bin/img4 -i tmp1/Firmware/dfu/$IBSS -o work/iBSS.raw -k $IBSS_KEY
    ./bin/kairos work/iBSS.raw boot/$IDENTIFIER/iBSS.patch
    ./bin/kairos work/iBSS.raw work/iBSS.patchboot -b "-v"
    ./bin/iBootpatch2 work/iBSS.patchboot boot/$IDENTIFIER/$VERSION/iBSS.boot
    ./bin/img4 -i boot/$IDENTIFIER/iBSS.patch -o tmp2/Firmware/dfu/$IBEC -A -T ibec
fi
#
restore_ramdisk_dmg=$(find_dmg tmp1 largest 106760000)
restore_ramdisk_dmg_18=$(find_dmg tmp2 largest 179000000)
fs_dmg_18=$(find_dmg tmp2 largest)
fs_dmg=$(find_dmg tmp1 largest)
fs_dmg_name=${fs_dmg##*/}
fs_dmg_18_name=${fs_dmg_18##*/}
ramdisk_dmg_name_18=${restore_ramdisk_dmg_18##*/}
ramdisk_dmg_name=${restore_ramdisk_dmg##*/}
sudo plutil -replace BuildIdentities.0.Manifest.KernelCache.Info.Path -string "$KERNEL2" tmp2/BuildManifest.plist
cp -v tmp1/Firmware/AOP/$AOP14 tmp2/Firmware/AOP/$AOP
cp -v tmp1/Firmware/agx/$GFX tmp2/Firmware/agx/$GFX
cp -v tmp1/Firmware/ane/$ANE tmp2/Firmware/ane/$ANE
cp -v tmp1/Firmware/ave/$AVE tmp2/Firmware/ave/$AVE
cp -v tmp1/Firmware/isp_bni/$ISP tmp2/Firmware/isp_bni/$ISP
cp -v tmp1/Firmware/WirelessPower/$WIRELESS tmp2/Firmware/WirelessPower/$WIRELESS
cp -v tmp1/Firmware/$MTFW tmp2/Firmware/$MTFW
cp -v tmp1/Firmware/$CALLAN tmp2/Firmware/$CALLAN
cp -v tmp1/Firmware/$HAPTICASSET tmp2/Firmware/$HAPTICASSET
cp -v tmp1/Firmware/all_flash/$DEVICETREE tmp2/Firmware/all_flash/$DEVICETREE
cp -v tmp1/Firmware/$IOFW tmp2/Firmware/$IOFW
cp -v $fs_dmg $fs_dmg_18 # replace rootfs in the IPSW
cp -v tmp1/Firmware/$fs_dmg_name.trustcache tmp2/Firmware/$fs_dmg_18_name.trustcache 
cp -v tmp1/Firmware/$fs_dmg_name.root_hash tmp2/Firmware/$fs_dmg_18_name.root_hash 
cp -v tmp1/Firmware/$fs_dmg_name.mtree tmp2/Firmware/$fs_dmg_18_name.mtree 
cp -v tmp1/Firmware/$ramdisk_dmg_name.trustcache tmp2/Firmware/$ramdisk_dmg_name_18.trustcache
./bin/img4 -i tmp1/$KERNEL -o work/kernel.raw
./bin/Kernel64Patcher3 work/kernel.raw work/kernelboot.patch -b # use kernel64patcher3, properly patch trust evaluation check on ios 14 arm64e
./bin/kerneldiff work/kernel.raw work/kernelboot.patch work/kernelboot.diff
rm -rf tmp2/$KERNEL
./bin/img4 -i tmp1/$KERNEL -o tmp2/$KERNEL2 -T krnl -J -P work/kernelboot.diff || true
./bin/KPlooshFinder work/kernel.raw work/kernel.patch
./bin/kerneldiff work/kernel.raw work/kernel.patch work/kernel.diff
./bin/img4 -i tmp1/$KERNEL -o tmp2/$KERNEL -T krnl -J -P work/kernel.diff || true
./bin/img4 -i $restore_ramdisk_dmg -o work/ramdisk.raw
./bin/hfsplus work/ramdisk.raw extract usr/sbin/asr work/asr
./bin/asr64_patcher work/asr work/asr_patched
./bin/ldid -e work/asr > work/ents.plist
./bin/ldid -Swork/ents.plist work/asr_patched
./bin/hfsplus work/ramdisk.raw rm usr/sbin/asr 
./bin/hfsplus work/ramdisk.raw add work/asr_patched usr/sbin/asr
./bin/hfsplus work/ramdisk.raw chmod 100755 usr/sbin/asr
./bin/hfsplus work/ramdisk.raw extract usr/lib/libimg4.dylib work/libimg4.dylib
./bin/libimg4_patcher work/libimg4.dylib work/libimg4.patch
./bin/ldid -Swork/ents.plist work/libimg4.patch
./bin/hfsplus work/ramdisk.raw rm usr/lib/libimg4.dylib 
./bin/hfsplus work/ramdisk.raw add work/libimg4.patch usr/lib/libimg4.dylib
./bin/hfsplus work/ramdisk.raw chmod 100755 usr/lib/libimg4.dylib
if [[ $IDENTIFIER == iPhone11* ]]; then
    sudo ./bin/pzb -g 048-58904-639.dmg https://updates.cdn-apple.com/2020SummerFCS/fullrestores/001-46617/B62CA88B-EB85-4A5A-9440-7E0B90B02006/iPhone10,3,iPhone10,6_14.0_18A373_Restore.ipsw
    ./bin/img4 -i 048-58904-639.dmg -o work/ramdisk2.raw
    sudo rm -rf 048-58904-639.dmg
    ./bin/hfsplus work/ramdisk2.raw extract usr/local/bin/restored_external work/restored_external
    ./bin/ipx_restored_patcher work/restored_external work/restored_patch
    ./bin/ldid -e work/restored_external > work/ents.plist
    ./bin/ldid -Swork/ents.plist work/restored_patch
    ./bin/hfsplus work/ramdisk.raw rm usr/local/bin/restored_external
    ./bin/hfsplus work/ramdisk.raw add work/restored_patch usr/local/bin/restored_external
    ./bin/hfsplus work/ramdisk.raw chmod 100755 usr/local/bin/restored_external
fi
# pack rdsk into im4p
./bin/img4 -i work/ramdisk.raw -o $restore_ramdisk_dmg_18 -A -T rdsk
cd tmp2
zip -0 -r ../custom.ipsw *
cd ..
rm -rf "tmp1"
rm -rf "tmp2"
mv -v custom.ipsw $restoredir/custom.ipsw
rm -rf "work"
ECID=$(./bin/irecovery -q | grep "^ECID:" | cut -d ':' -f2 | xargs)
echo "$VERSION" > boot/$ECID.txt

}

just_boot(){

VERSION=$(cat boot/$ECID.txt)
bootdir="boot/$IDENTIFIER/$VERSION"
if [[ ! -d $bootdir ]]; then
    echo "Please do a tethered restore to iOS $VERSION, then try tether boot again."
    exit 1
fi

if [[ $IDENTIFIER == iPhone10* || $IDENTIFIER == iPhone11* ]]; then
    dfu_helper_a11
else
    dfu_helper
fi
pwn_device

sleep 5

echo "Sending iBSS"
if [[ $IDENTIFIER == iPhone11* || $IDENTIFIER == iPad11* ]]; then
    curl -L -o bin/liter8ctl https://github.com/prdgmshift/usbliter8/raw/refs/heads/main/usbliter8ctl
    python3 bin/liter8ctl boot $bootdir/iBSS.boot
    echo "Device should now boot"
    exit 0
fi
./bin/irecovery -f $bootdir/iBSS.img4
if [[ $IDENTIFIER == iPhone10* ]]; then
    echo "Device should now boot"
    exit 0
fi
sleep 5
echo "Sending iBEC"
./bin/irecovery -f $bootdir/iBEC.img4
sleep 5
echo "Sending DeviceTree"
./bin/irecovery -f $bootdir/DeviceTree.img4
./bin/irecovery -c devicetree
if [[ $VERSION == 12.* || $VERSION == 13.* || $VERSION == 14.* || $VERSION == 15.* ]]; then
    echo "Sending trustcache"
    ./bin/irecovery -f $bootdir/Trustcache.img4
    ./bin/irecovery -c firmware
fi
echo "Sending Kernelcache"
./bin/irecovery -f $bootdir/Kernelcache.img4
./bin/irecovery -c bootx
echo "Device should now boot"
exit 0

}

prepare_boot_files(){

rm -rf "work"
if [[ $IDENTIFIER == iPhone10,1 || $IDENTIFIER == iPhone10,4 ]]; then
    ipsw_url="https://updates.cdn-apple.com/2020WinterFCS/fullrestores/001-87486/23310DA1-A434-4192-87BC-31429FD2D625/iPhone_4.7_P3_14.3_18C66_Restore.ipsw"
elif [[ $IDENTIFIER == iPhone10,2 || $IDENTIFIER == iPhone10,5 ]]; then
    ipsw_url="https://updates.cdn-apple.com/2020WinterFCS/fullrestores/001-87451/EE6AEB4B-1BF7-4FBF-9D29-A8C7B970B495/iPhone_5.5_P3_14.3_18C66_Restore.ipsw"
elif [[ $IDENTIFIER == iPhone10,3 || $IDENTIFIER == iPhone10,6 ]]; then
    ipsw_url="https://updates.cdn-apple.com/2020WinterFCS/fullrestores/001-87865/458334F5-D8E1-498A-A9FD-08BBD20FE007/iPhone10,3,iPhone10,6_14.3_18C66_Restore.ipsw"
fi
IBSS_KEY=$(grep "ibss-$VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)
IBEC_KEY=$(grep "ibec-$VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)
bootdir="boot/$IDENTIFIER/$VERSION"
if [[ $VERSION == 10.2* || $VERSION == 10.1* ]]; then
    krnl="$KERNEL10"
    unzip -j "$IPSW_PATH" "Firmware/dfu/$IBSS10" -d work
    unzip -j "$IPSW_PATH" "Firmware/dfu/$IBEC10" -d work
    unzip -j "$IPSW_PATH" "Firmware/all_flash/$ALLFLASH/$DEVICETREE" -d work
    ./bin/img4 -i work/$IBSS10 -o work/iBSS.raw -k $IBSS_KEY
    ./bin/img4 -i work/$IBEC10 -o work/iBEC.raw -k $IBEC_KEY
else
    krnl="$KERNEL"
    unzip -j "$IPSW_PATH" "Firmware/dfu/$IBSS" -d work
    unzip -j "$IPSW_PATH" "Firmware/dfu/$IBEC" -d work
    unzip -j "$IPSW_PATH" "Firmware/all_flash/$DEVICETREE" -d work
    if [[ $IDENTIFIER == iPhone10* ]] && [[ $VERSION == 14.0 ]]; then # just for 14.0 beta 4 restore
        cd work
        sudo ../bin/pzb -g Firmware/dfu/$IBSS $ipsw_url
        sudo ../bin/pzb -g Firmware/dfu/$IBEC $ipsw_url
        cd ..
    fi
    ./bin/img4 -i work/$IBSS -o work/iBSS.raw -k $IBSS_KEY
    ./bin/img4 -i work/$IBEC -o work/iBEC.raw -k $IBEC_KEY
fi
if [[ $VERSION == 10.* || $VERSION == 11.* || $VERSION == 12.* ]]; then
    ibootpatcher="kairos"
else
    ibootpatcher="iBoot64Patcher"
fi
rm -rf "$bootdir"
mkdir -p boot
mkdir -p boot/$IDENTIFIER
mkdir -p boot/$IDENTIFIER/$VERSION
if [[ $VERSION == 12.* || $VERSION == 13.* || $VERSION == 14.* || $VERSION == 15.* ]]; then
    unzip -j "$IPSW_PATH" "Firmware/*.dmg.trustcache" -d work
    trustcache_use=$(ls -S work/*.trustcache 2>/dev/null | head -n 1)
    ./bin/img4 -i $trustcache_use -o $bootdir/Trustcache.img4
fi
unzip -j "$IPSW_PATH" "$krnl" -d work
./bin/$ibootpatcher work/iBSS.raw work/iBSS.patch
./bin/$ibootpatcher work/iBEC.raw work/iBEC.patch -b "-v" 
if [[ $IDENTIFIER == iPhone10* ]]; then
    ./bin/iBoot64Patcher work/iBSS.raw work/iBSS.patch -l -b "-v"
fi
./bin/img4 -i work/iBSS.patch -o $bootdir/iBSS.img4 -A -T ibss -M $im4m
./bin/img4 -i work/iBEC.patch -o $bootdir/iBEC.img4 -A -T ibec -M $im4m
./bin/img4 -i work/$DEVICETREE -o $bootdir/DeviceTree.img4 -T rdtr -M $im4m
./bin/img4 -i work/$krnl -o $bootdir/Kernelcache.img4 -T rkrn -M $im4m
if [[ $VERSION == 14.* ]] && [[ $IDENTIFIER == iPad5* ]]; then
    ./bin/img4 -i work/$krnl -o work/kernel.raw
    ./bin/Kernel64Patcher work/kernel.raw work/kernel.patch -b
    ./bin/kerneldiff work/kernel.raw work/kernel.patch work/kernel.diff
    ./bin/img4 -i work/$krnl -o $bootdir/Kernelcache.img4 -T rkrn -M $im4m -P work/kernel.diff -J || true
elif [[ $VERSION == 15.* ]] && [[ $IDENTIFIER == iPad5* ]]; then
    ./bin/img4 -i work/$krnl -o work/kernel.raw
    ./bin/Kernel64Patcher work/kernel.raw work/kernel.patch -e -o -r -b15
    ./bin/kerneldiff work/kernel.raw work/kernel.patch work/kernel.diff
    ./bin/img4 -i work/$krnl -o $bootdir/Kernelcache.img4 -T rkrn -M $im4m -P work/kernel.diff -J || true
elif [[ $VERSION == 13.* ]] && [[ $IDENTIFIER == iPad5* ]]; then
    ./bin/img4 -i work/$krnl -o work/kernel.raw
    ./bin/Kernel64Patcher work/kernel.raw work/kernel.patch -b13 -n
    ./bin/kerneldiff work/kernel.raw work/kernel.patch work/kernel.diff
    ./bin/img4 -i work/$krnl -o $bootdir/Kernelcache.img4 -T rkrn -M $im4m -P work/kernel.diff -J || true
fi
if [[ $IDENTIFIER == iPad5,3 || $IDENTIFIER == iPad5,4 ]] && [[ $VERSION == 11.* ]]; then
    ./bin/img4 -i work/$krnl -o work/kernel.raw
    ./bin/Kernel64Patcher2 work/kernel.raw work/kernel.patch -u 11 --skip-sks --skip-acm --skip-amfi
    ./bin/kerneldiff work/kernel.raw work/kernel.patch work/kernel.diff
    ./bin/img4 -i work/$krnl -o $bootdir/Kernelcache.img4 -T rkrn -M $im4m -P work/kernel.diff -J || true
fi
if [[ $IDENTIFIER == iPad5,1 || $IDENTIFIER == iPad5,2 || $IDENTIFIER == iPhone7* ]] && [[ $VERSION == 10.* ]]; then
    ./bin/img4 -i work/$krnl -o work/kernel.raw
    ./bin/Kernel64Patcher2 work/kernel.raw work/kernel.patch -u 11 --skip-sks --skip-acm --skip-amfi
    ./bin/kerneldiff work/kernel.raw work/kernel.patch work/kernel.diff
    ./bin/img4 -i work/$krnl -o $bootdir/Kernelcache.img4 -T rkrn -M $im4m -P work/kernel.diff -J || true
fi

}

do_tethered_restore(){

if [[ -z "$IPSW_PATH" ]]; then
    echo "No IPSW selected. Aborting."
    exit 1
fi
if [[ ! -f "$IPSW_PATH" ]]; then
    echo "IPSW does not exist: $IPSW_PATH"
    exit 1
fi
if [[ -z "$IPSW_PATH_LATEST" ]]; then
    echo "Latest IPSW is not selected. Aborting."
    exit 1
fi
if [[ ! -f "$IPSW_PATH_LATEST" ]]; then
    echo "Latest IPSW does not exist: $IPSW_PATH_LATEST"
    exit 1
fi

if [[ $IDENTIFIER == iPhone10* ]] && [[ $VERSION == 14.3* || $VERSION == 14.4* || $VERSION == 14.5* || $VERSION == 14.6* || $VERSION == 14.7* || $VERSION == 14.8* || $VERSION == 15.* ]]; then
    echo "SEP is partially incompatible, read the following:"
    echo "The device will be unable to activate after the restore."
    echo "You will need to tether restore to 14.0 beta 4 first, activate the device, then tether restore to the desired version."
    echo "Sideloading outside of TrollStore may or may not work, your mileage may vary."
    echo "And potentially other broken features"
    echo "You cannot set a Passcode or use Touch ID because of BPR being enforced"
    read -p "Press enter to continue"
elif [[ $IDENTIFIER == iPad5* ]] && [[ $VERSION == 14.* || $VERSION == 15.* ]]; then
    echo "Your device may have deep sleep issues after this restore"
    read -p "Press enter to continue"
elif [[ $IDENTIFIER == iPad5* ]] && [[ $VERSION == 13.* ]]; then
    echo "Your device may have deep sleep issues after this restore"
    echo "Touch ID will not work"
    read -p "Press enter to continue"
elif [[ $IDENTIFIER == iPad5* ]] && [[ $VERSION == 12.* || $VERSION == 11.4* || $VERSION == 11.3* ]]; then
    echo "Touch ID will not work"
    if [[ $IDENTIFIER == iPad5,3 || $IDENTIFIER == iPad5,4 ]] && [[ $VERSION == 12.* ]]; then
        echo "USB accessories will not work"
        echo "Your device may have deep sleep issues after this restore"
    fi
    read -p "Press enter to continue"
elif [[ $IDENTIFIER == iPad5,1 || $IDENTIFIER == iPad5,2 || $IDENTIFIER == iPhone7* ]] && [[ $VERSION == 10.* ]]; then
    echo "Touch ID will not work"
    read -p "Press enter to continue"
fi

if [[ $IDENTIFIER == iPhone10* ]] && [[ $VERSION == 14.0* || $VERSION == 14.1* || $VERSION == 14.2* ]] && [[ $BUILD != 18A5342e ]]; then
    echo "14.2 and lower downgrades are unsupported, except for 14.0 beta 4"
    if [[ $VERSION == 13.* || $VERSION == 12.* || $VERSION == 11.* ]]; then
        echo "Also, 14.3 iBoot workaround does not work on 13.x and lower. SEP is totally incompatible"
    fi
    exit 1
fi
if [[ $IDENTIFIER == iPhone6* || $IDENTIFIER == iPad4* ]] && [[ $VERSION == 10.3.3 ]] && [[ $BUILD == 14G60 ]]; then
    echo "10.3.3 tether downgrades are not supported on this device."
    if [[ $IDENTIFIER == iPad4,6 ]]; then
        echo "10.3.3 is also not OTA signed for this device, so you cannot restore to 10.3.3 without saved blobs"
    fi
    exit 1
fi
if [[ $IDENTIFIER == iPad4,6 || $IDENTIFIER == iPad4,7 || $IDENTIFIER == iPad4,8 || $IDENTIFIER == iPad4,9 || $IDENTIFIER == iPad5,3 || $IDENTIFIER == iPad5,4 ]] && [[ $VERSION == 7.* || $VERSION == 8.* || $VERSION == 9.* || $VERSION == 10.* || $VERSION == 11.0* || $VERSION == 11.1* || $VERSION == 11.2* ]]; then
    echo "SEP is incompatible"
    exit 1
elif [[ $IDENTIFIER == iPad5,1 || $IDENTIFIER == iPad5,2 || $IDENTIFIER == iPod7* || $IDENTIFIER == iPhone7* || $IDENTIFIER == iPhone6* || $IDENTIFIER == iPad4,1 || $IDENTIFIER == iPad4,2 || $IDENTIFIER == iPad4,3 || $IDENTIFIER == iPad4,4 || $IDENTIFIER == iPad4,5 ]] && [[ $VERSION == 7.* || $VERSION == 8.* || $VERSION == 9.* || $VERSION == 10.0* || $VERSION == 11.0* || $VERSION == 11.1* || $VERSION == 11.2* ]]; then
    echo "SEP is incompatible"
    exit 1
fi

if [[ $IDENTIFIER == iPad5* ]] && [[ $VERSION == 13.1* || $VERSION == 13.2* || $VERSION == 13.3* ]]; then
    echo "13.x restores below 13.4 are not supported"
    exit 1
fi

if [[ $IDENTIFIER == iPhone10* ]] && [[ $VERSION != 16.6* ]] && [[ $BUILD == 20* ]]; then
    echo "iOS 16.0-16.5.1 restores are unsupported"
    echo "And iOS 16.7.x restores are unsupported"
    exit 1
elif [[ $IDENTIFIER == iPhone10* ]] && [[ $VERSION == 16.6* ]]; then
    echo "You will have some issues with the restore:"
    echo "iMessage/SMS may not work"
    echo "VPNs may not work, and potentially other issues."
    read -p "Press enter to continue"
fi

if [[ $IDENTIFIER == iPad5,3 || $IDENTIFIER == iPad5,4 ]] && [[ $VERSION == 11.* || $VERSION == 12.* ]]; then
    echo "11.3-12.4.1 downgrades are supported but they have not been integrated yet into surrealra1n $CURRENT_VERSION"
    exit 1
fi

if [[ $IDENTIFIER == iPhone10* ]]; then
    dfu_helper_a11
else
    dfu_helper
fi
pwn_device
det_rsep_flag
echo "Fetching shsh blobs for iOS $LATEST_VERSION"
rm -rf "shsh"
mkdir -p shsh
sudo ./bin/tsschecker -d $IDENTIFIER -s -e $ECID -i $LATEST_VERSION --save-path shsh

# Find the .shsh2 file in the shsh directory
SHSH_PATH=$(find shsh -type f -name "*.shsh2" | head -n 1)
if [[ -z "$SHSH_PATH" ]]; then
    echo "No SHSH file found in the shsh folder. Aborting"
    exit 1
fi

restoredir="restorefiles/$IDENTIFIER/$VERSION"

if [[ ! -f "$restoredir/custom.ipsw" ]] && [[ ! -f "$restoredir/ramdisk.im4p" ]] && [[ ! -f "$restoredir/kernel.im4p" ]]; then
    echo "Restore files does not exist, making new ones"
    if [[ $IDENTIFIER == iPhone10* ]] && [[ $VERSION == 16.* ]]; then
        make_custom_ipsw_ios16
    else
        make_custom_ipsw
    fi
else
    echo "Restore files already exist"
    read -p "Would you like to make new ones? (y/n): " restorefiles_remake
    if [[ $restorefiles_remake == Y || $restorefiles_remake == y ]]; then
        rm -rf "$restoredir"
        if [[ $IDENTIFIER == iPhone10* ]] && [[ $VERSION == 16.* ]]; then
            make_custom_ipsw_ios16
        else
            make_custom_ipsw
        fi
    fi
fi

if [[ $IDENTIFIER == iPhone7* || $IDENTIFIER == iPad5* || $IDENTIFIER == iPod7* ]] && [[ $VERSION == 10.* ]]; then
    download_tvos_sep
    prepatch_ibssibec_fr
    while true; do
        sudo FUTURERESTORE_I_SOLEMNLY_SWEAR_THAT_I_AM_UP_TO_NO_GOOD=1 \
            ./futurerestore/futurerestore -t $SHSH_PATH --use-pwndfu \
            --sep $sep_path --sep-manifest $manifest_path --skip-blob --rdsk $restoredir/ramdisk.im4p \
            --custom-latest $LATEST_VERSION \
            --rkrn $restoredir/kernel.im4p $updatebb_flag $rsep_flag $restoredir/custom.ipsw
        EXIT_CODE=$?
        if [[ $EXIT_CODE -eq 139 ]]; then
            echo "futurerestore segfaulted (exit 139), retrying..."
            sleep 2
        else
            break
        fi
    done
elif [[ $IDENTIFIER == iPad4* || $IDENTIFIER == iPhone6* ]] && [[ $VERSION == 10.* ]]; then
    download_1033_ota_sep
    prepatch_ibssibec_fr
    while true; do
        sudo FUTURERESTORE_I_SOLEMNLY_SWEAR_THAT_I_AM_UP_TO_NO_GOOD=1 \
            ./futurerestore/futurerestore -t $SHSH_PATH --use-pwndfu \
            --sep $sep_path --sep-manifest $manifest_path --skip-blob --rdsk $restoredir/ramdisk.im4p \
            --custom-latest $LATEST_VERSION \
            --rkrn $restoredir/kernel.im4p $updatebb_flag $rsep_flag $restoredir/custom.ipsw
        EXIT_CODE=$?
        if [[ $EXIT_CODE -eq 139 ]]; then
            echo "futurerestore segfaulted (exit 139), retrying..."
            sleep 2
        else
            break
        fi
    done
elif [[ $IDENTIFIER == iPad5* ]] && [[ $VERSION == 11.* || $VERSION == 12.* ]]; then
    download_iphone6_sep
    prepatch_ibssibec_fr
    while true; do
        sudo FUTURERESTORE_I_SOLEMNLY_SWEAR_THAT_I_AM_UP_TO_NO_GOOD=1 \
            ./futurerestore/futurerestore -t $SHSH_PATH --use-pwndfu \
            --sep $sep_path --sep-manifest $manifest_path --skip-blob --rdsk $restoredir/ramdisk.im4p \
            --custom-latest $LATEST_VERSION \
            --rkrn $restoredir/kernel.im4p $updatebb_flag $rsep_flag $restoredir/custom.ipsw
        EXIT_CODE=$?
        if [[ $EXIT_CODE -eq 139 ]]; then
            echo "futurerestore segfaulted (exit 139), retrying..."
            sleep 2
        else
            break
        fi
    done
else
    prepatch_ibssibec_fr
    if [[ $IDENTIFIER == iPhone10* ]] && [[ $VERSION == 14.* || $VERSION == 15.* ]] && [[ $BUILD != 18A5342e ]]; then
        ramdisk_det="updateramdisk"
    else
        ramdisk_det="ramdisk"
    fi
    while true; do
        sudo FUTURERESTORE_I_SOLEMNLY_SWEAR_THAT_I_AM_UP_TO_NO_GOOD=1 \
            ./futurerestore/futurerestore -t $SHSH_PATH --use-pwndfu --skip-blob --rdsk $restoredir/$ramdisk_det.im4p \
            --custom-latest $LATEST_VERSION \
            --rkrn $restoredir/kernel.im4p --latest-sep \
            $updatebb_flag $rsep_flag $restoredir/custom.ipsw
        EXIT_CODE=$?
        if [[ $EXIT_CODE -eq 139 ]]; then
            echo "futurerestore segfaulted (exit 139), retrying..."
            sleep 2
        else
            break
        fi
    done
fi

echo "Restore has completed! Read above if there is any errors"
prepare_boot_files
exit 0

}

do_tethered_restore_a12(){

if [[ $dist == 3 || $dist == 4 ]]; then
    echo ""
else
    echo "A12 tether downgrades are unsupported on Linux"
    exit 1
fi

if [[ -z "$IPSW_PATH" ]]; then
    echo "No IPSW selected. Aborting."
    exit 1
fi
if [[ ! -f "$IPSW_PATH" ]]; then
    echo "IPSW does not exist: $IPSW_PATH"
    exit 1
fi
if [[ -z "$IPSW_PATH_LATEST" ]]; then
    echo "Latest IPSW is not selected. Aborting."
    exit 1
fi
if [[ ! -f "$IPSW_PATH_LATEST" ]]; then
    echo "Latest IPSW does not exist: $IPSW_PATH_LATEST"
    exit 1
fi

if [[ $VERSION == 14.* ]]; then
    echo "SEP is partially incompatible, read the following:"
    echo "The device will be unable to activate after the restore."
    echo "Sideloading outside of TrollStore may or may not work, your mileage may vary."
    echo "And potentially other broken features"
    echo "You cannot set a Passcode or use Touch ID because of BPR being enforced"
    read -p "Press enter to continue"
elif [[ $VERSION == 15.* ]]; then
    echo "15.x A12 downgrades are not supported at the moment"
    exit 1
fi

dfu_helper_a11
pwn_device
det_rsep_flag

restoredir="restorefiles/$IDENTIFIER/$VERSION"

if [[ ! -f "$restoredir/custom.ipsw" ]]; then
    echo "Restore files does not exist, making new ones"
    make_custom_ipsw_a12_ios14
else
    echo "Restore files already exist"
    read -p "Would you like to make new ones? (y/n): " restorefiles_remake
    if [[ $restorefiles_remake == Y || $restorefiles_remake == y ]]; then
        rm -rf "$restoredir"
        make_custom_ipsw_a12_ios14
    fi
fi
curl -L -o bin/liter8ctl https://github.com/prdgmshift/usbliter8/raw/refs/heads/main/usbliter8ctl
python3 bin/liter8ctl boot boot/$IDENTIFIER/iBSS.patch
sleep 6
APNONCE=$(./bin/irecovery -q | grep "^NONC:" | cut -d ':' -f2 | xargs)
echo "Fetching shsh blobs for iOS $LATEST_VERSION"
rm -rf "shsh"
mkdir -p shsh
sudo ./bin/tsschecker -d $IDENTIFIER -s -e $ECID -i $LATEST_VERSION --save-path shsh --apnonce $APNONCE
# Find the .shsh2 file in the shsh directory
SHSH_PATH=$(find shsh -type f -name "*.shsh2" | head -n 1)
if [[ -z "$SHSH_PATH" ]]; then
    echo "No SHSH file found in the shsh folder. Aborting"
    exit 1
fi
while true; do
    sudo ./futurerestore/futurerestore -t $SHSH_PATH $rsep_flag --latest-sep $updatebb_flag $restoredir/custom.ipsw
    EXIT_CODE=$?
    if [[ $EXIT_CODE -eq 139 ]]; then
        echo "futurerestore segfaulted (exit 139), retrying..."
        sleep 2
    else
        break
    fi
done
if [[ $EXIT_CODE -eq 0 ]]; then
    echo "Restore has completed! Read above if there are any errors"
    exit 0
else
    echo "futurerestore failed with exit code $EXIT_CODE"
    exit 1
fi
echo "Restore has completed! Read above if there is any errors"
echo "Device will be stuck in DFU"
exit 0

}

prepare_seprmvr64_ipsw_legacy(){

if [[ $VERSION == 7.* ]]; then
    IBSS_2="$IBSS7"
    IBEC_2="$IBEC7"
else
    IBSS_2="$IBSS10"
    IBEC_2="$IBEC10"
fi
if [[ $VERSION == 9.* ]]; then
    ibootpatcher="kairos"
else
    ibootpatcher="ipatcher"
fi
if [[ $VERSION == 7.* ]]; then
    grow_to="2500000000"
elif [[ $VERSION == 8.* ]]; then
    grow_to="3200000000"
fi

mkdir -p noseprestore
mkdir -p noseprestore/$IDENTIFIER
mkdir -p noseprestore/$IDENTIFIER/$VERSION
IBSS_KEY=$(grep "ibss-$VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)
IBEC_KEY=$(grep "ibec-$VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)
DTRE_KEY=$(grep "dtre-$VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)
RDSK_KEY=$(grep "rdsk-$VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)
KRNL_KEY=$(grep "krnl-$VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)
ROOT_KEY=$(grep "fstm-$VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)
unzip "$IPSW_PATH" -d tmp1
unzip "$IPSW_PATH_LATEST" -d tmp2
# ramdisk handling
smallestlatest_dmg=$(find_dmg tmp2 smallest)
rootfs_dmg=$(find_dmg tmp1 largest)
rootfslatest_dmg=$(find_dmg tmp2 largest)
if [[ $VERSION == 7.0* ]]; then
    smallest_dmg=$(find_dmg tmp1 largest 10370000)
else
    smallest_dmg=$(find_dmg tmp1 smallest)
fi
./bin/img4 -i tmp1/Firmware/dfu/$IBSS_2 -o tmp1/iBSS.raw -k $IBSS_KEY
./bin/img4 -i tmp1/Firmware/dfu/$IBEC_2 -o tmp1/iBEC.raw -k $IBEC_KEY
./bin/$ibootpatcher tmp1/iBSS.raw tmp1/iBSS.patch
./bin/$ibootpatcher tmp1/iBEC.raw tmp1/iBEC.patch -b "rd=md0 debug=0x2014e -v wdt=-1 nand-enable-reformat=1 -restore amfi=0xff cs_enforcement_disable=1"
./bin/img4 -i tmp1/iBSS.patch -o tmp2/Firmware/dfu/$IBSS -A -T ibss
./bin/img4 -i tmp1/iBEC.patch -o tmp2/Firmware/dfu/$IBEC -A -T ibec
./bin/img4 -i tmp1/Firmware/all_flash/$ALLFLASH/$DEVICETREE -o tmp1/DeviceTree.raw -k $DTRE_KEY
perl -pi -e 's/content-protect/content-protecV/g' tmp1/DeviceTree.raw
./bin/img4 -i tmp1/DeviceTree.raw -o tmp2/Firmware/all_flash/$DEVICETREE -A -T rdtr
./bin/img4 -i tmp1/$KERNEL10 -o tmp1/kernel.raw -k $KRNL_KEY
./bin/img4 -i tmp1/$KERNEL10 -o tmp1/kernel.im4p -k $KRNL_KEY -D
if [[ $VERSION == 7.* ]]; then
    ./bin/Kernel64Patcher2 tmp1/kernel.raw tmp1/kernel.patch -u 7 -m 7 -e 7 -f 7 -k
elif [[ $VERSION == 8.* ]]; then
    ./bin/Kernel64Patcher2 tmp1/kernel.raw tmp1/kernel.patch -u 8 -t -p -e 8 -f 8 -a -m 8 -g -s -d
else
    ./bin/Kernel64Patcher2 tmp1/kernel.raw tmp1/kernel.patch -u 9 -f 9 -k -v
fi
./bin/kerneldiff tmp1/kernel.raw tmp1/kernel.patch tmp1/kernel.diff
./bin/img4 -i tmp1/kernel.im4p -o tmp2/$KERNEL -T rkrn -P tmp1/kernel.diff -J || true
./bin/img4 -i $smallest_dmg -o tmp1/ramdisk.raw -k $RDSK_KEY
./bin/hfsplus tmp1/ramdisk.raw grow 40000000
./bin/hfsplus tmp1/ramdisk.raw extract usr/sbin/asr tmp1/asr
./bin/asr64_patcher tmp1/asr tmp1/asr_patched
if [[ $VERSION == 8.* || $VERSION == 9.* ]]; then
    ./bin/ldid -e tmp1/asr > tmp1/ents.plist
    ./bin/ldid -Stmp1/ents.plist tmp1/asr_patched
fi
./bin/hfsplus tmp1/ramdisk.raw rm usr/sbin/asr
./bin/hfsplus tmp1/ramdisk.raw add tmp1/asr_patched usr/sbin/asr
./bin/hfsplus tmp1/ramdisk.raw chmod 100755 usr/sbin/asr
./bin/img4 -i tmp1/ramdisk.raw -o $smallestlatest_dmg -A -T rdsk
rm -rf $rootfslatest_dmg
./bin/dmg extract $rootfs_dmg tmp1/rootfs.raw -k $ROOT_KEY
if [[ $VERSION == 7.* || $VERSION == 8.* ]]; then
    ./bin/hfsplus tmp1/rootfs.raw grow $grow_to
fi
if [[ $VERSION == 9.* ]]; then
    echo "Skipping removal of powerd"
else
    # Try and work around deep sleep issues without jailbreak
    echo "Removing powerd"
    ./bin/hfsplus tmp1/rootfs.raw rm System/Library/CoreServices/powerd.bundle/powerd
    ./bin/hfsplus tmp1/rootfs.raw rm System/Library/LaunchDaemons/com.apple.powerd.plist
fi
./bin/dmg build tmp1/rootfs.raw $rootfslatest_dmg
cd tmp2
zip -0 -r ../$restoredir/$ipsw_custom *
cd ..
rm -rf "tmp1"
rm -rf "tmp2"

}

prepare_boot_files_seprmvr64(){

if [[ $VERSION == 7.* ]]; then
    IBSS_2="$IBSS7"
    IBEC_2="$IBEC7"
else
    IBSS_2="$IBSS10"
    IBEC_2="$IBEC10"
fi
if [[ $VERSION == 9.* ]]; then
    ibootpatcher="kairos"
else
    ibootpatcher="ipatcher"
fi
IBSS_KEY=$(grep "ibss-$VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)
IBEC_KEY=$(grep "ibec-$VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)
DTRE_KEY=$(grep "dtre-$VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)
KRNL_KEY=$(grep "krnl-$VERSION:" "$KEY_FILE" | cut -d':' -f2 | xargs)
bootdir="boot/$IDENTIFIER/$VERSION"
mkdir -p boot
mkdir -p boot/$IDENTIFIER
mkdir -p boot/$IDENTIFIER/$VERSION
unzip -j "$IPSW_PATH" "Firmware/dfu/$IBSS_2" -d work
unzip -j "$IPSW_PATH" "Firmware/dfu/$IBEC_2" -d work
unzip -j "$IPSW_PATH" "Firmware/all_flash/$ALLFLASH/$DEVICETREE" -d work
unzip -j "$IPSW_PATH" "$KERNEL10" -d work
./bin/img4 -i work/$IBSS_2 -o work/iBSS.raw -k $IBSS_KEY
./bin/img4 -i work/$IBEC_2 -o work/iBEC.raw -k $IBEC_KEY
./bin/img4 -i work/$DEVICETREE -o work/DeviceTree.im4p -k $DTRE_KEY -D
./bin/img4 -i work/$KERNEL10 -o work/kernel.raw -k $KRNL_KEY
./bin/img4 -i work/$KERNEL10 -o work/kernel.im4p -k $KRNL_KEY -D
./bin/$ibootpatcher work/iBSS.raw work/iBSS.patch
./bin/$ibootpatcher work/iBEC.raw work/iBEC.patch -b "-v"
./bin/img4 -i work/iBSS.patch -o $bootdir/iBSS.img4 -A -T ibss -M $im4m
./bin/img4 -i work/iBEC.patch -o $bootdir/iBEC.img4 -A -T ibec -M $im4m
./bin/img4 -i work/DeviceTree.im4p -o $bootdir/DeviceTree.img4 -T rdtr -M $im4m
if [[ $VERSION == 7.* ]]; then
    ./bin/Kernel64Patcher2 work/kernel.raw work/kernel.patch -u 7 -m 7 -e 7 -f 7 -k
elif [[ $VERSION == 8.* ]]; then
    ./bin/Kernel64Patcher2 work/kernel.raw work/kernel.patch -u 8 -t -p -e 8 -f 8 -a -m 8 -g -s -d
else
    ./bin/Kernel64Patcher2 work/kernel.raw work/kernel.patch -u 9 -f 9 -k -v
fi
./bin/kerneldiff work/kernel.raw work/kernel.patch work/kernel.diff
./bin/img4 -i work/kernel.im4p -o $bootdir/Kernelcache.img4 -T rkrn -P work/kernel.diff -J -M $im4m || true
rm -rf "work"

}

do_tethered_seprmvr64_restore(){

if [[ -z "$IPSW_PATH" ]]; then
    echo "No IPSW selected. Aborting."
    exit 1
fi
if [[ ! -f "$IPSW_PATH" ]]; then
    echo "IPSW does not exist: $IPSW_PATH"
    exit 1
fi
if [[ -z "$IPSW_PATH_LATEST" ]]; then
    echo "Latest IPSW is not selected. Aborting."
    exit 1
fi
if [[ ! -f "$IPSW_PATH_LATEST" ]]; then
    echo "Latest IPSW does not exist: $IPSW_PATH_LATEST"
    exit 1
fi

echo "Here is the following things that may happen on seprmvr64 restore:"
echo "1. Touch ID will not work"
echo "2. Passcode will not work"
echo "3. Password protected Wi-Fi networks will not work"
echo "4. Battery life may be affected on iOS 7/8, because we use a workaround there to make deep sleep panics not occur"
echo "5. Potentially other broken features"
read -p "Press enter to continue"
if [[ $IDENTIFIER == iPhone7* || $IDENTIFIER == iPad5* || $IDENTIFIER == iPod7* ]]; then
    echo "A8 is currently unsupported as we are rewriting surrealra1n, but it should be back eventually."
    exit 1
fi

restoredir="noseprestore/$IDENTIFIER/$VERSION"
stitch_activation=0
if [[ $JAILBREAK == 1 ]] && [[ $stitch_activation != 1 ]]; then
    ipsw_custom="customJB.ipsw"
elif [[ $JAILBREAK == 1 ]] && [[ $stitch_activation == 1 ]]; then
    ipsw_custom="customJB_$ECID.ipsw"
elif [[ $JAILBREAK != 1 ]] && [[ $stitch_activation == 1 ]]; then
    ipsw_custom="custom_$ECID.ipsw"
else
    ipsw_custom="custom.ipsw"
fi

if [[ ! -f "$restoredir/$ipsw_custom" ]]; then
    echo "Restore files does not exist, making new ones"
    prepare_seprmvr64_ipsw_legacy
else
    echo "Restore files already exist"
    read -p "Would you like to make new ones? (y/n): " restorefiles_remake
    if [[ $restorefiles_remake == Y || $restorefiles_remake == y ]]; then
        rm -rf "$restoredir"
        prepare_seprmvr64_ipsw_legacy
    fi
fi

rm -rf "shsh"
mkdir -p shsh
sudo ./bin/tsschecker -d $IDENTIFIER -s -e $ECID -i $LATEST_VERSION --save-path shsh
# Find the .shsh2 file in the shsh directory
SHSH_PATH=$(find shsh -type f -name "*.shsh2" | head -n 1)
if [[ -z "$SHSH_PATH" ]]; then
    echo "No SHSH file found in the shsh folder. Aborting"
    exit 1
fi
./bin/img4tool -s "$SHSH_PATH" -e -m "$IDENTIFIER-im4m"
im4m="$IDENTIFIER-im4m"

dfu_helper
pwn_device
sleep 5
sudo LD_LIBRARY_PATH="lib" ./bin/idevicerestore -ey $restoredir/$ipsw_custom
echo "Restore has finished! Read above if there's any errors"
prepare_boot_files_seprmvr64
exit 0

}

seprmvr64_opts(){

clear 
echo "$INFO_TEXT"
echo ""
echo "This feature uses seprmvr64 by Mineek"
echo "All SEP functionality will be disabled"
echo ""
echo "Options:"
echo ""
echo "1. Select Target IPSW"
echo "2. Select Base IPSW"
echo "3. Start Restore"
echo "4. Back"
read -p "Please input an option (1-4): " tether_options
if [[ $tether_options == 1 ]]; then
    IPSW_PATH=$($zenity --file-selection --title="Select an IPSW file")
    if [[ -z "$IPSW_PATH" ]]; then
        echo "No IPSW selected. Aborting."
        exit 1
    fi
    rm -rf work/BuildManifest.plist
    unzip -j "$IPSW_PATH" "BuildManifest.plist" -d work
    VERSION=$(grep -A1 "ProductVersion" work/BuildManifest.plist | grep -o '<string>[^<]*</string>' | head -1 | sed 's/<[^>]*>//g')
    if [[ $VERSION == 8.* || $VERSION == 10.* || $VERSION == 11.* || $VERSION == 12.* || $VERSION == 13.* || $VERSION == 14.* || $VERSION == 15.* ]]; then
        echo "iOS 10 and later are unsupported, and iOS 8 is unsupported."
        exit 1
    fi
    if [[ $IDENTIFIER == iPhone6,2 ]] && [[ $VERSION == 9.3 ]] && [[ $BUILD != 13E237 ]]; then
        echo "9.3 ($BUILD) is unsupported"
        exit 1
    elif [[ $IDENTIFIER == iPhone6,1 ]] && [[ $VERSION == 9.3 ]] && [[ $BUILD != 13E233 ]]; then
        echo "9.3 ($BUILD) is unsupported"
        exit 1
    elif [[ $IDENTIFIER == iPad4* ]] && [[ $VERSION == 9.3 ]] && [[ $BUILD != 13E233 ]]; then
        echo "9.3 ($BUILD) is unsupported"
        exit 1
    fi
    seprmvr64_opts
elif [[ $tether_options == 2 ]]; then
    IPSW_PATH_LATEST=$($zenity --file-selection --title="Select iOS $LATEST_VERSION IPSW file")
    if [[ -z "$IPSW_PATH_LATEST" ]]; then
        echo "No IPSW selected. Aborting."
        exit 1
    fi
    rm -rf work/BuildManifest.plist
    unzip -j "$IPSW_PATH_LATEST" "BuildManifest.plist" -d work
    VERSION_LATEST=$(grep -A1 "ProductVersion" work/BuildManifest.plist | grep -o '<string>[^<]*</string>' | head -1 | sed 's/<[^>]*>//g')
    if [[ $VERSION_LATEST != $LATEST_VERSION ]]; then
        echo "Invalid IPSW. You must select IPSW for iOS $LATEST_VERSION, not iOS $VERSION_LATEST"
        exit 1
    fi
    seprmvr64_opts
elif [[ $tether_options == 3 ]]; then
    if [[ $VERSION == 7.* ]]; then
        read -p "Would you like to jailbreak? (Y/n): " jelbrek_opt
        if [[ $jelbrek_opt == Y || $jelbrek_opt == y ]]; then
            echo "Jailbreak option is enabled."
            if [[ $VERSION == 9.* ]]; then
                echo "This will only bootstrap the device."
                echo "To get into a jailbroken state, you need to use http://jbme.ddw.nu afterwards. This is semi-untethered"
            fi
            JAILBREAK=1
            sleep 5
        else
            echo "Jailbreak option is disabled."
            sleep 5
        fi
    fi
    do_tethered_seprmvr64_restore
elif [[ $tether_options == 4 ]]; then
    reset_restore_vars
    restore_tethered_opts
else
    echo "Invalid option. Exiting."
    exit 0
fi

}

restore_tethered_opts(){

clear 
echo "$INFO_TEXT"
echo ""
echo "Options:"
echo ""
echo "1. Select Target IPSW"
echo "2. Select Base IPSW"
echo "3. Start Restore"
echo "4. seprmvr64 options"
echo "5. Back"
read -p "Please input an option (1-5): " tether_options
if [[ $tether_options == 1 ]]; then
    IPSW_PATH=$($zenity --file-selection --title="Select an IPSW file")
    if [[ -z "$IPSW_PATH" ]]; then
        echo "No IPSW selected. Aborting."
        exit 1
    fi
    rm -rf work/BuildManifest.plist
    unzip -j "$IPSW_PATH" "BuildManifest.plist" -d work
    BUILD=$(grep -A1 "ProductBuildVersion" work/BuildManifest.plist | grep -o '<string>[^<]*</string>' | head -1 | sed 's/<[^>]*>//g')
    VERSION=$(grep -A1 "ProductVersion" work/BuildManifest.plist | grep -o '<string>[^<]*</string>' | head -1 | sed 's/<[^>]*>//g')
    restore_tethered_opts
elif [[ $tether_options == 2 ]]; then
    IPSW_PATH_LATEST=$($zenity --file-selection --title="Select iOS $LATEST_VERSION IPSW file")
    if [[ -z "$IPSW_PATH_LATEST" ]]; then
        echo "No IPSW selected. Aborting."
        exit 1
    fi
    rm -rf work/BuildManifest.plist
    unzip -j "$IPSW_PATH_LATEST" "BuildManifest.plist" -d work
    VERSION_LATEST=$(grep -A1 "ProductVersion" work/BuildManifest.plist | grep -o '<string>[^<]*</string>' | head -1 | sed 's/<[^>]*>//g')
    if [[ $VERSION_LATEST != $LATEST_VERSION ]]; then
        echo "Invalid IPSW. You must select IPSW for iOS $LATEST_VERSION, not iOS $VERSION_LATEST"
        exit 1
    fi
    restore_tethered_opts
elif [[ $tether_options == 3 ]]; then
    if [[ $IDENTIFIER == iPhone11* || $IDENTIFIER == iPad11* ]]; then
        do_tethered_restore_a12
    else
        do_tethered_restore
    fi
elif [[ $tether_options == 4 ]]; then
    seprmvr64_opts
elif [[ $tether_options == 5 ]]; then
    reset_restore_vars
    restore_utils
else
    echo "Invalid option. Exiting."
    exit 0
fi

}

restore_a7_to_1033(){

if [[ -z "$IPSW_PATH" ]]; then
    echo "No IPSW selected. Aborting."
    exit 1
fi
if [[ ! -f "$IPSW_PATH" ]]; then
    echo "IPSW does not exist: $IPSW_PATH"
    exit 1
fi
dfu_helper
pwn_device
download_1033_ota_sep
rm -rf "shsh"
mkdir -p shsh
sudo ./bin/tsschecker -d $IDENTIFIER -i 10.3.3 -e $ECID -o -m tmp/BuildManifest-SEP.plist -s --save-path shsh
# Find the .shsh2 file in the shsh directory
SHSH_PATH=$(find shsh -type f -name "*.shsh2" | head -n 1)
if [[ -z "$SHSH_PATH" ]]; then
    echo "No SHSH file found in the shsh folder. Aborting"
    exit 1
fi
det_rsep_flag
prepatch_ibssibec_fr
while true; do
    sudo FUTURERESTORE_I_SOLEMNLY_SWEAR_THAT_I_AM_UP_TO_NO_GOOD=1 \
        ./futurerestore/futurerestore -t $SHSH_PATH --use-pwndfu \
        --sep $sep_path --sep-manifest $manifest_path \
        --custom-latest $LATEST_VERSION \
        $updatebb_flag $rsep_flag $IPSW_PATH
    EXIT_CODE=$?
    if [[ $EXIT_CODE -eq 139 ]]; then
        echo "futurerestore segfaulted (exit 139), retrying..."
        sleep 2
    else
        break
    fi
done
if [[ $EXIT_CODE -eq 0 ]]; then
    echo "Restore has completed! Read above if there are any errors"
    exit 0
else
    echo "futurerestore failed with exit code $EXIT_CODE"
    exit 1
fi


}

restore_a7_options(){

if [[ $IDENTIFIER == iPhone6* || $IDENTIFIER == iPad4,1 || $IDENTIFIER == iPad4,2 || $IDENTIFIER == iPad4,3 || $IDENTIFIER == iPad4,4 || $IDENTIFIER == iPad4,5 ]]; then
    clear
else
    restore_utils
    return
fi
 
echo "$INFO_TEXT"
echo "This OTA restore will use $LATEST_VERSION baseband"
echo ""
echo "Options:"
echo ""
echo "1. Select 10.3.3 IPSW"
echo "2. Start Restore"
echo "3. Back"
read -p "Please input an option (1-3): " restore_a7_options_choice
if [[ $restore_a7_options_choice == 1 ]]; then
    IPSW_PATH=$($zenity --file-selection --title="Select an IPSW file")
    if [[ -z "$IPSW_PATH" ]]; then
        echo "No IPSW selected. Aborting."
        exit 1
    fi
    rm -rf work/BuildManifest.plist
    unzip -j "$IPSW_PATH" "BuildManifest.plist" -d work
    BUILD=$(grep -A1 "ProductBuildVersion" work/BuildManifest.plist | grep -o '<string>[^<]*</string>' | head -1 | sed 's/<[^>]*>//g')
    VERSION=$(grep -A1 "ProductVersion" work/BuildManifest.plist | grep -o '<string>[^<]*</string>' | head -1 | sed 's/<[^>]*>//g')
    if [[ $VERSION == 10.3.3 ]] && [[ $BUILD == 14G60 ]]; then
        restore_a7_options
    else
        echo "IPSW is invalid"
        sleep 2
        reset_restore_vars
        restore_a7_options
    fi
elif [[ $restore_a7_options_choice == 2 ]]; then
    restore_a7_to_1033
elif [[ $restore_a7_options_choice == 3 ]]; then
    reset_restore_vars
    restore_utils
fi

}

restore_utils(){

if [[ $outdated == 1 ]]; then
    echo "This surrealra1n beta has expired"
    echo "A newer beta is available. Please update to continue."
    echo "You will need to exit, re-run surrealra1n.sh, and when it prompts for an update, update surrealra1n."
    sleep 10
    main_menu
    return
fi

if [[ $IDENTIFIER == NONE ]]; then
    main_menu
    return
fi

if [[ $IDENTIFIER == iPhone11* || $IDENTIFIER == iPad11* ]]; then
    echo "A12 device support is entirely experimental."
    echo "Expect to have issues or bugs."
    read -p "Press enter to continue"
fi

clear 
echo "$INFO_TEXT"
echo ""
echo "Options:"
echo ""
echo "1. Restore (with SHSH blobs)"
echo "2. Restore (Tethered)"
echo "3. Restore to 10.3.3 untethered (some A7 devices only)"
echo "4. Just Boot"
echo "5. Back"
read -p "Please input an option (1-5): " restore_options
if [[ $restore_options == 1 ]]; then
    restore_untethered_opts
elif [[ $restore_options == 2 ]]; then
    restore_tethered_opts
elif [[ $restore_options == 3 ]]; then
    restore_a7_options
elif [[ $restore_options == 4 ]]; then
    just_boot
elif [[ $restore_options == 5 ]]; then
    main_menu
else
    echo "Invalid option. Exiting."
    exit 1
fi

}

main_menu(){

clear
echo "$INFO_TEXT"
echo ""
echo "Options:"
echo ""
echo "1. Downgrade Options"
echo "2. Misc Utilities"
echo "3. Switch to main branch"
echo "4. Exit"
read -p "Please input an option (1-4): " option
if [[ $option == 1 ]]; then
    restore_utils
elif [[ $option == 2 ]]; then
    misc_utils
elif [[ $option == 3 ]]; then
    switch_to_main
elif [[ $option == 4 ]]; then
    echo "surrealra1n is exiting"
    exit 0
else
    echo "Invalid option. Exiting."
    exit 1
fi

}

main_menu
