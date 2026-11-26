#!/usr/bin/env bash
# Links this repo's Zed config into ~/.config/zed.
# Existing files are moved to *.bak before linking.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
TARGET="$HOME/.config/zed"
mkdir -p "$TARGET"

for item in settings.json keymap.json themes; do
  [ -e "$REPO/$item" ] || continue
  if [ -e "$TARGET/$item" ] && [ ! -L "$TARGET/$item" ]; then
    mv "$TARGET/$item" "$TARGET/$item.bak"
    echo "backed up $TARGET/$item -> $item.bak"
  fi
  ln -sfn "$REPO/$item" "$TARGET/$item"
  echo "linked $TARGET/$item"
done

echo "Done. Restart Zed; extensions in auto_install_extensions install on start."
