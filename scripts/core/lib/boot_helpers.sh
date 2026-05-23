#!/usr/bin/env bash

normal_boot() {
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
}
