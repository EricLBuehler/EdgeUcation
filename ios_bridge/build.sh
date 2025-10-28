#!/usr/bin/env bash
set -euo pipefail

# 1) Build Rust for device + Apple-silicon simulator
cargo build --release --target aarch64-apple-ios
cargo build --release --target aarch64-apple-ios-sim

# 2) Stage outputs
rm -rf build && mkdir -p build/ios build/ios-sim build/headers
cp target/aarch64-apple-ios/release/libios_bridge.a         build/ios/
cp target/aarch64-apple-ios-sim/release/libios_bridge.a     build/ios-sim/
cp ios_bridge.h                                             build/headers/

# 3) Recreate the XCFramework (write to a temp, then atomically replace)
TMP_OUT="$(pwd)/ios_bridge.tmp.xcframework"
FINAL_OUT="../ios_vlm/ios_vlm/ios_bridge.xcframework"

rm -rf "$TMP_OUT"
xcodebuild -create-xcframework \
  -library build/ios/libios_bridge.a -headers build/headers \
  -library build/ios-sim/libios_bridge.a -headers build/headers \
  -output "$TMP_OUT"

# 4) Replace in place and clear quarantine (once per path)
rm -rf "$FINAL_OUT"
mv "$TMP_OUT" "$FINAL_OUT"
xattr -dr com.apple.quarantine "$FINAL_OUT"

echo "✅ Rebuilt $FINAL_OUT"
