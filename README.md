# surrealra1n

A script that allows tethered & untethered downgrades of all 64-bit devices vulnerable to checkm8.
So what iOS versions can you downgrade to with surrealra1n? Any version with SEP compatibility, except for iOS 10 at this time for A7 (except for downgrade with OTA blobs to 10.3.3)

All restores will use the latest baseband firmware and possibly the latest SEP, except for ota downgrade to 10.3.3 on A7 devices, which will use 10.3.3 SEP instead of latest SEP.

# Version Compatibility:

A7 devices: iOS 11.3 - 12.5.6 (tethered & untethered), 10.3.3 as an untethered OTA downgrade, tethered 10.x restores will not boot currently

A8 devices: iOS 11.3 - 12.5.6 (tethered & untethered)

A9+ devices: No support! Use turdus merula instead if device is A9-A10 (https://sep.lol), or downr1n (for tethered downgrades, https://github.com/edwin170/downr1n) or the nightly's futurerestore if your device is A11

# What tools does surrealra1n depend on:

The nightly's version of futurerestore and other tools. Some tools may be downloaded from Legacy iOS Kit & Semaphorin

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

To boot tethered right now, run:

./surrealra1n.sh --boot [iOS version you are on right now, example: 11.4]

Enter your sudo password when prompted to, and follow instructions. You may need to put your device into DFU mode. It may ask for an IPSW file if boot files do not exist
