#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

. "$PROJECT_ROOT/scripts/core/lib/bootstrap.sh"
. "$PROJECT_ROOT/scripts/core/lib/usage.sh"
. "$PROJECT_ROOT/scripts/core/lib/runtime_context.sh"
. "$PROJECT_ROOT/scripts/core/lib/command_helpers.sh"
. "$PROJECT_ROOT/scripts/core/lib/flows.sh"

cmd_seprmvr64_ipsw() {
    normalize_command_args "--seprmvr64-ipsw" "$@"
    local args=("${NORMALIZED_ARGS[@]}")

    if (( ${#args[@]} < 3 || ${#args[@]} > 5 )); then
        echo "[!] Usage: --seprmvr64-ipsw [TARGET_IPSW_PATH] [BASE_IPSW_PATH] [iOS_VERSION] [--stitch-activation] [--jailbreak]"
        exit 1
    fi

    TARGET_IPSW="${args[0]}"
    BASE_IPSW="${args[1]}"
    IOS_VERSION="${args[2]}"

    FORCE_ACTIVATE="0"
    if has_flag "--stitch-activation" "${args[@]:3}"; then
        case "$IOS_VERSION" in
            7.*|8.*|9.0*|9.1*|9.2*)
                FORCE_ACTIVATE=1
                ;;
            9.3*)
                FORCE_ACTIVATE=0
                ;;
            *)
                echo "[!] Unsupported iOS version for stitch-activation: $IOS_VERSION"
                exit 1
                ;;
        esac
    fi
    if [[ $IDENTIFIER == iPhone6,2 ]] && [[ $IOS_VERSION != 7.* ]]; then
        echo "iPhone6,2 does not support 8.0-9.3.5 seprmvr64 restores yet in surrealra1n."
        exit 1
    elif [[ $IDENTIFIER == iPhone7,2 || $IDENTIFIER == iPhone7,1 ]] && [[ $IOS_VERSION != 8.4.1 ]]; then
        echo "iPhone 6 (and 6 Plus) does not support any other than 8.4.1 seprmvr64 restores via surrealra1n"
        exit 1
    elif [[ $IDENTIFIER == iPad5,3 ]] && [[ $IOS_VERSION != 8.* ]]; then
        echo "This version is not supported yet in seprmvr64-ipsw"
        exit 1
    elif [[ $IDENTIFIER == iPad5,1 || $IDENTIFIER == iPad5,2 || $IDENTIFIER == iPad5,4 || $IDENTIFIER == iPad4* ]]; then
        echo "Device is not supported yet for seprmvr64-ipsw"
        exit 1
    fi
    # A8(X) iOS 8.0-9.x activation error candidates
    if [[ $IDENTIFIER == iPad5* || $IDENTIFIER == iPod7* || $IDENTIFIER == iPhone7* ]] && [[ $IOS_VERSION == 9.3* ]]; then
        echo "[!] 9.3.x restores are blocked on A8(X) devices for the following reason."
        echo "Recently, Apple blocked activation for A8(X) iOS 8 and 9. This means that you will not be able to activate normally, getting \"Activation Error\"."
        if [[ $IDENTIFIER == iPhone7* ]]; then
            echo "Since the restore will not have baseband, activation will not work, so it is strongly recommended to stitch activation records"
        fi
        echo "Note: stitching activation records is only for 9.2.1 and lower, and you are trying to restore to 9.3.x. Please do iOS 9.2.1 and lower."
        exit 1
    elif [[ $IDENTIFIER == iPad5* || $IDENTIFIER == iPod7* || $IDENTIFIER == iPhone7* ]] && [[ $IOS_VERSION != 9.3* ]]; then
        # set FORCE_ACTIVATE=1 automatically because these are affected A8/A8X candidates, override --stitch-activation flag here
        FORCE_ACTIVATE=1
        echo "[!] Activation records are REQUIRED for this restore."
        echo "[!] This is due to Apple blocking activation recently for A8(X) iOS 8 and 9."
        echo "[!] Make sure you are on the latest iOS (must be a functional device), and fully activated via Apple's servers. Make sure to jailbreak and install OpenSSH as well."
        read -p "Press enter to continue"
    fi
    if [[ $FORCE_ACTIVATE == 1 ]] && [[ $IDENTIFIER == iPad5* || $IDENTIFIER == iPod7* || $IDENTIFIER == iPhone7* ]] && [[ $IOS_VERSION == 8.2* || $IOS_VERSION == 8.1* || $IOS_VERSION == 8.0* ]]; then
        echo "Stitching activation may work on this version, but there is a much higher chance of the device deactivating especially right after the first boot."
        echo "It is recommended to do iOS 8.3 or later instead."
        read -p "Press enter to continue"
    fi
    if has_flag "--jailbreak" "${args[@]:3}"; then
        JAILBREAK=1
    fi
    if [[ $JAILBREAK != 1 ]]; then
        echo "Jailbreak option disabled."
        echo "Cydia will not be installed with this restore."
        read -p "Press enter to continue"
    fi
    if [[ $JAILBREAK == 1 ]] && [[ $IOS_VERSION != 7.* ]]; then
        echo "Jailbreak option not supported for iOS 8.0-9.3.5 yet, only 7.0-7.1.2."
        JAILBREAK=0
        read -p "Press enter to continue"
    fi
    if [[ $JAILBREAK == 1 ]]; then
        mkdir -p jbresources
        curl -L -o jbresources/pangu-untether.tar https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/resources/jailbreak/panguaxe.tar
        curl -L -o jbresources/evasi0n7-untether.tar https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/resources/jailbreak/evasi0n7-untether.tar
        curl -L -o jbresources/evasi0n7-untether-70.tar https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/resources/jailbreak/evasi0n7-untether-70.tar
        curl -L -o jbresources/freeze.tar.gz https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/resources/jailbreak/freeze.tar.gz
        gzip -dc jbresources/freeze.tar.gz > jbresources/freeze.tar
    fi
    if [[ "$FORCE_ACTIVATE" == "0" ]]; then
        echo "[*] iOS version is not supported for stitch-activation. Skipping pre-activation of IPSW."
    elif [[ "$FORCE_ACTIVATE" == "1" ]]; then
        echo "[!] Before you can proceed, make sure your device is legitimately activated via Apple's servers on the Latest iOS (activated, not iCloud/MDM bypassed)."
        # normalize ECID (hex -> decimal if needed)
        if [[ "$ECID" == 0x* || "$ECID" == 0X* ]]; then
            ECID_CLEAN="${ECID#0x}"
            ECID_CLEAN="${ECID_CLEAN#0X}"
            ECID_DEC=$(printf '%d' "0x$ECID_CLEAN")
        else
            ECID_CLEAN="$ECID"
            ECID_DEC="$ECID"
        fi
        CACHE_FILE="cache/$ECID_DEC"

        # check cached serial
        if [[ -f "$CACHE_FILE" ]]; then
            CACHED_SERIAL=$(cat "$CACHE_FILE")
        else
            CACHED_SERIAL=""
        fi

        # save serial to cache if empty
        if [[ -z "$CACHED_SERIAL" ]]; then
            if [[ -n "${SERIAL:-}" ]]; then
                mkdir -p cache
                echo "$SERIAL" > "$CACHE_FILE"
                CACHED_SERIAL="$SERIAL"
            else
                CACHED_SERIAL="$(ls -1 activation_records 2>/dev/null | head -n 1 || true)"
            fi
        fi

        if [[ -z "$CACHED_SERIAL" ]]; then
            echo "[!] Could not determine SerialNumber for activation cache."
            echo "[!] Connect device once in normal mode (activated) and rerun, or place activation files in activation_records/<SERIAL>/ manually."
            exit 1
        fi
    fi
    if [[ $FORCE_ACTIVATE == 1 ]] && [[ ! -f "activation_records/$CACHED_SERIAL/activation_record.plist" ]] && [[ ! -f "activation_records/$CACHED_SERIAL/IC-Info.sisv" ]] && [[ ! -f "activation_records/$CACHED_SERIAL/com.apple.commcenter.device_specific_nobackup.plist" ]]; then
        echo "[!] Make sure your device is in a jailbroken state, and OpenSSH is installed."
        echo "[!] Please DO NOT USE THIS IN THE INTENT OF BYPASSING ICLOUD, THANK YOU." 
        mkdir -p activation_records
        mkdir -p activation_records/$CACHED_SERIAL/
        read -p "Press enter when it is ready. The SSH password you must input during this is "alpine" or your device's SSH password"
        # determine what it connects by, on iOS 15.0 and later, connect as mobile, otherwise connect as root
        if [[ $DEVICE_VERSION == 15.* ]]; then
            CONNECT_AS="mobile"
        else
            CONNECT_AS="root"
        fi
        echo "SSH will connect as $CONNECT_AS"
        echo "Make sure your computer and device is connected to the same Wi-Fi network."
        read -p "Insert the IP of your device, go to Settings/Wi-Fi/Wi-Fi network/Information/IP Address: " ip_address
        read -p "Enter the SSH Password of your device: " sshpwd
        sudo ./bin/sshpass -p "$sshpwd" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $CONNECT_AS@"$ip_address":/private/var/containers/Data/System/*/Library/activation_records/activation_record.plist activation_records/$CACHED_SERIAL/activation_record.plist
        if [[ ! -f "activation_records/$CACHED_SERIAL/activation_record.plist" ]]; then
            echo "activation_record.plist did not save correctly. Cannot continue --stitch-activation with this."
            exit 1
        fi
        sudo ./bin/sshpass -p "$sshpwd" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $CONNECT_AS@"$ip_address":/private/var/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv activation_records/$CACHED_SERIAL/IC-Info.sisv
        if [[ ! -f "activation_records/$CACHED_SERIAL/IC-Info.sisv" ]]; then
            echo "IC-Info.sisv did not save correctly. Certain things may be broken."
            read -p "You can press enter to continue, but it is usually not recommended to have an incomplete backup of activation records."
        fi
        if [[ $DEVICE_VERSION == 15.* ]]; then
            # re-set permissions for com.apple.commcenter.device_specific_nobackup.plist and move to different dir, so you can download it when connected via mobile
            sudo ./bin/sshpass -p "$sshpwd" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $CONNECT_AS@"$ip_address" "echo "$sshpwd" | sudo -S cp /private/var/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist /private/var/containers/Data/System/"
            sudo ./bin/sshpass -p "$sshpwd" ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $CONNECT_AS@"$ip_address" "echo "$sshpwd" | sudo -S chown mobile:mobile /private/var/containers/Data/System/com.apple.commcenter.device_specific_nobackup.plist"
            sudo ./bin/sshpass -p "$sshpwd" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $CONNECT_AS@"$ip_address":/private/var/containers/Data/System/com.apple.commcenter.device_specific_nobackup.plist activation_records/$CACHED_SERIAL/com.apple.commcenter.device_specific_nobackup.plist
        else
            sudo ./bin/sshpass -p "$sshpwd" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $CONNECT_AS@"$ip_address":/private/var/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist activation_records/$CACHED_SERIAL/com.apple.commcenter.device_specific_nobackup.plist
        fi
        if [[ ! -f "activation_records/$CACHED_SERIAL/com.apple.commcenter.device_specific_nobackup.plist" ]]; then 
            echo "com.apple.commcenter.device_specific_nobackup.plist did not save correctly."
            read -p "You can press enter to continue, but you will not have cellular signal after activation records are stitched (that is if of course, baseband update doesn't have to be skipped)."
        fi
    fi        
    echo "[!] IMPORTANT: This feature is only supported on iOS 7.0 - 9.3.5. DO NOT TRY THIS on 10.0 or later"
    echo "[!] Warning: Before you proceed with a seprmvr64 restore, please understand the following issues you will have afterwards:"
    echo "[!] 1. Touch ID will NOT work, at all."
    echo "[!] 2. Passcode will NOT work, at all. Your passcode is technically NULL."
    echo "[!] 3. Encrypted Wi-Fi networks will not work. Use an open network instead."
    echo "[!] 4. You will have deep sleep issues, and POTENTIALLY other issues."
    read -p "Press enter to continue. Or press CTRL + C to cancel."
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
    IBSS_KEY=$(read_key_value "$KEY_FILE" "ibss-$IOS_VERSION")
    IBEC_KEY=$(read_key_value "$KEY_FILE" "ibec-$IOS_VERSION")
    DTRE_KEY=$(read_key_value "$KEY_FILE" "dtre-$IOS_VERSION")
    RDSK_KEY=$(read_key_value "$KEY_FILE" "rdsk-$IOS_VERSION")
    KRNL_KEY=$(read_key_value "$KEY_FILE" "krnl-$IOS_VERSION")
    ROOT_KEY=$(read_key_value "$KEY_FILE" "fstm-$IOS_VERSION")

    if [[ -z "$IBSS_KEY" || -z "$IBEC_KEY" ]]; then
        echo "[!] Missing iBSS or iBEC key for iOS $IOS_VERSION in $KEY_FILE. Aborting."
        exit 1
    fi

    echo "[*] Found keys:"
    echo "    iBSS Key: $IBSS_KEY"
    echo "    iBEC Key: $IBEC_KEY"
    if [[ $IOS_VERSION == 7.1* || $IOS_VERSION == 8.* || $IOS_VERSION == 9.* ]]; then
        smallest_dmg=$(find_dmg tmp1 smallest)
    else
        smallest_dmg=$(find_dmg tmp1 largest 10370000)
    fi
    smallest12_dmg=$(find_dmg tmp2 smallest)
    rootfs_dmg=$(find_dmg tmp1 largest)
    rootfs12_dmg=$(find_dmg tmp2 largest)
    mkdir -p work
    rm -rf "$rootfs12_dmg"
    ./bin/img4 -i "$smallest_dmg" -o "$smallest12_dmg" -k $RDSK_KEY -D
    if [[ $IOS_VERSION == 8.* ]] && [[ $IDENTIFIER == iPod7* || $IDENTIFIER == iPhone7* || $IDENTIFIER == iPad5* || $FORCE_ACTIVATE == 1 ]]; then
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
        if [[ $IDENTIFIER == iPod7* || $IDENTIFIER == iPhone7* || $IDENTIFIER == iPad5* ]]; then
            ./bin/hfsplus "work/ramdisk.raw" extract usr/local/bin/restored_external
            ./bin/restoredpatcher restored_external restored_patch -b
            ./bin/ldid -e restored_external > ents.plist
            ./bin/ldid -Sents.plist restored_patch
            ./bin/hfsplus "work/ramdisk.raw" rm usr/local/bin/restored_external
            ./bin/hfsplus "work/ramdisk.raw" add restored_patch usr/local/bin/restored_external
            ./bin/hfsplus "work/ramdisk.raw" chmod 100755 usr/local/bin/restored_external
            if [[ $IDENTIFIER == iPad5,3 ]]; then
                # options plist change
                curl -L -o options.n61.plist https://github.com/pwnerblu/surrealra1n/raw/refs/heads/development/dualboot/options.n61.plist
                ./bin/hfsplus "work/ramdisk.raw" rm usr/local/share/restore/options.j81.plist
                ./bin/hfsplus "work/ramdisk.raw" add options.n61.plist usr/local/share/restore/options.j81.plist
                rm -rf options.n61.plist
            fi
            if [[ $IDENTIFIER == iPhone7,2 ]]; then
                # options plist change
                curl -L -o options.n61.plist https://github.com/pwnerblu/surrealra1n/raw/refs/heads/development/dualboot/options.n61.plist
                ./bin/hfsplus "work/ramdisk.raw" rm usr/local/share/restore/options.n61.plist
                ./bin/hfsplus "work/ramdisk.raw" add options.n61.plist usr/local/share/restore/options.n61.plist
            elif [[ $IDENTIFIER == iPhone7,1 ]]; then
                # options plist change
                curl -L -o options.n56.plist https://github.com/pwnerblu/surrealra1n/raw/refs/heads/development/dualboot/options.n56.plist
                ./bin/hfsplus "work/ramdisk.raw" rm usr/local/share/restore/options.n56.plist
                ./bin/hfsplus "work/ramdisk.raw" add options.n56.plist usr/local/share/restore/options.n56.plist
            fi
        fi
        ./bin/img4 -i "work/ramdisk.raw" -o "$smallest12_dmg" -A -T rdsk
        ./bin/dmg extract "$rootfs_dmg" "tmp1/rootfs.raw" -k $ROOT_KEY
        ./bin/hfsplus "tmp1/rootfs.raw" grow 3500000000
        if [[ $FORCE_ACTIVATE == 1 ]]; then
            echo "Preparing activation files..."
            sudo cp activation_records/$CACHED_SERIAL/activation_record.plist activation.plist
            sudo cp activation_records/$CACHED_SERIAL/IC-Info.sisv IC-Info.sisv
            sudo cp activation_records/$CACHED_SERIAL/com.apple.commcenter.device_specific_nobackup.plist com.apple.commcenter.device_specific_nobackup.plist
            echo "Making dirs..."
            ./bin/hfsplus "tmp1/rootfs.raw" mkdir private/var/root/Library/Lockdown/activation_records
            ./bin/hfsplus "tmp1/rootfs.raw" mkdir private/var/mobile/Library/mad/activation_records
            ./bin/hfsplus "tmp1/rootfs.raw" mkdir private/var/mobile/Library/FairPlay/iTunes_Control/iTunes
            ./bin/hfsplus "tmp1/rootfs.raw" mkdir private/var/wireless
            ./bin/hfsplus "tmp1/rootfs.raw" mkdir private/var/wireless/Library
            ./bin/hfsplus "tmp1/rootfs.raw" mkdir private/var/wireless/Library/Preferences
            echo "Injecting activation files into rootfs..."
            ./bin/hfsplus "tmp1/rootfs.raw" add activation.plist private/var/root/Library/Lockdown/activation_records/activation_record.plist
            ./bin/hfsplus "tmp1/rootfs.raw" add activation.plist private/var/mobile/Library/mad/activation_records/activation_record.plist
            ./bin/hfsplus "tmp1/rootfs.raw" add IC-Info.sisv private/var/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv
            sudo ./bin/hfsplus "tmp1/rootfs.raw" add com.apple.commcenter.device_specific_nobackup.plist private/var/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist
            echo "Setting permissions..."
            ./bin/hfsplus "tmp1/rootfs.raw" chmod 666 private/var/root/Library/Lockdown/activation_records/activation_record.plist
            ./bin/hfsplus "tmp1/rootfs.raw" chmod 666 private/var/mobile/Library/mad/activation_records/activation_record.plist
            ./bin/hfsplus "tmp1/rootfs.raw" chmod 664 private/var/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv
            ./bin/hfsplus "tmp1/rootfs.raw" chmod 600 private/var/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist
            echo "Cleaning up..."
            sudo rm -rf activation.plist
            sudo rm -rf IC-Info.sisv
        fi
        ./bin/dmg build "tmp1/rootfs.raw" "$rootfs12_dmg"
    elif [[ $IOS_VERSION == 7.* ]] && [[ $FORCE_ACTIVATE == 1 || $JAILBREAK == 1 ]]; then
        # patch asr...
        ./bin/img4 -i "$smallest_dmg" -o "work/ramdisk.raw" -k $RDSK_KEY 
        ./bin/hfsplus "work/ramdisk.raw" grow 30000000
        ./bin/hfsplus "work/ramdisk.raw" extract usr/sbin/asr
        ./bin/asr64_patcher asr asr_patch 
        ./bin/hfsplus "work/ramdisk.raw" rm usr/sbin/asr
        ./bin/hfsplus "work/ramdisk.raw" add asr_patch usr/sbin/asr
        ./bin/hfsplus "work/ramdisk.raw" chmod 100755 usr/sbin/asr
        ./bin/img4 -i "work/ramdisk.raw" -o "$smallest12_dmg" -A -T rdsk
        ./bin/dmg extract "$rootfs_dmg" "tmp1/rootfs.raw" -k $ROOT_KEY
        ./bin/hfsplus "tmp1/rootfs.raw" grow 2500000000
        if [[ $FORCE_ACTIVATE == 1 ]]; then
            echo "Preparing activation files..."
            sudo cp activation_records/$CACHED_SERIAL/activation_record.plist activation.plist
            sudo cp activation_records/$CACHED_SERIAL/IC-Info.sisv IC-Info.sisv
            sudo cp activation_records/$CACHED_SERIAL/com.apple.commcenter.device_specific_nobackup.plist com.apple.commcenter.device_specific_nobackup.plist
            echo "Making dirs..."
            ./bin/hfsplus "tmp1/rootfs.raw" mkdir private/var/root/Library/Lockdown/activation_records
            ./bin/hfsplus "tmp1/rootfs.raw" mkdir private/var/mobile/Library/FairPlay/iTunes_Control/iTunes
            ./bin/hfsplus "tmp1/rootfs.raw" mkdir private/var/wireless
            ./bin/hfsplus "tmp1/rootfs.raw" mkdir private/var/wireless/Library
            ./bin/hfsplus "tmp1/rootfs.raw" mkdir private/var/wireless/Library/Preferences
            echo "Injecting activation files into rootfs..."
            ./bin/hfsplus "tmp1/rootfs.raw" add activation.plist private/var/root/Library/Lockdown/activation_records/activation_record.plist
            ./bin/hfsplus "tmp1/rootfs.raw" add IC-Info.sisv private/var/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv
            sudo ./bin/hfsplus "tmp1/rootfs.raw" add com.apple.commcenter.device_specific_nobackup.plist private/var/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist
            echo "Setting permissions..."
            ./bin/hfsplus "tmp1/rootfs.raw" chmod 666 private/var/root/Library/Lockdown/activation_records/activation_record.plist
            ./bin/hfsplus "tmp1/rootfs.raw" chmod 664 private/var/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv
            ./bin/hfsplus "tmp1/rootfs.raw" chmod 600 private/var/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist
            echo "Cleaning up..."
            sudo rm -rf activation.plist
            sudo rm -rf IC-Info.sisv
            sudo rm -rf com.apple.commcenter.device_specific_nobackup.plist
        fi
        if [[ $JAILBREAK == 1 ]]; then
            echo "Doing jailbreak stuff..."
            if [[ $IOS_VERSION == 7.1* ]]; then
                untether_tar="jbresources/pangu-untether.tar"
            elif [[ $IOS_VERSION == 7.0.1* || $IOS_VERSION == 7.0.2* || $IOS_VERSION == 7.0.3* || $IOS_VERSION == 7.0.4* || $IOS_VERSION == 7.0.5* || $IOS_VERSION == 7.0.6* ]]; then
                untether_tar="jbresources/evasi0n7-untether.tar"
            else
                untether_tar="jbresources/evasi0n7-untether-70.tar"
            fi
            ./bin/hfsplus "tmp1/rootfs.raw" untar jbresources/freeze.tar
            ./bin/hfsplus "tmp1/rootfs.raw" untar $untether_tar
        fi
        ./bin/dmg build "tmp1/rootfs.raw" "$rootfs12_dmg"
    elif [[ $IOS_VERSION == 9.* ]] && [[ $IDENTIFIER == iPod7* || $IDENTIFIER == iPhone7* || $IDENTIFIER == iPad5* || $FORCE_ACTIVATE == 1 ]]; then
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
        if [[ $IDENTIFIER == iPod7* || $IDENTIFIER == iPhone7* || $IDENTIFIER == iPad5* ]]; then
            ./bin/hfsplus "work/ramdisk.raw" extract usr/local/bin/restored_external
            ./bin/restoredpatcher restored_external restored_patch -b
            ./bin/ldid -e restored_external > ents.plist
            ./bin/ldid -Sents.plist restored_patch
            ./bin/hfsplus "work/ramdisk.raw" rm usr/local/bin/restored_external
            ./bin/hfsplus "work/ramdisk.raw" add restored_patch usr/local/bin/restored_external
            ./bin/hfsplus "work/ramdisk.raw" chmod 100755 usr/local/bin/restored_external
            ./bin/img4 -i "work/ramdisk.raw" -o "$smallest12_dmg" -A -T rdsk
        fi
        ./bin/img4 -i "work/ramdisk.raw" -o "$smallest12_dmg" -A -T rdsk
        ./bin/dmg extract "$rootfs_dmg" "tmp1/rootfs.raw" -k $ROOT_KEY
        if [[ $FORCE_ACTIVATE == 1 ]]; then
            echo "Preparing activation files..."
            sudo cp activation_records/$CACHED_SERIAL/activation_record.plist activation.plist
            sudo cp activation_records/$CACHED_SERIAL/IC-Info.sisv IC-Info.sisv
            sudo cp activation_records/$CACHED_SERIAL/com.apple.commcenter.device_specific_nobackup.plist com.apple.commcenter.device_specific_nobackup.plist
            echo "Making dirs..."
            ./bin/hfsplus "tmp1/rootfs.raw" mkdir private/var/root/Library/Lockdown/activation_records
            ./bin/hfsplus "tmp1/rootfs.raw" mkdir private/var/mobile/Library/mad/activation_records
            ./bin/hfsplus "tmp1/rootfs.raw" mkdir private/var/mobile/Library/FairPlay/iTunes_Control/iTunes
            ./bin/hfsplus "tmp1/rootfs.raw" mkdir private/var/wireless
            ./bin/hfsplus "tmp1/rootfs.raw" mkdir private/var/wireless/Library
            ./bin/hfsplus "tmp1/rootfs.raw" mkdir private/var/wireless/Library/Preferences
            echo "Injecting activation files into rootfs..."
            ./bin/hfsplus "tmp1/rootfs.raw" add activation.plist private/var/root/Library/Lockdown/activation_records/activation_record.plist
            ./bin/hfsplus "tmp1/rootfs.raw" add activation.plist private/var/mobile/Library/mad/activation_records/activation_record.plist
            ./bin/hfsplus "tmp1/rootfs.raw" add IC-Info.sisv private/var/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv
            sudo ./bin/hfsplus "tmp1/rootfs.raw" add com.apple.commcenter.device_specific_nobackup.plist private/var/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist
            echo "Setting permissions..."
            ./bin/hfsplus "tmp1/rootfs.raw" chmod 666 private/var/root/Library/Lockdown/activation_records/activation_record.plist
            ./bin/hfsplus "tmp1/rootfs.raw" chmod 666 private/var/mobile/Library/mad/activation_records/activation_record.plist
            ./bin/hfsplus "tmp1/rootfs.raw" chmod 664 private/var/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv
            ./bin/hfsplus "tmp1/rootfs.raw" chmod 600 private/var/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist
            echo "Cleaning up..."
            sudo rm -rf activation.plist
            sudo rm -rf IC-Info.sisv
        fi
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
        ./bin/Kernel64Patcher2 "work/kcache.raw" "work/kcache.patched" -u 9 -f 9 -k -v
    fi     
    ./bin/kerneldiff "work/kcache.raw" "work/kcache.patched" "work/kcache.bpatch"
    # wrap kcache into im4p
    ./bin/img4 -i "work/kcache.im4p" -o "tmp2/$KERNELCACHE" -T rkrn -P "work/kcache.bpatch" -J || true
    echo "Patching complete!"
    rm -rf "work"
    rm -rf "tmp1"
    cd tmp2
    zip -0 -r ../$savedir/custom.ipsw *
    cd ..
    rm -rf "tmp2"
    echo "Custom IPSW is created! You can restore with: ./surrealra1n.sh --seprmvr64-restore $IOS_VERSION"
    rm -rf "jbresources"
    exit 0
}

main() {
    bootstrap_environment
    init_runtime_context
    cmd_seprmvr64_ipsw "$@"
}

main "$@"
