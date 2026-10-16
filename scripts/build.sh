#!/bin/zsh
# Compila e assembla build/Trove.app.
#   --install   copia in /Applications (chiude l'istanza in esecuzione)   --open  installa e apre
#   VERSION=1.2.0  imposta CFBundleShortVersionString/CFBundleVersion
#   SIGN_IDENTITY="Developer ID Application: …"  firma con un'identità; senza, usa quella locale
#   di scripts/make-cert.sh se presente, altrimenti firma ad-hoc.
set -euo pipefail
cd "$(dirname "$0")/.."
LOCAL_ID="Trove Local Signing"
ID=${SIGN_IDENTITY:-}
if [[ -z $ID ]] && security find-identity -p codesigning 2>/dev/null | grep -q "$LOCAL_ID"; then
  ./scripts/make-cert.sh >/dev/null && ID=$LOCAL_ID
fi
[[ -f Resources/AppIcon.icns ]] || swift scripts/make-icon.swift Resources/AppIcon.icns
swift build -c release --arch arm64
BIN=$(swift build -c release --arch arm64 --show-bin-path)
APP=build/Trove.app
rm -rf $APP && mkdir -p $APP/Contents/{MacOS,Resources,Frameworks}
cp $BIN/Trove $APP/Contents/MacOS/Trove
cp Resources/Info.plist $APP/Contents/Info.plist
cp -R Resources/AppIcon.icns Resources/*.lproj $APP/Contents/Resources/
ditto $BIN/Sparkle.framework $APP/Contents/Frameworks/Sparkle.framework
if [[ -n ${VERSION:-} ]]; then
  plutil -replace CFBundleShortVersionString -string "$VERSION" $APP/Contents/Info.plist
  plutil -replace CFBundleVersion -string "${BUILD_NUMBER:-$VERSION}" $APP/Contents/Info.plist
fi
if [[ $ID == "Developer ID"* ]]; then
  # hardened runtime + timestamp per la notarizzazione, framework firmato dall'interno verso l'esterno
  S=(codesign --force --options runtime --timestamp --sign "$ID")
  $S $APP/Contents/Frameworks/Sparkle.framework/Versions/B/{XPCServices/*.xpc,Autoupdate,Updater.app}
  $S $APP/Contents/Frameworks/Sparkle.framework
  $S $APP
else
  # ponytail: senza Team ID niente hardened runtime, la library validation rifiuterebbe Sparkle
  codesign --force --deep --sign "${ID:--}" $APP
fi
codesign --verify --deep --strict $APP && echo "Pronta: $APP"
[[ ${1:-} == --install || ${1:-} == --open ]] || exit 0
pkill -x Trove 2>/dev/null && sleep 0.5 || true
rm -rf /Applications/Trove.app && ditto $APP /Applications/Trove.app
echo "Installata: /Applications/Trove.app"
[[ ${1:-} == --open ]] && open /Applications/Trove.app || true
