#!/usr/bin/env bash
# Build the Janzeer wallet for one platform on THIS machine and drop a versioned, hashed archive into
# wallet/build/release/ — the same shape as the node bundle kit, so backend_v03/deploy/build-dist.sh can stage it under
# downloads/wallet/<version>/ and the website prints its SHA-256 (docs/md/wallet-ui-plan.md §7).
#
#   ./release/build-wallet.sh android   # → janzeer-wallet-<ver>-android.apk   (any host with the Android SDK)
#   ./release/build-wallet.sh linux     # → janzeer-wallet-<ver>-linux-x64.tar.gz (Linux host)
#   ./release/build-wallet.sh windows   # → janzeer-wallet-<ver>-windows-x64.zip  (Windows host, Git Bash)
#   ./release/build-wallet.sh macos     # → janzeer-wallet-<ver>-macos.zip        (macOS host)
#   ./release/build-wallet.sh all       # every platform this host can build
#
# Android signing: with no keystore configured the APK is signed with the debug key (fine for the rehearsal and for
# side-loading). Before the public release generate a keystore ONCE, keep it offline with the anchors' seeds, and set
# JANZEER_KEYSTORE=/path/release.jks JANZEER_KEY_ALIAS=… JANZEER_KEYSTORE_PASSWORD=… JANZEER_KEY_PASSWORD=… in the
# environment: android/app/build.gradle.kts picks them up. Every later update MUST be signed with the same key.
set -euo pipefail
cd "$(dirname "$0")/.."
VER=$(sed -n 's/^version: *\([0-9][0-9.]*\).*/\1/p' pubspec.yaml | head -1)
OUT=build/release; mkdir -p "$OUT"
NAME="janzeer-wallet-$VER"
say() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }

build_android() {
  say "android: flutter build apk --release ($VER)"
  flutter build apk --release
  cp build/app/outputs/flutter-apk/app-release.apk "$OUT/$NAME-android.apk"
}
build_linux() {
  say "linux: flutter build linux --release ($VER)"
  flutter build linux --release
  local bundle=build/linux/x64/release/bundle
  rm -rf "build/$NAME-linux-x64"; mkdir -p "build/$NAME-linux-x64"
  cp -r "$bundle"/. "build/$NAME-linux-x64/"
  cat >"build/$NAME-linux-x64/README.txt" <<EOF
Janzeer Wallet $VER — Linux x86-64
Run:  ./wallet        (needs GTK 3; on Debian/Ubuntu: sudo apt install libgtk-3-0)
Keys never leave this machine. Source: https://github.com/janzeerorg — https://janzeer.org
EOF
  ( cd build && tar -czf "release/$NAME-linux-x64.tar.gz" "$NAME-linux-x64" )
}
build_windows() {
  say "windows: flutter build windows --release ($VER)"
  flutter build windows --release
  local bundle=build/windows/x64/runner/Release
  rm -rf "build/$NAME-windows-x64"; mkdir -p "build/$NAME-windows-x64"; cp -r "$bundle"/. "build/$NAME-windows-x64/"
  ( cd build && rm -f "release/$NAME-windows-x64.zip" && powershell -NoProfile -Command "Compress-Archive -Path '$NAME-windows-x64' -DestinationPath 'release/$NAME-windows-x64.zip'" 2>/dev/null || zip -qr "release/$NAME-windows-x64.zip" "$NAME-windows-x64" )
}
build_macos() {
  say "macos: flutter build macos --release ($VER)"
  flutter build macos --release
  ( cd build/macos/Build/Products/Release && rm -f "../../../../release/$NAME-macos.zip" && zip -qry "../../../../release/$NAME-macos.zip" wallet.app )
}

case "${1:-}" in
  android) build_android ;;
  linux) build_linux ;;
  windows) build_windows ;;
  macos) build_macos ;;
  all)
    build_android
    case "$(uname -s)" in Linux) build_linux ;; Darwin) build_macos ;; MINGW*|MSYS*|CYGWIN*) build_windows ;; esac ;;
  *) echo "usage: $0 android|linux|windows|macos|all"; exit 2 ;;
esac
( cd "$OUT" && sha256sum janzeer-wallet-* >SHA256SUMS 2>/dev/null || shasum -a 256 janzeer-wallet-* >SHA256SUMS )
say "release archives in $OUT/:"; ls -la "$OUT" | grep -v '^total'
