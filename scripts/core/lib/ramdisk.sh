#!/usr/bin/env bash

install_sshrd_script_if_missing() {
    local clone_root="$PROJECT_ROOT/sshrd"
    local clone_target="$clone_root/SSHRD_Script"

    mkdir -p "$clone_root"
    if [[ ! -d "$clone_target/.git" ]]; then
        rm -rf "$clone_target"
        echo "[*] Cloning SSHRD_Script to $clone_target ..." >&2
        git clone https://github.com/verygenericname/SSHRD_Script "$clone_target"
    fi

    printf '%s\n' "$clone_target"
}

download_sshpass_binary() {
    local url
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"

    mkdir -p "$PROJECT_ROOT/bin"

    if [[ "$os" == "Darwin" ]]; then
        url="https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/macos/sshpass"
        if curl -fL -o "$PROJECT_ROOT/bin/sshpass" "$url"; then
            chmod +x "$PROJECT_ROOT/bin/sshpass"
            return
        fi
    elif [[ "$os" == "Linux" ]]; then
        if [[ "$arch" == "x86_64" ]]; then
            url="https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/linux/x86_64/sshpass"
            if curl -fL -o "$PROJECT_ROOT/bin/sshpass" "$url"; then
                chmod +x "$PROJECT_ROOT/bin/sshpass"
                return
            fi
        fi

        # Fallback attempt for non-x86 Linux hosts.
        url="https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/linux/arm64/sshpass"
        if curl -fL -o "$PROJECT_ROOT/bin/sshpass" "$url"; then
            chmod +x "$PROJECT_ROOT/bin/sshpass"
            return
        fi
    fi

    return 1
}

download_core_ramdisk_binary() {
    local binary="$1"
    local os arch semaphorin_platform lik_platform url=""
    os="$(uname -s)"
    arch="$(uname -m)"

    if [[ "$os" == "Darwin" ]]; then
        semaphorin_platform="Darwin"
        lik_platform="macos"
    elif [[ "$os" == "Linux" ]]; then
        semaphorin_platform="Linux"
        if [[ "$arch" == "x86_64" ]]; then
            lik_platform="linux/x86_64"
        elif [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
            lik_platform="linux/arm64"
        else
            lik_platform="linux/x86_64"
        fi
    else
        return 1
    fi

    case "$binary" in
        dsc64patcher|irecovery)
            url="https://github.com/LukeZGD/Semaphorin/raw/refs/heads/main/$semaphorin_platform/$binary"
            ;;
        gaster)
            url="https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/bin/$lik_platform/gaster"
            ;;
        *)
            return 1
            ;;
    esac

    mkdir -p "$PROJECT_ROOT/bin"
    if curl -fL -o "$PROJECT_ROOT/bin/$binary" "$url"; then
        chmod +x "$PROJECT_ROOT/bin/$binary"
        return
    fi

    return 1
}

ensure_required_ramdisk_binary() {
    local binary="$1"

    mkdir -p "$PROJECT_ROOT/bin"

    if [[ -x "$PROJECT_ROOT/bin/$binary" ]]; then
        return
    fi

    if command -v "$binary" >/dev/null 2>&1; then
        cp "$(command -v "$binary")" "$PROJECT_ROOT/bin/$binary" || true
        chmod +x "$PROJECT_ROOT/bin/$binary" || true
        if [[ -x "$PROJECT_ROOT/bin/$binary" ]]; then
            return
        fi
    fi

    if [[ "$binary" == "sshpass" ]]; then
        echo "[*] sshpass missing. Trying automatic install..."
        if [[ "$(uname -s)" == "Darwin" ]]; then
            if command -v brew >/dev/null 2>&1; then
                brew install hudochenkov/sshpass/sshpass || true
            fi
        elif [[ -r /etc/os-release ]]; then
            # shellcheck disable=SC1091
            . /etc/os-release
            if [[ "${ID:-}" == "arch" || "${ID_LIKE:-}" == *"arch"* ]]; then
                sudo pacman -S --needed sshpass || true
            else
                sudo apt update || true
                sudo apt install -y sshpass || true
            fi
        fi

        if command -v sshpass >/dev/null 2>&1; then
            cp "$(command -v sshpass)" "$PROJECT_ROOT/bin/sshpass" || true
            chmod +x "$PROJECT_ROOT/bin/sshpass" || true
        fi

        if [[ ! -x "$PROJECT_ROOT/bin/sshpass" ]]; then
            echo "[*] Package-manager install did not provide sshpass. Trying direct binary download..."
            download_sshpass_binary || true
        fi

        if [[ -x "$PROJECT_ROOT/bin/sshpass" ]]; then
            return
        fi
    elif [[ "$binary" == "dsc64patcher" || "$binary" == "irecovery" || "$binary" == "gaster" ]]; then
        echo "[*] $binary missing. Trying automatic binary download..."
        download_core_ramdisk_binary "$binary" || true
        if [[ -x "$PROJECT_ROOT/bin/$binary" ]]; then
            return
        fi
    fi

    echo "[!] Missing required binary: ./bin/$binary"
    echo "[!] Automatic install failed. Please install it and rerun --fix-ios8."
    exit 1
}

