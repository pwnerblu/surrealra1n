#!/usr/bin/env bash

apply_device_profiles() {
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
        ALLFLASH="all_flash.j81ap.production"
        IBSS10="iBSS.j81.RELEASE.im4p"
        IBEC10="iBEC.j81.RELEASE.im4p"
        IBSS7="iBSS.j81ap.RELEASE.im4p"
        IBEC7="iBEC.j81ap.RELEASE.im4p"
        KERNELCACHE10="kernelcache.release.j81"
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
        ALLFLASH="all_flash.n61ap.production"
        IBSS10="iBSS.n61.RELEASE.im4p"
        IBEC10="iBEC.n61.RELEASE.im4p"
        # ik this device did not get ios 7
        IBSS7="iBSS.n61ap.RELEASE.im4p"
        IBEC7="iBEC.n61ap.RELEASE.im4p"
        KERNELCACHE10="kernelcache.release.n61"
    fi

    # iBSS and iBEC specification for iPhone 6 Plus, and DeviceTree. finish A8 support

    if [[ $IDENTIFIER == iPhone7,1 ]]; then
        IBSS="iBSS.n56.RELEASE.im4p"
        IBEC="iBEC.n56.RELEASE.im4p"
        DEVICETREE="DeviceTree.n56ap.im4p"
        ALLFLASH="all_flash.n56ap.production"
        IBSS10="iBSS.n56.RELEASE.im4p"
        IBEC10="iBEC.n56.RELEASE.im4p"
        # ik this device did not get ios 7
        IBSS7="iBSS.n56ap.RELEASE.im4p"
        IBEC7="iBEC.n56ap.RELEASE.im4p"
        KERNELCACHE10="kernelcache.release.n56"
    fi

    # important, for iPad air 2 and mini 4 tethered restores
    if [[ $IDENTIFIER == iPad5,2 || $IDENTIFIER == iPad5,4 ]]; then
        USE_BASEBAND="--latest-baseband"
    fi 

    if [[ $IDENTIFIER == iPad5,1 || $IDENTIFIER == iPad5,3 ]]; then
        USE_BASEBAND="--no-baseband"
    fi 

    # ipad mini 2 support

    if [[ $IDENTIFIER == iPad4,4 || $IDENTIFIER == iPad4,5 ]]; then
        DOWNGRADE_RANGE="10.3 to 12.5.7"
        NOSEP_DOWNGRADE="7.0.3 to 9.3.5 (seprmvr64 downgrades to these versions not added yet)"
        IBSS="iBSS.ipad4b.RELEASE.im4p"
        IBEC="iBEC.ipad4b.RELEASE.im4p"
        if [[ $IDENTIFIER == iPad4,4 ]]; then
            DEVICETREE="DeviceTree.j85ap.im4p"
            USE_BASEBAND="--no-baseband"
        else
            DEVICETREE="DeviceTree.j86ap.im4p"
            USE_BASEBAND="--latest-baseband"
        fi
        KERNELCACHE="kernelcache.release.ipad4b"
        LLB="LLB.ipad4b.RELEASE.im4p"
        IBOOT="iBoot.ipad4b.RELEASE.im4p"
    fi

    if [[ $IDENTIFIER == iPad4,6 ]]; then
        DOWNGRADE_RANGE="11.3 to 12.5.7"
        NOSEP_DOWNGRADE="7.1 to 9.3.5 (seprmvr64 downgrades to these versions not added yet)"
        USE_BASEBAND="--latest-baseband"
        DEVICETREE="DeviceTree.j87ap.im4p"
        IBSS="iBSS.ipad4b.RELEASE.im4p"
        IBEC="iBEC.ipad4b.RELEASE.im4p"
        KERNELCACHE="kernelcache.release.ipad4b"
    fi

    if [[ $IDENTIFIER == iPad4,4 ]]; then
        SEP="sep-firmware.j85.RELEASE.im4p"
        IBSS10="iBSS.j85.RELEASE.im4p"
        IBEC10="iBEC.j85.RELEASE.im4p"
        IBSS7="iBSS.j85ap.RELEASE.im4p"
        IBEC7="iBEC.j85ap.RELEASE.im4p"
        IBOOT10="iBoot.j85.RELEASE.im4p"
        LLB10="LLB.j85.RELEASE.im4p"
        ALLFLASH="all_flash.j85ap.production"
        KERNELCACHE10="kernelcache.release.j85"
        sudo rm -rf "tmpmanifest"
        mkdir -p tmpmanifest
        cd tmpmanifest
        curl -L -o Manifest.plist https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/resources/manifest/BuildManifest_iPad4,4_10.3.3.plist
        cd ..
    fi

    if [[ $IDENTIFIER == iPad4,5 ]]; then
        SEP="sep-firmware.j86.RELEASE.im4p"
        IBSS10="iBSS.j86.RELEASE.im4p"
        IBEC10="iBEC.j86.RELEASE.im4p"
        IBSS7="iBSS.j86ap.RELEASE.im4p"
        IBEC7="iBEC.j86ap.RELEASE.im4p"
        IBOOT10="iBoot.j86.RELEASE.im4p"
        LLB10="LLB.j86.RELEASE.im4p"
        ALLFLASH="all_flash.j86ap.production"
        KERNELCACHE10="kernelcache.release.j86"
        sudo rm -rf "tmpmanifest"
        mkdir -p tmpmanifest
        cd tmpmanifest
        curl -L -o Manifest.plist https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/resources/manifest/BuildManifest_iPad4,5_10.3.3.plist
        cd ..
    fi

    if [[ $IDENTIFIER == iPad4,6 ]]; then
        IBSS10="iBSS.j87.RELEASE.im4p"
        IBEC10="iBEC.j87.RELEASE.im4p"
        IBSS7="iBSS.j87ap.RELEASE.im4p"
        IBEC7="iBEC.j87ap.RELEASE.im4p"
        IBOOT10="iBoot.j87.RELEASE.im4p"
        LLB10="LLB.j87.RELEASE.im4p"
        ALLFLASH="all_flash.j87ap.production"
        KERNELCACHE10="kernelcache.release.j87"
    fi

    # other stuff

    if [[ $IDENTIFIER == iPhone7,2 ]]; then
        LLB="LLB.n61.RELEASE.im4p"
        IBOOT="iBoot.n61.RELEASE.im4p"
    elif [[ $IDENTIFIER == iPhone7,1 ]]; then
        LLB="LLB.n56.RELEASE.im4p"
        IBOOT="iBoot.n56.RELEASE.im4p"
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
        LATEST_VERSION="16.7.16"
        DOWNGRADE_RANGE="14.3 to 15.6.1"
        KERNELCACHE="kernelcache.release.iphone10"
    elif [[ $IDENTIFIER == iPhone10,3 || $IDENTIFIER == iPhone10,6 ]]; then
        LATEST_VERSION="16.7.16"
        DOWNGRADE_RANGE="14.3 to 15.6.1"
        KERNELCACHE="kernelcache.release.iphone10b"
    elif [[ $IDENTIFIER == iPod7,1 ]]; then
        # ipod touch 6 support, huge thanks to bodyc1m
        LATEST_VERSION="12.5.8"
        DOWNGRADE_RANGE="10.3 to 12.5.7"
        NOSEP_DOWNGRADE="8.4 to 9.3.5"
        KERNELCACHE="kernelcache.release.n102"
        KERNELCACHE10="kernelcache.release.n102"
        LLB="LLB.n102.RELEASE.im4p"
        IBOOT="iBoot.n102.RELEASE.im4p"
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
    elif [[ $IDENTIFIER == iPad5,1 || $IDENTIFIER == iPad5,2 ]]; then
        LATEST_VERSION="15.8.8"
        DOWNGRADE_RANGE="11.3 to 15.8.5"
        NOSEP_DOWNGRADE="9.0 to 9.3.5"
        IBSS="iBSS.ipad5.RELEASE.im4p"
        IBEC="iBEC.ipad5.RELEASE.im4p"
        KERNELCACHE="kernelcache.release.ipad5"
        LLB="LLB.ipad5.RELEASE.im4p"
        IBOOT="iBoot.ipad5.RELEASE.im4p"
    elif [[ $IDENTIFIER == iPad5,3 || $IDENTIFIER == iPad5,4 ]]; then
        LATEST_VERSION="15.8.8"
        DOWNGRADE_RANGE="11.3 to 15.8.5"
        NOSEP_DOWNGRADE="8.1 to 9.3.5"
        IBSS="iBSS.ipad5b.RELEASE.im4p"
        IBEC="iBEC.ipad5b.RELEASE.im4p"
        KERNELCACHE="kernelcache.release.ipad5b"
    elif [[ $IDENTIFIER == iPad4,4 || $IDENTIFIER == iPad4,5 || $IDENTIFIER == iPad4,6 ]]; then
        LATEST_VERSION="12.5.8"
    else
        echo "Unsupported device, press enter to continue if you are going to do an untethered downgrade with saved SHSH (use --downgrade [IPSW FILE] [SHSH BLOB])"
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
        IBSS7="iBSS.n53ap.RELEASE.im4p"
        IBEC7="iBEC.n53ap.RELEASE.im4p"
        DEVICETREE="DeviceTree.n53ap.im4p"
        sudo rm -rf "tmpmanifest"
        mkdir -p tmpmanifest
        cd tmpmanifest
        curl -L -o Manifest.plist https://github.com/LukeZGD/Legacy-iOS-Kit/raw/refs/heads/main/resources/manifest/BuildManifest_iPhone6,2_10.3.3.plist
        cd ..
    fi

    mnifst="tmpmanifest/Manifest.plist"
}
