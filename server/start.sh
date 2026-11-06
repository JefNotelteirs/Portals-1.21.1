#!/usr/bin/env bash
# Portals 1.21.1 server - Minecraft 1.21.1 / NeoForge 21.1.265
# Needs Java 21. The system default here is Java 27, which NeoForge 21.1 does not support,
# so this defaults to the Java 21 runtime that Prism Launcher downloaded.
# Override with:  JAVA=/path/to/java21/bin/java ./start.sh
cd "$(dirname "$0")"

JAVA="${JAVA:-$HOME/.local/share/PrismLauncher/java/java-runtime-delta/bin/java}"

# Re-sync mods/configs from the pack (server-side files only) before every start.
# PACK_URL can point at a hosted pack.toml later; it defaults to the local checkout.
PACK_URL="${PACK_URL:-file://$(cd .. && pwd)/pack.toml}"
if [ "${SKIP_PACKWIZ:-0}" != "1" ]; then
  "$JAVA" -jar packwiz-installer-bootstrap.jar --bootstrap-no-update -g -s server "$PACK_URL" || {
    echo "packwiz sync failed, not starting the server" >&2
    exit 1
  }
fi

exec "$JAVA" @user_jvm_args.txt @libraries/net/neoforged/neoforge/21.1.265/unix_args.txt nogui "$@"
