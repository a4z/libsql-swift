#!/usr/bin/env sh

set -xe +f

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
TURSO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)
CLIBSQL_DIR="$TURSO_DIR/CLibsql"
LIBSQL_C_DIR="$CLIBSQL_DIR/libsql-c"

cd "$LIBSQL_C_DIR"

export IPHONEOS_DEPLOYMENT_TARGET=15.1

function build_ios() {
    iphone=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk
    iphonesimulator=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk

    CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_DEBUG=true
    RUSTFLAGS="-C link-arg=-F$SDKROOT/System/Library/Frameworks"
    CFLAGS="-DHAVE_GETHOSTUUID=0"

    SDKROOT="$iphone"
    cargo build --target aarch64-apple-ios --release

    SDKROOT="$iphonesimulator"
    cargo build --target x86_64-apple-ios --release

    SDKROOT="$iphonesimulator"
    cargo build --target aarch64-apple-ios-sim --release

    mkdir -p ./target/universal-ios-sim/release

    lipo \
        ./target/x86_64-apple-ios/release/liblibsql.a \
        ./target/aarch64-apple-ios-sim/release/liblibsql.a \
        -create -output ./target/universal-ios-sim/release/liblibsql.a
}

build_ios

# nix develop .# -c "./build.sh"

mkdir -p ./target/universal-macos/release

lipo \
    ./target/x86_64-apple-darwin/release/liblibsql.a \
    ./target/aarch64-apple-darwin/release/liblibsql.a \
    -create -output ./target/universal-macos/release/liblibsql.a

rm -rf "$CLIBSQL_DIR/CLibsql.xcframework"

include_dir=$(mktemp -d)

cp ./libsql.h "$include_dir/"
cp "$CLIBSQL_DIR/module.modulemap" "$include_dir/"

xcodebuild -create-xcframework \
    -library ./target/universal-ios-sim/release/liblibsql.a -headers $include_dir \
    -library ./target/aarch64-apple-ios/release/liblibsql.a -headers $include_dir \
    -library ./target/universal-macos/release/liblibsql.a -headers $include_dir \
    -output "$CLIBSQL_DIR/CLibsql.xcframework"

rm -rf "$include_dir"
