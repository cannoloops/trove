#!/bin/zsh
# Crea build/release/Trove-<versione>.dmg e appcast.xml per Sparkle.
#   VERSION=1.2.0 SPARKLE_KEY_FILE=chiave ./scripts/release.sh
# Senza SPARKLE_KEY_FILE generate_appcast usa la chiave nel portachiavi (account io.github.cannoloops.trove).
set -euo pipefail
cd "$(dirname "$0")/.."
: ${VERSION:?serve VERSION, es. VERSION=1.2.0}
REPO=${GITHUB_REPOSITORY:-cannoloops/trove}
VERSION=$VERSION ./scripts/build.sh
OUT=build/release; rm -rf $OUT; mkdir -p $OUT
STAGE=$(mktemp -d); trap 'rm -rf $STAGE' EXIT
ditto build/Trove.app $STAGE/Trove.app && ln -s /Applications $STAGE/Applications
hdiutil create -quiet -volname Trove -srcfolder $STAGE -format UDZO $OUT/Trove-$VERSION.dmg
KEY=(--account io.github.cannoloops.trove); [[ -n ${SPARKLE_KEY_FILE:-} ]] && KEY=(--ed-key-file $SPARKLE_KEY_FILE)
.build/artifacts/sparkle/Sparkle/bin/generate_appcast $KEY \
  --download-url-prefix https://github.com/$REPO/releases/download/v$VERSION/ \
  --link https://github.com/$REPO $OUT
ls -lh $OUT
