#!/usr/bin/env bash
# Copies the newest pack-balance build into the pack and refreshes the packwiz index.
# Usage: ~/minecraft-packs/Portals-1.21.1/sync-pack-balance.sh [path/to/pack_balance-neoforge-*.jar]
# Default source: the newest jar in ~/mc-mods/pack-balance-neoforge/dist/
# Clients pick it up on their next Prism launch; the server on its next start.sh.
set -euo pipefail
PACK="$HOME/minecraft-packs/Portals-1.21.1"
SRC="${1:-$(ls -t "$HOME"/mc-mods/pack-balance-neoforge/dist/pack_balance-neoforge-*.jar | grep -v -e sources -e dev | head -1)}"
[ -f "$SRC" ] || { echo "No pack-balance jar found at: $SRC" >&2; exit 1; }

find "$PACK/mods" -maxdepth 1 -name 'pack_balance-neoforge-*.jar' -delete
cp "$SRC" "$PACK/mods/"
cd "$PACK"
"$HOME/go/bin/packwiz" refresh
echo "Synced $(basename "$SRC") sha256 $(sha256sum "$SRC" | cut -d' ' -f1)"
echo "Commit with: git -C $PACK add -A mods index.toml pack.toml && git -C $PACK commit -m 'Update pack-balance'"
