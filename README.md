# surrealra1n 

A tethered downgrade tool for iPhone 5S, all A8(X), and A11 devices

Supports macOS and Linux

For surrealra1n support, join the [surrealra1n](https://discord.gg/kDXVHhTQs2) Discord Server

# Compatible devices and versions:

View the [Supported Devices](https://github.com/pwnerblu/surrealra1n/wiki/Supported-Devices) section in the wiki for more information

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

Mineek - iPhone X restored patcher, used for ipx restores 14.3-15.6.1 (my fork of the patcher is used for seprmvr64 restores on A8+), openra1n, and seprmvr64

Nathan (verygenericname) - SSHRD_Script












