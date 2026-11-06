#!/usr/bin/env bash
# Copies the newest OneChunk build into the pack and refreshes the packwiz index.
# Usage: ~/minecraft-packs/Portals-1.21.1/sync-onechunk.sh [path/to/onechunk-neoforge-*.jar]
# Default source: the newest jar in ~/mc-mods/onechunk-neoforge/dist/
# Clients pick it up on their next Prism launch; the server on its next start.sh.
set -euo pipefail
PACK="$HOME/minecraft-packs/Portals-1.21.1"
SRC="${1:-$(ls -t "$HOME"/mc-mods/onechunk-neoforge/dist/onechunk-neoforge-*.jar | grep -v -e sources -e dev | head -1)}"
[ -f "$SRC" ] || { echo "No OneChunk jar found at: $SRC" >&2; exit 1; }

# Remove the previous OneChunk jar(s) from the pack, then copy the new one in.
find "$PACK/mods" -maxdepth 1 -name 'onechunk-neoforge-*.jar' -delete
cp "$SRC" "$PACK/mods/"
cd "$PACK"
"$HOME/go/bin/packwiz" refresh
echo "Synced $(basename "$SRC") sha256 $(sha256sum "$SRC" | cut -d' ' -f1)"
echo "Commit with: git -C $PACK add -A mods index.toml pack.toml && git -C $PACK commit -m 'Update OneChunk'"
