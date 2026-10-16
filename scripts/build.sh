#!/bin/zsh
# Compila, assembla, firma e installa /Applications/Trove.app
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/make-cert.sh >/dev/null
[[ -f Resources/AppIcon.icns ]] || swift scripts/make-icon.swift Resources/AppIcon.icns
swift build -c release
APP=build/Trove.app
rm -rf $APP && mkdir -p $APP/Contents/MacOS $APP/Contents/Resources
cp .build/release/Trove $APP/Contents/MacOS/Trove
cp Resources/Info.plist $APP/Contents/Info.plist
cp Resources/AppIcon.icns $APP/Contents/Resources/
codesign --force --options runtime --keychain ~/Library/Keychains/trove-signing.keychain-db --sign "Trove Local Signing" $APP
pkill -x Trove 2>/dev/null && sleep 0.5 || true
rm -rf /Applications/Trove.app && cp -R $APP /Applications/Trove.app
codesign --verify --strict /Applications/Trove.app && echo "Installata: /Applications/Trove.app"
[[ "${1:-}" == "--open" ]] && open /Applications/Trove.app || true
