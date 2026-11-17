# Build the host patcher. Its ARM64 handlers are already linked for 11A466.
# No SDK, network access, Python or firmware is needed to compile the patcher.
CC = cc
CFLAGS = -O2 -std=c11 -Wall -Wextra -Werror
HOST := $(shell uname -s)
SOURCES = sep-bridge.c
.PHONY: all clean macos-arm64 macos-x86_64 macos-universal linux-x86_64
ifeq ($(HOST),Darwin)
all: macos-universal
else
all: linux-x86_64
endif
macos-arm64: build/macos-arm64/sep-bridge
macos-x86_64: build/macos-x86_64/sep-bridge
macos-universal: build/macos-universal/sep-bridge
linux-x86_64: build/linux-x86_64/sep-bridge
build/macos-arm64/sep-bridge: $(SOURCES)
	mkdir -p $(@D)
	$(CC) $(CFLAGS) -arch arm64 -mmacosx-version-min=11.0 $< -o $@
build/macos-x86_64/sep-bridge: $(SOURCES)
	mkdir -p $(@D)
	$(CC) $(CFLAGS) -arch x86_64 -mmacosx-version-min=10.12 $< -o $@
build/macos-universal/sep-bridge: build/macos-arm64/sep-bridge build/macos-x86_64/sep-bridge
	mkdir -p $(@D)
	lipo -create $^ -output $@
build/linux-x86_64/sep-bridge: $(SOURCES)
	mkdir -p $(@D)
	$(CC) $(CFLAGS) $< -o $@
clean:
	rm -rf build
