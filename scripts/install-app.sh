#!/bin/bash
# Installs the built bundle as /Applications/TermPaste.app. Any earlier copy, including one from
# before the app was renamed (Terminal Image Paste), is kept under
# ~/Library/Application Support/TermPaste/backups.
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
app_dir="$repo_dir/dist/TermPaste.app"
destination="/Applications/TermPaste.app"
earlier_locations=(
    "$HOME/Applications/TermPaste.app"
    "/Applications/Terminal Image Paste.app"
    "$HOME/Applications/Terminal Image Paste.app"
)
[[ -d "$app_dir" ]] || { printf 'Run scripts/build-app.sh first.\n' >&2; exit 1; }
codesign --verify --strict "$app_dir"
if pgrep -x TermPaste >/dev/null || pgrep -x TerminalImagePaste >/dev/null; then
    printf 'Quit TermPaste from its menu before updating it.\n' >&2
    exit 1
fi
[[ -w /Applications ]] || { printf '/Applications is not writable for this user.\n' >&2; exit 1; }
backup_root="$HOME/Library/Application Support/TermPaste/backups"
for existing in "$destination" "${earlier_locations[@]}"; do
    if [[ -e "$existing" || -L "$existing" ]]; then
        mkdir -p "$backup_root"
        backup_dir="$(mktemp -d "$backup_root/install.XXXXXX")"
        mv "$existing" "$backup_dir/"
        printf 'Previous app preserved: %s\n' "$backup_dir"
    fi
done
ditto "$app_dir" "$destination"
codesign --verify --strict "$destination"
printf 'Installed: %s\n' "$destination"
printf 'Launch with: open -g "%s"\n' "$destination"
