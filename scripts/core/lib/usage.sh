#!/usr/bin/env bash

function usage() {
    local downgrade_display="${DOWNGRADE_RANGE:-device-specific (detected after device check)}"

    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --make-custom-ipsw [TARGET_IPSW_PATH] [BASE_IPSW_PATH] [iOS_VERSION]
        Create a custom IPSW for tethered restore.
        - TARGET_IPSW_PATH: Path for the stock IPSW for target version
        - BASE_IPSW_PATH: Must be latest signed iOS IPSW for your device
        - iOS_VERSION: Target iOS version to restore ($downgrade_display)

  --seprmvr64-ipsw [TARGET_IPSW_PATH] [BASE_IPSW_PATH] [iOS_VERSION] [optional: --jailbreak]
        Create a custom IPSW for tethered restore, with seprmvr64. If you're going to 9.2.1 and lower, you can choose to attempt stitching activation records to pre-activate the seprmvr64 restore.
        - TARGET_IPSW_PATH: Path for the stock IPSW for target version
        - BASE_IPSW_PATH: Must be latest signed iOS IPSW for your device
        - iOS_VERSION: Target iOS version to restore
        - [--stitch-activation]: Attempt to stitch activation records into rootfs to pre-activate a restore (7.0 - 9.2.1 only). Device must be legitimately activated to save activation records, it can't be iCloud/MDM bypassed.

  --restore [iOS_VERSION]
        Restore the device to a previously created custom IPSW.
        - You can also choose to tethered update (no data loss, but may only work if going from a lower version to a newer version (13.6 to 15.4.1 for example)
        - Requires a custom IPSW already built for the specified iOS version.
        - Put your device into DFU mode before proceeding.

  --seprmvr64-restore [iOS_VERSION]
        Restore the device to a previously created custom IPSW for seprmvr64.
        - Requires a custom IPSW already built for the specified iOS version.
        - Put your device into DFU mode before proceeding.

  --seprmvr64-boot [iOS_VERSION] [ipsw file]
        Perform a tethered boot of the specified iOS version with seprmvr64.
        - You must be on that iOS version already.
        - Put your device into DFU mode before proceeding.

  --fix-ios8
        Automatically boot SSH ramdisk and patch iOS 8 dyld cache.
        - Intended right after a fresh iOS 8.x seprmvr64 restore.

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
