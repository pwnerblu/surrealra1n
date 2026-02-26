# surrealra1n 

A tethered downgrade tool for iPhone 5S, all A8(X), iPad 6 (one A10 device), and A11 devices

# Compatible devices and versions:

iPod touch 6:

8.4 - 9.3.5 (seprmvr64 restore)

10.0 - 11.2.6 (no support)

11.3 - 12.5.7 (supported with SEP)

iPhone 6 and 6 Plus:

8.0 - 11.2.6 (no support)

11.3 - 12.5.7 (supported with SEP)

iPad Air 2:

8.1 - 11.2.6 (no support)

11.3 - 15.8.5 (supported with SEP, iOS 11.3-13.7 will not have Touch ID though)

iPad mini 4:

9.0 - 13.3.1 (no support)

13.4 - 15.8.5 (supported with SEP, 13 will not have Touch ID though)

iPhone 5S:

7.0 - 9.3.5 (seprmvr64 restore, not yet supported on iPhone6,2)

10.0 (no support yet)

10.1 - 12.5.7 (supported with SEP, 10.1 will not have Touch ID, 11.0 - 11.2.6 has broken features)

iPhone 8:

11.0 - 13.7 (no support)

14.0 - 14.2 (supported with SEP, though 14.3 iBoot is used with those restores, broken features)

14.3 - 15.6.1 (supported with SEP, broken features)

iPhone 8 Plus and iPhone X:

11.0 - 14.2 (no support)

14.3 - 15.6.1 (supported with SEP, broken features)

iPad mini 2 (excluding iPad4,6):

7.0.3 - 10.2.1 (no support)

10.3 - 12.5.7 (supported with SEP, 11.0-11.2.6 will have broken features)

iPad mini 2 (iPad4,6):

7.1 - 11.2.6 (no support)

11.3 - 12.5.7 (supported with SEP)

# Usage:

Make a custom IPSW for tethered restore:

Example: `./surrealra1n.sh --make-custom-ipsw [target ipsw] [latest ipsw] 11.4`

Make a custom IPSW for tethered restore with seprmvr64 (7.0-9.3.5):

Example: `./surrealra1n.sh --seprmvr64-ipsw [target ipsw] [latest ipsw] 8.4.1`

Make a custom IPSW for tethered restore with seprmvr64, and attempt activation record stitching (7.0-9.2.1), note that this IPSW type is device-specific:

Example: `./surrealra1n.sh --seprmvr64-ipsw [target ipsw] [latest ipsw] 9.2.1 --stitch-activation`

Restore the device with an existing custom IPSW:

Example: `./surrealra1n.sh --restore 11.4`

Restore the device with an existing custom iPSW (seprmvr64):

Example: `./surrealra1n.sh --seprmvr64-restore 8.4.1`

Boot the device after tethered downgrade:

Example: `./surrealra1n.sh --boot 11.4`

Boot the device after seprmvr64 tethered downgrade:

Example: `./surrealra1n.sh --seprmvr64-boot 8.4.1`

# Thanks to:

libimobiledevice team, tihmstar, LukeeGD/LukeZGD, xerub, plooshi, etc! (for the tools it has to download)

Mineek - iPhone X restored patcher, used for ipx restores 14.3-15.6.1 (my fork of the patcher is used for seprmvr64 restores on A8+), and seprmvr64



