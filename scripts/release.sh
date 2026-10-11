#!/bin/bash
# Builds the universal app, signs it with Developer ID, has Apple notarize it and staples the
# ticket, then writes dist/TermPaste-<version>.zip for a GitHub release.
# NOTARY_PROFILE names a notarytool keychain profile (xcrun notarytool store-credentials).
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a notarytool keychain profile (see xcrun notarytool store-credentials).}"
[[ "${SIGN_IDENTITY:-}" == "-" ]] && { printf 'A release needs a Developer ID signature, not ad hoc.\n' >&2; exit 1; }
version="$(plutil -extract CFBundleShortVersionString raw Resources/Info.plist)"
app="dist/TermPaste.app"
zip="dist/TermPaste-$version.zip"

swift test
UNIVERSAL=1 bash scripts/build-app.sh
lipo -info "$app/Contents/MacOS/TermPaste"
signature="$(codesign -dvv "$app" 2>&1)"
[[ "$signature" == *"Authority=Developer ID Application"* ]] || { printf 'Not signed with Developer ID.\n' >&2; exit 1; }

rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"
xcrun notarytool submit "$zip" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"

# Zip again so the download carries the stapled ticket and opens offline without a warning.
rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"
shasum -a 256 "$zip"
printf 'Release: %s\n' "$zip"
