#!/bin/sh

#  build.sh
#  Builds all supported architectures of FFmpeg for Android.
#  Versions: NDK - r16b, FFmpeg - 4.0.2

NDK=/Users/chenzhichang/Downloads/android-ndk-r16b
# MacOS：darwin-86_64
HOST=darwin-x86_64

# Takes three arguments:
# First: ARCH, supported values: armeabi-v7a, arm64-v8a, x86, x86_64
# Second: platform level. Range: 14-19, 21-24, 26-28
# Third: additinal configuration flags. Already present flags: --enable-cross-compile --disable-static --disable-programs --disable-doc --enable-shared --enable-protocol=file --enable-pic --enable-small
build () {
    ARCH=$1
    LEVEL=$2
    if [ ! $ARCH ]; then
       ARCH=armeabi-v7a
    fi 
    if [ ! $LEVEL ]; then
       LEVEL=21
    fi
    ISYSROOT=$NDK/sysroot
    PLATFORM_ARCH=
    CFLAGS=
    TARGET=
    TOOLCHAIN_FOLDER=
    
    CONFIGURATION="--disable-asm \
    --enable-cross-compile \
    --disable-static \
    --disable-programs \
    --disable-doc \
    --enable-shared \
    --enable-protocol=file \
    --enable-pic \
    --enable-small \
    --disable-devices \
    $3"
    

    case $ARCH in
        "armeabi-v7a")
            TARGET="arm-linux-androideabi"
            CFLAGS="-march=armv7-a -mfloat-abi=softfp -mfpu=neon"
            PLATFORM_ARCH="arm"
            TOOLCHAIN_FOLDER="arm-linux-androideabi"
        ;;
        "arm64-v8a")
            TARGET="aarch64-linux-android"
            CFLAGS="-march=armv8-a"
            PLATFORM_ARCH="arm64"
            CONFIGURATION="$CONFIGURATION --disable-pthreads"
            TOOLCHAIN_FOLDER="aarch64-linux-android"
        ;;
        "x86")
            TARGET="i686-linux-android"
            CFLAGS="-march=i686 -mtune=intel -mssse3 -mfpmath=sse -m32"
            PLATFORM_ARCH="x86"
            TOOLCHAIN_FOLDER="x86"
        ;;
        "x86_64")
            TARGET="x86_64-linux-android"
            CFLAGS="-march=x86-64 -msse4.2 -mpopcnt -m64 -mtune=intel"
            PLATFORM_ARCH="x86_64"
            TOOLCHAIN_FOLDER="x86_64"
        ;;
    esac

    CROSS_PREFIX=$NDK/toolchains/$TOOLCHAIN_FOLDER-4.9/prebuilt/$HOST/bin/$TARGET-
    ASM=$ISYSROOT/usr/include/$TARGET
    SYSROOT=$NDK/platforms/android-$LEVEL/arch-$PLATFORM_ARCH/
    PREFIX="android/$ARCH"

    ./configure --prefix=$PREFIX  \
                $CONFIGURATION \
                --cross-prefix=$CROSS_PREFIX \
                --arch=$PLATFORM_ARCH \
                --target-os=android \
                --sysroot=$SYSROOT \
                --extra-cflags="$CFLAGS -I$ASM -isysroot $ISYSROOT -D__ANDROID_API__=$LEVEL -Wfatal-errors -U_FILE_OFFSET_BITS -Os -fPIC -DANDROID -D__thumb__ -Wno-deprecated "


    make clean
    make -j4
    make install
}

build "armeabi-v7a" "21"
build "arm64-v8a" "21"
build "x86_64" "21"
build "x86" "21"
