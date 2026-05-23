#!/usr/bin/env bash

require_shsh_blob() {
    local shsh_dir="${1:-shsh}"
    local shsh_path

    shsh_path=$(find "$shsh_dir" -type f -name "*.shsh2" | head -n 1)
    if [[ -z "$shsh_path" ]]; then
        echo "[!] No .shsh2 blob found in $shsh_dir folder. Aborting."
        exit 1
    fi

    printf '%s\n' "$shsh_path"
}

enter_pwndfu_mode() {
    local allow_ignore_note="${1:-0}"

    echo "first, your device needs to be in pwndfu mode. pwning with gaster"
    echo "[!] Linux has low success rate for the checkm8 exploit on A6-A7. If possible, you should connect your device to a Mac or iOS device and pwn with ipwnder"
    if [[ "$allow_ignore_note" == "1" ]]; then
        echo "You can ignore this message if you are restoring an A8(X) device or newer."
    fi
    read -p "[!] Do you want to continue pwning with gaster? (LOW SUCCESS RATE) y/n " response
    if [[ "$response" == "y" ]]; then
        ./bin/gaster pwn
    else
        echo "Now, disconnect your device and connect it to a Mac or iOS device to pwn with ipwnder."
        echo "For more information about pwning with an iOS device, go to <https://github.com/LukeZGD/Legacy-iOS-Kit/wiki/Pwning-Using-Another-iOS-Device>"
        read -p "Press any key after the device is pwned with ipwnder and reconnected to this computer"
    fi

    ./bin/gaster reset
    echo "[*] Verifying PWNDFU mode..."
    local irecovery_output
    irecovery_output=$(./bin/irecovery -q)
    if echo "$irecovery_output" | grep -q "PWND"; then
        echo "[*] Device is in PWNDFU mode"
    else
        echo "[!] Device is NOT in PWNDFU mode"
        return 1
    fi
}

read_key_value() {
    local key_file="$1"
    local key_name="$2"
    grep "${key_name}:" "$key_file" | cut -d':' -f2 | xargs
}
