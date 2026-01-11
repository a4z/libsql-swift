#!/usr/bin/env sh

set -xe +f

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
TURSO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)
CLIBSQL_DIR="$TURSO_DIR/CLibsql"
LIBSQL_C_DIR="$CLIBSQL_DIR/libsql-c"

cd "$LIBSQL_C_DIR"

# Clean all previous build artifacts first to avoid cross-contamination
echo "Cleaning all previous build artifacts..."
cargo clean

export IPHONEOS_DEPLOYMENT_TARGET=15.1
export RUSTFLAGS="--remap-path-prefix=$HOME=~"

# Build iOS targets (Apple Silicon only)
function build_ios() {
    iphone=$(xcrun --sdk iphoneos --show-sdk-path)
    iphonesimulator=$(xcrun --sdk iphonesimulator --show-sdk-path)

    CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_DEBUG=true
    RUSTFLAGS="$RUSTFLAGS -C link-arg=-F$SDKROOT/System/Library/Frameworks"
    CFLAGS="-DHAVE_GETHOSTUUID=0"

    echo "Building for aarch64-apple-ios..."
    SDKROOT="$iphone" cargo build --target aarch64-apple-ios --release

    echo "Building for aarch64-apple-ios-sim..."
    SDKROOT="$iphonesimulator" cargo build --target aarch64-apple-ios-sim --release
}

# Build macOS targets (Apple Silicon only)
function build_macos() {
    echo "Building for aarch64-apple-darwin..."
    MACOSX_DEPLOYMENT_TARGET=11.0 cargo build --target aarch64-apple-darwin --features encryption --release
}

# Build all targets (macOS first, then iOS)
build_macos
build_ios

# Create XCFramework
echo "Creating XCFramework..."
rm -rf "$CLIBSQL_DIR/CLibsql.xcframework"

include_dir=$(mktemp -d)

cp ./libsql.h "$include_dir/"
cp "$CLIBSQL_DIR/module.modulemap" "$include_dir/"

xcodebuild -create-xcframework \
    -library ./target/aarch64-apple-ios-sim/release/liblibsql.a -headers $include_dir \
    -library ./target/aarch64-apple-ios/release/liblibsql.a -headers $include_dir \
    -library ./target/aarch64-apple-darwin/release/liblibsql.a -headers $include_dir \
    -output "$CLIBSQL_DIR/CLibsql.xcframework"

rm -rf "$include_dir"

echo "✅ XCFramework created successfully at $CLIBSQL_DIR/CLibsql.xcframework"
