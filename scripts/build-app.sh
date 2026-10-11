#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"
# UNIVERSAL=1 builds for Apple silicon and Intel in one binary, as releases are.
build_flags=(-c release)
[[ "${UNIVERSAL:-0}" == 1 ]] && build_flags+=(--arch arm64 --arch x86_64)
swift build "${build_flags[@]}"
binary_dir="$(swift build "${build_flags[@]}" --show-bin-path)"
app_dir="$repo_dir/dist/TermPaste.app"
if [[ -e "$app_dir" ]]; then
    backup_dir="$(mktemp -d "$repo_dir/.build/bundle-backup.XXXXXX")"
    mv "$app_dir" "$backup_dir/TermPaste.app"
fi
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/TermPaste" "$app_dir/Contents/MacOS/TermPaste"
cp "$repo_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
cp "$repo_dir/Resources/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
plutil -lint "$app_dir/Contents/Info.plist"
# A Developer ID signature keeps the designated requirement (bundle ID + team) stable across
# rebuilds, so macOS keeps the Accessibility grant. An ad-hoc signature changes with every build.
# SIGN_IDENTITY overrides the identity; SIGN_IDENTITY=- signs ad hoc.
identity="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)}"
if [[ -z "$identity" ]]; then
    printf 'No "Developer ID Application" identity in the keychain; set SIGN_IDENTITY (or SIGN_IDENTITY=- for ad hoc).\n' >&2
    exit 1
fi
if [[ "$identity" == "-" ]]; then
    codesign --force --sign - "$app_dir"
else
    codesign --force --options runtime --timestamp --sign "$identity" "$app_dir"
fi
codesign --verify --strict "$app_dir"
printf 'Built: %s\nSigned: %s\n' "$app_dir" "$identity"