ensure_iproxy_available() {
    if [[ -x "$PROJECT_ROOT/bin/iproxy" ]]; then
        return
    fi

    if command -v iproxy >/dev/null 2>&1; then
        cp "$(command -v iproxy)" "$PROJECT_ROOT/bin/iproxy" || true
        chmod +x "$PROJECT_ROOT/bin/iproxy" || true
        [[ -x "$PROJECT_ROOT/bin/iproxy" ]] && return
    fi

    echo "[*] iproxy not found. Trying to install ramdisk dependency..."
    if [[ "$(uname -s)" == "Darwin" ]]; then
        if command -v brew >/dev/null 2>&1; then
            brew install usbmuxd libimobiledevice || true
        fi
    elif [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        if [[ "${ID:-}" == "arch" || "${ID_LIKE:-}" == *"arch"* ]]; then
            sudo pacman -S --needed libusbmuxd libimobiledevice usbmuxd || true
        else
            sudo apt update || true
            sudo apt install -y libusbmuxd-tools libimobiledevice-utils usbmuxd || true
        fi
    fi

    if command -v iproxy >/dev/null 2>&1; then
        cp "$(command -v iproxy)" "$PROJECT_ROOT/bin/iproxy" || true
        chmod +x "$PROJECT_ROOT/bin/iproxy" || true
    fi

    if [[ ! -x "$PROJECT_ROOT/bin/iproxy" ]]; then
        echo "[!] iproxy is still missing. Install libimobiledevice/usbmuxd and rerun."
        exit 1
    fi
}

ensure_ramdisk_dyld_dependencies() {
    local required_bins=("sshpass" "dsc64patcher" "irecovery" "gaster")
    local binary
    for binary in "${required_bins[@]}"; do
        ensure_required_ramdisk_binary "$binary"
    done
    ensure_iproxy_available
}

ensure_sshramdisk_payload() {
    if [[ -f "$PROJECT_ROOT/sshramdisk/iBSS.img4" && \
          -f "$PROJECT_ROOT/sshramdisk/iBEC.img4" && \
          -f "$PROJECT_ROOT/sshramdisk/ramdisk.img4" && \
          -f "$PROJECT_ROOT/sshramdisk/devicetree.img4" && \
          -f "$PROJECT_ROOT/sshramdisk/kernelcache.img4" ]]; then
        return
    fi

    local sshrd_dir
    sshrd_dir="$(install_sshrd_script_if_missing)"
    if [[ ! -x "$sshrd_dir/sshrd.sh" ]]; then
        chmod +x "$sshrd_dir/sshrd.sh"
    fi

    echo "[*] Generating SSH ramdisk payload using $sshrd_dir ..."
    (
        cd "$sshrd_dir"
        ./sshrd.sh 12.0
    )

    rm -rf "$PROJECT_ROOT/sshramdisk"
    mkdir -p "$PROJECT_ROOT/sshramdisk"
    cp -R "$sshrd_dir/sshramdisk/." "$PROJECT_ROOT/sshramdisk/"
}

run_ramdisk_boot_chain() {
    local cpid major
    cpid="$("$PROJECT_ROOT/bin/irecovery" -q | awk -F': ' '/^CPID:/{print $2}')"
    major="$(awk -F. '{print $1}' "$PROJECT_ROOT/sshramdisk/version.txt" 2>/dev/null || echo 12)"
    major="${major:-12}"

    "$PROJECT_ROOT/bin/irecovery" -f "$PROJECT_ROOT/sshramdisk/iBSS.img4"
    sleep 5
    "$PROJECT_ROOT/bin/irecovery" -f "$PROJECT_ROOT/sshramdisk/iBEC.img4"
    if [[ "$cpid" == "0x8010" || "$cpid" == "0x8015" || "$cpid" == "0x8011" || "$cpid" == "0x8012" ]]; then
        "$PROJECT_ROOT/bin/irecovery" -c go || true
    fi
    sleep 2
    if [[ -f "$PROJECT_ROOT/sshramdisk/logo.img4" ]]; then
        "$PROJECT_ROOT/bin/irecovery" -f "$PROJECT_ROOT/sshramdisk/logo.img4"
        "$PROJECT_ROOT/bin/irecovery" -c "setpicture 0x1" || true
    fi
    "$PROJECT_ROOT/bin/irecovery" -f "$PROJECT_ROOT/sshramdisk/ramdisk.img4"
    "$PROJECT_ROOT/bin/irecovery" -c ramdisk
    if [[ "$major" -ge 16 && -f "$PROJECT_ROOT/sshramdisk/sep-firmware.img4" ]]; then
        "$PROJECT_ROOT/bin/irecovery" -f "$PROJECT_ROOT/sshramdisk/sep-firmware.img4"
        "$PROJECT_ROOT/bin/irecovery" -c firmware
    fi
    "$PROJECT_ROOT/bin/irecovery" -f "$PROJECT_ROOT/sshramdisk/devicetree.img4"
    "$PROJECT_ROOT/bin/irecovery" -c devicetree
    if [[ "$major" -ge 12 && -f "$PROJECT_ROOT/sshramdisk/trustcache.img4" ]]; then
        "$PROJECT_ROOT/bin/irecovery" -f "$PROJECT_ROOT/sshramdisk/trustcache.img4"
        "$PROJECT_ROOT/bin/irecovery" -c firmware
    fi
    "$PROJECT_ROOT/bin/irecovery" -f "$PROJECT_ROOT/sshramdisk/kernelcache.img4"
    "$PROJECT_ROOT/bin/irecovery" -c bootx
}

start_iproxy_tunnel_2222() {
    pkill -f "iproxy 2222 22" >/dev/null 2>&1 || true
    "$PROJECT_ROOT/bin/iproxy" 2222 22 >/dev/null 2>&1 &
    sleep 1
}

wait_for_ssh_ramdisk_2222() {
    local tries=50
    local i
    for ((i=1; i<=tries; i++)); do
        if "$PROJECT_ROOT/bin/sshpass" -p "alpine" ssh root@127.0.0.1 -p2222 \
            -o ConnectTimeout=2 -o StrictHostKeyChecking=no "echo ready" >/dev/null 2>&1; then
            return
        fi
        sleep 3
    done

    echo "[!] SSH ramdisk did not become reachable on 127.0.0.1:2222."
    exit 1
}

ensure_ssh_ramdisk_ready() {
    if "$PROJECT_ROOT/bin/sshpass" -p "alpine" ssh root@127.0.0.1 -p2222 \
        -o ConnectTimeout=2 -o StrictHostKeyChecking=no "echo ready" >/dev/null 2>&1; then
        echo "[*] SSH ramdisk already running on 127.0.0.1:2222."
        return
    fi

    ensure_ramdisk_dyld_dependencies
    ensure_sshramdisk_payload

    if ! enter_pwndfu_mode 1; then
        echo "[!] Device is NOT in PWNDFU mode. Aborting."
        exit 1
    fi

    run_ramdisk_boot_chain
    start_iproxy_tunnel_2222
    wait_for_ssh_ramdisk_2222
}
