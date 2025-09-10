# w1nterst0rm Downgrade Kit

An all in one utility for downgrading all 64-bit checkm8 devices.
Huge thanks to the libimobiledevice team and the people that created the downgrade tools that this utility uses.

DISCLAIMER: w1nterst0rm is a shell script that makes downgrading straightforward, not the downgrade tool itself.
And the binaries for the tool aren't in this repository, they are downloaded at runtime when you run menu.sh for the first time.

This script supports macOS (not tested) and Linux.
Turdus Merula officially supports macOS and iOS at this time, so if you are downgrading an A9/A10 device on Linux,
the Turdus Merula linux test build will be used.

If you're looking to downgrade your A7 device to iOS 10.3.3, please use Legacy iOS Kit (https://github.com/LukeZGD/Legacy-iOS-Kit)
instead of w1nterst0rm.

Regarding SEP/BB compatibility, you can restore A7/A8 devices to iOS 11.3 or newer safely, and A11 devices to iOS 16 safely,
but the iOS 16 baseband/SEP is partially incompatible with iOS 14.3-15.x, fully incompatible with iOS 14.2 and lower.

SEP compatibility doesn't matter much with A9/A10, because Turdus Merula is used to downgrade those devices.
BUT BASEBAND COMPATIBILITY still matters, mainly on A10: If you downgrade to iOS 10.x on an A10 device, you may get activation issues.
A9 disclaimer if you're downgrading to iOS 9:

You most likely will get activation problems! It is recommended to downgrade to iOS 10.x instead.
And also in this script, when downgrading to iOS 9.x, it will automatically downgrade your device to 10.2.1 first, then the iOS 9 version, this is to bypass the FDR error.

If there is any issues with w1nterst0rm Downgrade Kit, please let me know.
