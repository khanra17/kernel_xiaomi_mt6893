#!/bin/bash
#
# Compile script for the khanra17 kernel
# Based on the Hydrogen kernel build script by rio004
#

# Date/Time
SECONDS=0
DATE=$(date '+%Y%m%d-%H%M')

# Device
DEVICE="${1:-ares}"
DEFCONFIG="${DEVICE}_defconfig"
KERNEL_NAME="khanra17"
RELEASE_VERSION="v1.0.6"
BASE_KERNEL_VERSION="$(awk '$1 == "VERSION" || $1 == "PATCHLEVEL" || $1 == "SUBLEVEL" { version = version (version ? "." : "") $3 } END { print version }' Makefile)"
KERNEL_RELEASE="${BASE_KERNEL_VERSION}-${KERNEL_NAME}-${RELEASE_VERSION}"
ZIPNAME="${KERNEL_RELEASE}-${DEVICE}-${DATE}.zip"

echo -e "Building for: $DEVICE\n"

# Ensure the toolchain is available
TC_DIR="$HOME/toolchains/proton-clang"
CURRENT_DIR=$(pwd)
if [ ! -d "$TC_DIR" ]; then
    mkdir -p "$HOME/toolchains"
    cd "$HOME/toolchains"
    git clone --depth=1 https://gitlab.com/LeCmnGend/proton-clang.git -b clang-15 proton-clang
    cd "$CURRENT_DIR"
fi
export PATH="$TC_DIR/bin:$PATH"

# Process options
CLEAN_BUILD=false
for arg in "$@"; do
    case $arg in
        -c) CLEAN_BUILD=true ;;
        -ksu) echo "ReSukiSU + SUSFS are already integrated." ;;
    esac
done

[ "$CLEAN_BUILD" = true ] && rm -rf out

# Compilation process
mkdir -p out
if ! make O=out ARCH=arm64 HOSTCC=clang CC="ccache clang" LLVM=1 LLVM_IAS=1 "$DEFCONFIG"; then
    echo -e "\nDefconfig failed!"
    exit 1
fi

echo -e "\nStarting compilation...\n"
if ! make -j$(nproc --all) O=out ARCH=arm64 HOSTCC=clang CC="ccache clang" LLVM=1 LLVM_IAS=1 CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- Image.gz; then
    echo -e "\nCompilation failed!"
    exit 1
fi

echo -e "\nKernel compiled successfully! Zipping up...\n"
rm -rf AnyKernel3
for attempt in 1 2 3; do
    git clone -q --depth=1 https://github.com/rio004/AnyKernel3 AnyKernel3 && break
    echo "AnyKernel3 clone attempt $attempt failed."
    rm -rf AnyKernel3
    sleep 2
done
if [ ! -d AnyKernel3 ]; then
    echo "Packaging failed: unable to clone AnyKernel3."
    exit 1
fi

if ! cp out/arch/arm64/boot/Image.gz AnyKernel3/Image.gz; then
    echo "Packaging failed: unable to copy Image.gz."
    rm -rf AnyKernel3
    exit 1
fi
rm -f "$ZIPNAME"
if ! (cd AnyKernel3 && zip -r9 "../$ZIPNAME" * -x '*.git*' README.md '*placeholder*'); then
    echo "Packaging failed: zip command failed."
    rm -rf AnyKernel3 "$ZIPNAME"
    exit 1
fi
rm -rf AnyKernel3

echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s)!"
echo "Zip: $ZIPNAME"
