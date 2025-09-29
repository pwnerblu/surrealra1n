# surrealra1n development branch

The development branch is not meant to be used for normal use.

Please open an issue if there's problems or bugs.

iOS 10.3.x tethered restores work now, 10.2.x and 10.1.x are in progress, after that is done, I will push the update to the main branch

A script that allows tethered & untethered downgrades of A7-A8 iPhones. A7 iPad support will be added eventually, but A8(X) iPad support will not be added.
So what iOS versions can you downgrade to with surrealra1n? Any version with SEP compatibility, except for iOS 10 at this time for A7 (except for downgrade with OTA blobs to 10.3.3)

This script works on Linux only, no macOS support

Specifically, this is for Ubuntu/Debian, and any other distros using the dpkg/apt package manager, and is for x86_64, not arm64.


All restores will use the latest baseband firmware and possibly the latest SEP, except for ota downgrade to 10.3.3 on A7 devices, which will use 10.3.3 SEP instead of latest SEP.

Alternatively, you can use Legacy iOS Kit (https://github.com/LukeZGD/Legacy-iOS-Kit) by LukeZGD to OTA downgrade to iOS 10.3.3 instead of surrealra1n.

If you'd like to contribute to this project, please do so we can make surrealra1n even better!
And if there is any issues, PLEASE open one up on the issues tab.

DO NOT OPEN ISSUES at Futurerestore if there's an issue with surrealra1n, it most likely isn't futurerestore's fault.

# Compatibility:

A7 devices: iOS 11.3 - 12.5.6 (tethered & untethered), 10.3.3 as an untethered OTA downgrade, tethered 10.x restores will not boot currently and thus not supported.

A8 devices: iOS 11.3 - 12.5.6 (tethered & untethered, but cannot boot yet because I haven't finished the firmware key list)

A9+ devices: No support! Use turdus merula instead if device is A9-A10 (https://sep.lol), or downr1n (for tethered downgrades, https://github.com/edwin170/downr1n) or the nightly's futurerestore if your device is A11

# What tools does surrealra1n depend on:

LukeeGD fork of futurerestore and other tools. Some tools may be downloaded from Legacy iOS Kit & Semaphorin as these tools are bundled with Legacy iOS Kit and/or Semaphorin.

These tools may be under a different license than the surrealra1n script itself, but the surrealra1n shell script is under Apache License Version 2.0.

# Usage:

If you're running it for the first time, go into the surrealra1n folder, then run: chmod +x surrealra1n.sh

To run the script, type ./surrealra1n.sh into the terminal

To create a custom IPSW + restore chain to downgrade your device tethered, run:

./surrealra1n.sh --make-custom-ipsw [path to target IPSW, aka the version you are downgrading to] [path to latest signed IPSW, required so the device will not get stuck in DFU afterwards] [iOS version you are downgrading to, example: 11.4]

Enter your sudo password when prompted to.

To downgrade your device with an existing custom IPSW & restore chain, run:

./surrealra1n.sh --restore [iOS version you are downgrading to, example: 11.4]

Enter your sudo password when prompted to, and follow instructions. You may need to put your device into DFU mode.

NOTE: for certain A7 devices only, to downgrade to iOS 10.3.3, run:

./surrealra1n.sh --ota-downgrade [iOS 10.3.3 IPSW path]

Enter your sudo password when prompted to, and follow instructions. You may need to put your device into DFU mode.

NOTE: If you have SHSH blobs and you want to do an untethered downgrade, run:

./surrealra1n.sh --downgrade [IPSW PATH] [SHSH BLOB]

Enter your sudo password when prompted to, and follow instructions. You may need to put your device into DFU mode.

To boot tethered right now, run:

./surrealra1n.sh --boot [iOS version you are on right now, example: 11.4]

Enter your sudo password when prompted to, and follow instructions. You may need to put your device into DFU mode. It may ask for an IPSW file if boot files do not exist

# Thanks to:

libimobiledevice team, tihmstar, LukeeGD/LukeZGD, xerub, plooshi and more!
