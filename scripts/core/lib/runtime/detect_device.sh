#!/usr/bin/env bash

detect_connected_device() {
    # Keep these defined for set -u even in DFU/recovery paths.
    IDENTIFIER="${IDENTIFIER:-}"
    ECID="${ECID:-}"
    SERIAL="${SERIAL:-}"
    DEVICE_VERSION="${DEVICE_VERSION:-}"

    # Run ideviceinfo and capture both output and return code
    IDEVICE_INFO=$(ideviceinfo 2>&1) || true
    IDEVICE_STATUS=$?

    if [[ $IDEVICE_STATUS -eq 0 && "$IDEVICE_INFO" != *"No device found!"* ]]; then
        echo "[*] Device is in normal mode."

        # Extract ProductType and UniqueChipID
        IDENTIFIER=$(echo "$IDEVICE_INFO" | grep "^ProductType:" | cut -d ':' -f2 | xargs)
        ECID=$(echo "$IDEVICE_INFO" | grep "^UniqueChipID:" | cut -d ':' -f2 | xargs)
        SERIAL=$(echo "$IDEVICE_INFO" | grep "^SerialNumber:" | cut -d ':' -f2 | xargs)
        DEVICE_VERSION=$(echo "$IDEVICE_INFO" | grep "^ProductVersion:" | cut -d ':' -f2 | xargs)

        echo "[+] Device Identifier: $IDENTIFIER"
        echo "[+] ECID: $ECID"

    else
        echo "[*] Device is not in normal mode. Trying recovery/DFU mode..."

        # Try irecovery
        IRECOVERY_INFO=$(./bin/irecovery -q 2>/dev/null) || true

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

}
