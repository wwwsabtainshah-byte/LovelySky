#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/4] Flutter dependencies..."
flutter pub get

echo "[2/4] Static analysis..."
flutter analyze

echo "[3/4] Release APK..."
flutter build apk --release

echo "[4/4] Copy APK to Downloads..."
mkdir -p "$HOME/storage/shared/Download"
cp -f build/app/outputs/flutter-apk/app-release.apk \
  "$HOME/storage/shared/Download/LovelySkyBlue-release.apk"

echo "DONE: $HOME/storage/shared/Download/LovelySkyBlue-release.apk"
