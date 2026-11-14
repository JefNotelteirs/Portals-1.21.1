# Psycho Gaming 2027 (Portals 1.21.1)

## Install (players)

1. Install Prism Launcher (prismlauncher.org, Windows installer is fine) and log in with your Minecraft account.
2. Download **PsychoGaming2027-Prism.zip**:
   https://github.com/JefNotelteirs/Portals-1.21.1/releases/latest/download/PsychoGaming2027-Prism.zip
3. In Prism: **Add Instance**, **Import**, pick the zip, **OK**.
4. Select "Psycho Gaming 2027" and press **Launch**. The first launch downloads all mods (a few minutes) and
   asks one question: tick "AZERTY keyboard" only if you play on AZERTY. Every later launch updates the pack.
5. The server "Psycho Gaming 2027" is already in your multiplayer list.

Everything is set in the zip: Minecraft 1.21.1 + NeoForge 21.1.265, 4 GB memory, auto-update from this repo.
Shaders (Iris) are installed but off; pick one under Options, Video Settings, Shader Packs.

## Status at a glance

| Thing | Status |
| --- | --- |
| Server boots headless to "Done" | Tested, clean (see Evidence) |
| World generation incl. Twilight Forest, Nether, End | Tested: 256 TF chunks force-generated, TF structures and biomes located, 20 TPS |
| Server restart on an existing world | Tested, clean |
| Vanilla `keepInventory` is false | Tested (`gamerule keepInventory` on the console) |
| Curios-only keep inventory | Verified from bytecode + config, NOT tested in game (needs a player death) |
| Client mod loading | **UNTESTED.** No client was launched (rule: no GUI). Files sync into the Prism instance fine |
| G.L.A.S.S + Immersive Portals on the client | **Predicted crash, see the next section** |
| Airships (Sable sub-levels) going through portals | Untested (needs a player) |
| OneChunk on the server (dimensions, `/onechunk` commands, island create + reset, restart) | Tested, clean, 20 TPS in every dimension (section 11) |
| OneChunk gateway teleport (sneak + Eye of Ender on the pad) | Untested (needs a player); static check says it is compatible with Immersive Portals |

## 1. FIRST THING TO TEST: G.L.A.S.S vs Immersive Portals on the client

Both mods are in the pack. Static analysis of the two jars shows a hard clash:

- G.L.A.S.S `dev.imb11.mixins.LevelRendererMixin` and Immersive Portals
  `qouteall.imm_ptl.core.mixin.client.render.MixinLevelRenderer` both put a `@Redirect` on the
  exact same call: `LocalPlayer.getEyePosition(F)` inside `LevelRenderer.renderSky`.
- Neither annotation lowers `require`, and both mixin configs use `"defaultRequire": 1`.
- Mixin only lets one `@Redirect` win per call. The loser logs "@Redirect conflict. Skipping ..."
  and then fails its injection check, which is a fatal `InjectionError`. That is exactly how the
  official Immersive Portals crashed against Sable on this server (see
  `~/minecraft-packs/Portals-1.21.1/evidence/boot1-official-immersive-portals-6.0.7-CRASH.log`).
  LevelRenderer loads while the client starts, so expect a crash at startup.
- Other overlaps (GameRenderer.renderLevel, LevelRenderer.allChanged, ClientLevel.addEntity,
  ClientChunkCache.getChunk) are `@Inject` next to `@Inject`/`@Redirect`, which normally coexist.
- The G.L.A.S.S server-side mixins (ChunkMap, ServerChunkCache) applied fine on the server.

This is static evidence, not a crash log, so G.L.A.S.S was NOT dropped. It is marked as an
**optional mod, ticked by default** (`~/minecraft-packs/Portals-1.21.1/mods/glass-remastered.pw.toml`).
packwiz-installer shows a checkbox for it the first time the Prism instance syncs.

How to test: launch "Portals 1.21.1" in Prism, load a world. If it crashes and the crash report or
`latest.log` mentions `renderSky` / `getEyePosition` / `glass` / `imm_ptl`, untick G.L.A.S.S
(or run `~/go/bin/packwiz remove glass-remastered` in `~/minecraft-packs/Portals-1.21.1` so the
server drops it too). If you want to change your tick later, delete
`~/.local/share/PrismLauncher/instances/Portals 1.21.1/minecraft/packwiz.json` and launch again.

## 2. Playtest in Prism (client)

The instance already exists: `~/.local/share/PrismLauncher/instances/Portals 1.21.1`
(Minecraft 1.21.1, NeoForge 21.1.265, Java 21 from Prism, 4 GB max RAM).

Its pre-launch command syncs from the LOCAL pack, no GitHub needed:

```
"$INST_JAVA" -Djava.net.preferIPv4Stack=true -jar packwiz-installer-bootstrap.jar --bootstrap-no-update -s client "file:///home/jefno/minecraft-packs/Portals-1.21.1/pack.toml"
```

`--bootstrap-no-update` is there because the bootstrap's self-update hit a GitHub API 403
(rate limit) during setup. `packwiz-installer.jar` is already in the instance folder.
The mods were pre-synced into the instance (21 jars, including OneChunk, Pack Balance and TrueUUID). Edit the pack, run
`~/go/bin/packwiz refresh`, launch again, and the instance picks up the change.

When the pack moves to GitHub later, swap the `file:///...` URL for the raw `pack.toml` URL,
the same way the PSY instance does it.

## 3. Server

Folder: `~/minecraft-packs/Portals-1.21.1/server`. Not a systemd service, no firewall changes.
Hosting is not decided yet.

Start it:

```
~/minecraft-packs/Portals-1.21.1/server/start.sh
```

`~/minecraft-packs/Portals-1.21.1/server/start.sh` does two things:

1. Runs packwiz-installer with `-g -s server` against `PACK_URL` (default: the local
   `~/minecraft-packs/Portals-1.21.1/pack.toml`), so the server only gets server-side files.
   Set `SKIP_PACKWIZ=1` to skip that step, or `PACK_URL=https://...` once the pack is hosted.
2. Starts NeoForge 21.1.265 with `nogui` and the JVM flags from
   `~/minecraft-packs/Portals-1.21.1/server/user_jvm_args.txt`.

Java: NeoForge 21.1 needs **Java 21**. The system default on this machine is Java 27, so the
script defaults to Prism's runtime `~/.local/share/PrismLauncher/java/java-runtime-delta/bin/java`.
On a real host, install a Java 21 and run `JAVA=/path/to/java ./start.sh`.

Settings worth knowing:

- RAM: `-Xms8G -Xmx8G` (G1GC, Aikar-style flags). Drop both to `6G` on a host with under 10 GB RAM.
- `-Djava.net.preferIPv4Stack=true`: this machine has no working IPv6 route. Without it, the
  Immersive Portals "check mod info from the internet" call hung the server thread right after
  "Done" (`~/minecraft-packs/Portals-1.21.1/evidence/boot2-ipsable-HANG-on-ip-mod-info-fetch.log`).
  That internet check is also switched off in `~/minecraft-packs/Portals-1.21.1/config/immersive_portals.json`
  (`checkModInfoFromInternet` and `enableUpdateNotification` are false; the update notice would
  tell players to install the upstream build, which crashes with Sable).
  The packwiz sync step in `start.sh` (and the Prism pre-launch command) uses the same flag: on
  2026-11-09 the sync timed out on four Modrinth downloads without it
  (`~/minecraft-packs/Portals-1.21.1/evidence/boot14a-packwiz-sync-TIMEOUT-before-ipv4-fix.log`).
- `server.properties`: max 14 players, whitelist ON (add friends with `whitelist add <name>`),
  difficulty normal, view distance 10, simulation distance 8, `allow-flight=true` (airships
  would otherwise get players kicked), `max-tick-time=-1` (no watchdog kill during heavy
  Create/portal ticks), spawn protection 0, command blocks on, port 25565.
- `eula.txt` is set to true.
- The test world was deleted after the boot tests (it had force-loaded chunks). The first real
  start generates a fresh world with a random seed.

Port note: during testing another agent's NeoForge dev server
(`~/mc-mods/onechunk-neoforge/run`) was holding port 25565 on this machine, so the restart test ran
on port 25591. `server.properties` is back on 25565.

## 4. Mod list

**21 jars. Only the mods Jef asked for, plus the libraries those mods declare as required.**
The pack was first built on the full PSY mod list; on Jef's correction everything he did not ask
for was stripped out (see "Removed" below). The configs of removed mods were deleted too.

### Requested mods (17 jars)

| Mod | Version | Source |
| --- | --- | --- |
| Create | 6.0.10 (bundles Flywheel 1.0.6, Ponder, Registrate) | CurseForge |
| Create Aeronautics (bundled jar: Aeronautics, Simulated, Offroad) | 1.3.2 | Modrinth |
| Sable | 2.0.6 (bundles Sable Companion, Veil) | Modrinth |
| Relics | 0.12.11 (beta, newest) | Modrinth |
| Artifacts | 13.2.5, newest (bundles ExpandAbility) | Modrinth |
| More Relics | 1.7.7-forRelics-0.12.8-1.0 (beta, the build for Relics 0.12) | Modrinth |
| Reliquified Artifacts | 1.0.9 (beta; formerly rarcompat, mod id now `reliquified_artifacts`) | Modrinth |
| The Twilight Forest | 4.8.3345 (newest NeoForge 1.21.1 build on CurseForge) | CurseForge |
| KeepCuriosInventory | 1.0.0 | CurseForge |
| Curios API | 9.5.1 (the duplicate 9.0.15 jar from PSY was dropped) | CurseForge |
| Backpacked | 3.0.5 | CurseForge |
| Immersive Portals x Sable (IPSable) | 0.5.0 (fork of IP 6.0.7, see section 7) | GitHub release, hash-pinned |
| G.L.A.S.S Remastered | 1.0.0-experimental.sable (optional, default on, see section 1) | Modrinth |
| OneChunk (custom) | 1.0.0, jar shipped in `mods/` (see section 11) | this repo |
| When Dungeons Arise | 2.1.68, newest 1.21.1 NeoForge build. Declares only NeoForge, so no new dependency. Modrinth marks it server-only; it is set to both sides so singleplayer playtests get the dungeons too | Modrinth |
| Pack Balance (custom) | 1.0.0, jar shipped in `mods/` (see section 12). Requires only Create; Aeronautics, Simulated, Offroad, Sable and Curios are optional for it and all present | this repo |
| TrueUUID | 1.3.0, newest NeoForge 1.21.1 build. Both sides (its README: the same jar on client and server). Declares only NeoForge/Minecraft. See section 13 | Modrinth |

### Relics 0.12 decision (made by Jef)

Jef chose Relics 0.12.11 over keeping Reliquified Twilight Forest. RTF 0.5.3 is the newest RTF build
and it only works with Relics 0.10.x: it references 38 Relics classes that are gone in 0.11 and
0.12, and with Relics 0.12.11 mod loading fails with
`ClassNotFoundException: it.hurts.sskirillss.relics.init.EffectRegistry`
(`~/minecraft-packs/Portals-1.21.1/evidence/boot10-relics-0.12.11-with-RTF-0.5.3-CRASH.log`).
So RTF is removed; Twilight Forest itself stays. Branch `test/relics-0.12` was merged into `master`.

| Mod | Before | Now | Constraint |
| --- | --- | --- | --- |
| Relics | 0.10.7.8 | 0.12.11 (beta) | |
| Reliquified Artifacts | rarcompat 0.9.7 | 1.0.9 (beta) | needs Relics `[0.12.3,)` and Artifacts exactly `[13.2.5]` |
| More Relics | 1.7.7 | 1.7.7-forRelics-0.12.8-1.0 (beta) | pinned to Relics 0.12.8 on Modrinth; every Relics class it uses exists in 0.12.11 |
| Artifacts | 13.2.1 | 13.2.5 | newest |
| Reliquified Twilight Forest | 0.5.3 | removed | no build for Relics 0.11/0.12 |

The mod id change (`rarcompat` to `reliquified_artifacts`) would delete its items in an existing
world; there is no world yet, so it costs nothing now. Curios 9.5.1 and KeepCuriosInventory 1.0.0
are unchanged; KeepCuriosInventory only patches Curios' death-drop handler and applies cleanly.

### Libraries (4 jars) and why each one is there

Found by reading the `neoforge.mods.toml` of every kept jar (including the jars bundled inside
them) and following only `required` dependencies.

| Library | Version | Required by |
| --- | --- | --- |
| ShatterLib / OctoLib | 0.6.2 | Relics 0.12.11 and Reliquified Artifacts 1.0.9 (both declare `octolib` required) |
| Architectury API | 13.0.8 | OctoLib (declares `architectury` required) |
| Framework | 0.13.11 | Backpacked (declares `framework` required) |
| Cloth Config API | 15.0.140 | Immersive Portals. Its mods.toml does not declare it, but the code does need it: `IPConfig`, `IPModMain` and `IPGlobal` use Cloth's AutoConfig, and the Modrinth page lists it as required (upstream issue #21 is the `NoClassDefFoundError` you get without it). Artifacts also references Cloth for its config screen |

Requested mods that need nothing outside this list: Create, Sable, Artifacts, Twilight Forest,
Curios, KeepCuriosInventory, GLASS (Sable is optional for it and present), OneChunk.
More Relics declares only NeoForge/Minecraft; Modrinth lists Relics, Curios, OctoLib and
Architectury for it, and all four are in.

### Version changes compared to the PSY pack

| Mod | From | To | Why |
| --- | --- | --- | --- |
| NeoForge | 21.1.219 | 21.1.265 | G.L.A.S.S needs `[21.1.249,)`; every kept mod accepts 21.1.265 |
| Sable | 1.2.2 | 2.0.6 | G.L.A.S.S declares `sable [2.0.6,3.0.0)` |
| Create Aeronautics | 1.2.1 | 1.3.2 | 1.3.x is the line built for Sable 2.x |

### Removed

- Never wanted, or replaced: the duplicate Curios API Continuation 9.0.15; official Immersive Portals
  6.0.7 (crashes with Sable, replaced by IPSable); Relics: Sable Compat (patched a class that does not
  exist in Relics 0.10.7.8).
- Every Create addon (Jef: Create is too strong): Create Crafts & Additions, Create: Aquatic
  Ambitions, Create: Dragons Plus, Create: Enchantment Industry, Create Goggles, Create Jetpack,
  Create: Curios Jetpack & Backtank, Create: Oxidized, Create: Ultimate Factory, and the library only
  Create Jetpack needed (Kotlin for Forge).
- Everything else from the PSY pack that Jef did not ask for (even if harmless): Terralith, Sky
  Villages, Formations, Formations Overworld, Charm of Undying, Elytra Slot, Enchanted: Witchcraft,
  Iron Chests, Macaw's Bridges, Trade Cycling, Vanilla Backport, JEI, Xaero's Minimap, Xaero's World
  Map, Item Obliterator, YetAnotherConfigLib, FerriteCore, Lithium, ModernFix, the Baby Mobs resource
  pack, and the libraries only those needed: Caelus, GeckoLib, Modopedia, Necronomicon, Platform,
  Resourceful Lib, StateObserver.

Counts: 55 jars before the Create cleanup, 45 after it, 19 after the strip, 20 with When Dungeons Arise,
21 with Pack Balance,
**21 now** after the Relics 0.12 merge (-1 RTF) and TrueUUID (+1) (expected 21, actual 21 on the
server and in Prism). The strip itself was: expected 19, actual 19 on the
server and in the Prism instance). Evidence:
`~/minecraft-packs/Portals-1.21.1/evidence/boot9-minimal-19-mods-CLEAN.log`.

`~/go/bin/packwiz list` in `~/minecraft-packs/Portals-1.21.1` prints the live list.

## 5. Relics / Artifacts addons

The rule was "tasteful, not over the top": no gear packs that add dozens of overpowered items.

Picked:

- **More Relics** (now 1.7.7-forRelics-0.12.8-1.0). A curated set of extra relics in the same
  Relics system.
- **Reliquified Twilight Forest** was picked at first (boss-drop relics from Twilight Forest) and
  later removed: it has no build for Relics 0.12 (see section 4).

Looked at and rejected:

- Relics: Sable Compat: no-op on this Relics version (see Dropped).
- Create: Relics+ and Create: Relics Integration: Create addons (Jef removed all Create addons),
  and Relics Integration replaces relic loot with crafting lines.
- Compat Artifacts (100+ artifacts), L2 Artifacts (long RPG progression): too much.
- Artifacts crafting: makes artifacts craftable, kills the exploration reward.

## 6. Keep inventory: curios slots only

Rules: vanilla `keepInventory` stays **false**, so the main inventory, armor and offhand drop on
death. Items in Curios slots (Relics and Artifacts trinkets) are kept.

How it works (checked in the jars, not just the config):

- Curios 9.5.1 `CuriosEventHandler`, lambda inside `playerDrops`, reads
  `level.getGameRules().getBoolean(GameRules.RULE_KEEPINVENTORY)` and combines it with the
  `keepCurios` setting in `~/minecraft-packs/Portals-1.21.1/config/curios-server.toml`
  (`keepCurios = "DEFAULT"` means "follow keepInventory"). That code only handles the curios
  inventory map and adds curios to the drop list.
- KeepCuriosInventory 1.0.0 (`me.kall.keepcuriosinventory.mixin.CuriosEventHandlerMixin`) has a
  `@Redirect` on exactly that `GameRules.getBoolean` call and returns `true`. So Curios believes
  keepInventory is on for curios only. Vanilla's own inventory drop reads the real game rule and
  is not touched.
- Its second redirect (on `ItemStack.isEmpty()` in `handleDrops`) applies the blacklist in
  `~/minecraft-packs/Portals-1.21.1/config/keepcuriosinventory-common.toml`
  (`curiosBlacklist = []`, so nothing is forced to drop).
- The mixin is `required` with `defaultRequire 1`, and the server boots, so it applied.
- Server console check: `gamerule keepInventory` returned `false`.

Not tested in game (needs a player to die). Fallback if it ever breaks: set
`keepCurios = "ON"` in `~/minecraft-packs/Portals-1.21.1/config/curios-server.toml`, which makes
Curios keep its slots by itself.

Note: **Backpacked backpacks drop on death** (`keepOnDeath = false` in
`~/minecraft-packs/Portals-1.21.1/config/backpacked.backpack.toml`). Backpacked uses its own
equip slots, not Curios. That matches "curios only", but see Open decisions.

## 7. Immersive Portals compatibility findings

Sources: the NeoForge issue tracker (github.com/iPortalTeam/ImmersivePortalsModForNeo), the
mod's own incompatibility list (qouteall.fun/immptl_info/1.21.1.json), the jars, and boot logs.

- **Sable / Create Aeronautics: official IP does NOT work.** Reproduced on this server: Sable's
  `EntityMixin` and IP's `MixinEntity` both `@Redirect` entity collision; IP loses and crashes
  (`evidence/boot1-...-CRASH.log`). Upstream issue #64 is open, and upstream is no longer
  maintained (issue #73). Other reports: Sable and IP also clash on
  `Player.canPlayerFitWithinBlocksAndEntitiesWhen`.
  Fix used: **IPSable 0.5.0** (github.com/r2smith141/IPSable, Apache-2.0), a fork of IP 6.0.7
  made for Sable 2.0.3+, Aeronautics 1.3.0+ and Create 6.0.10. It boots cleanly here and creates
  its own dimension `ipl_sable:sublevels`, where all Sable sub-levels (airships) now live.
  Trade-offs: it is a pre-release from one developer; it moves airship storage into that
  dimension (worlds made with it may not load cleanly without it); its patched physics natives
  ship for Windows x86_64 only, so a Linux server falls back to stock Sable natives and loses
  "aperture contact clipping" for ships straddling a portal; one of its mixins targets a Sable
  class missing in 2.0.6 (`SubLevelSelector`, logged as not found, skipped); it logs an
  `[IPL-HEARTBEAT]` line every 5 seconds. Its open issues include ships losing collision after
  crossing dimensions (#27, #24). Other compat attempts (ImmersivePortalSableBridge: "unsuitable
  for Sable 2.0"; sableipcompat, ImmersivePortalsNSableCompat: no releases) were not usable.
- **Sodium / Embeddium:** not in the pack. Good, because IP has open
  crash reports with Embeddium (#61) and Sodium 0.8.12+ (#74, #67), and Sable refuses Sodium older
  than 0.8.12-alpha.2. Do not add either without testing. G.L.A.S.S has its own Sodium compat.
- **Create / Flywheel:** upstream lists Create as "sometimes some contraptions will be invisible"
  (issue #38, visual). IP's Flywheel compat mixins target Flywheel 0.6 classes
  (`com.jozufozu.flywheel...`) that do not exist in Create 6's Flywheel 1.0, so they are skipped
  (logged as "not found"). Expect moving Create parts to sometimes not render through portals.
- **Twilight Forest:** upstream lists "the Twilight Forest map sometimes doesn't work" (the magic
  map item). Twilight portals stay normal teleport portals.
- **Xaero, ModernFix, Lithium, FerriteCore:** were checked while they were in the pack (no reports,
  all loaded with IPSable). They have since been removed.
- **G.L.A.S.S:** see section 1.

## 8. Evidence

All in `~/minecraft-packs/Portals-1.21.1/evidence/` (ANSI colours stripped):

- `boot1-official-immersive-portals-6.0.7-CRASH.log`: official IP + Sable 2.0.6. Key line:
  `Critical injection failure: Redirector redirectHandleCollisions(...) in imm_ptl.mixins.json:common.collision.MixinEntity ... failed injection check, (0/1) succeeded.`
- `boot2-ipsable-HANG-on-ip-mod-info-fetch.log`: IPSable reached "Done" but the server thread
  hung in `IPModInfoChecking.fetchImmPtlInfoFromInternet` (IPv6). Fixed as described in section 3.
- `boot3-CLEAN-done-twilight-forest-worldgen.log`: clean boot and world generation. Key lines:
  - `Done (7.356s)! For help, type "help"`
  - `Gamerule keepInventory is currently set to: false`
  - `Marked 256 chunks in Twilight Forest from [-8, -8] to [7, 7] to be force loaded`
  - `The nearest twilightforest:hedge_maze is at [-295, ~, -487]`
  - `The nearest twilightforest:enchanted_forest is at [-1120, 118, 352]`
  - `Marked 64 chunks in The Nether ...`, `Marked 64 chunks in The End ...`
  - `Twilight Forest: 20.000 TPS (1.389 ms/tick)`, `Overall: 20.000 TPS (3.042 ms/tick)`
  - clean `stop`: `All dimensions are saved`, exit 0
- `boot4-restart-PORT-CONFLICT-with-other-dev-server.log`: restart failed only because another
  agent's dev server held port 25565 (`FAILED TO BIND TO PORT`). Not a pack problem.
- `boot5-CLEAN-restart-existing-world.log` (+ `boot5-latest.log`): restart on the existing world
  with the full `start.sh` (packwiz sync included): `Done (1.639s)!`, 20 TPS,
  `The nearest twilightforest:quest_grove is at [24, ~, -1287]`, clean stop.
- `boot8-no-create-addons-CLEAN.log`: after removing the Create addons (45 jars): `Done (8.984s)!`,
  20 TPS in all dimensions.
- `boot9-minimal-19-mods-CLEAN.log`: the current 19-jar pack. Key lines:
  - the packwiz sync deletes every removed jar and config, `Finished successfully!`
  - `Done (4.342s)!`
  - `Marked 256 chunks in Twilight Forest ...`, `The nearest twilightforest:hedge_maze is at [3080, ~, -3063]`
  - `Marked 64 chunks in Nether ...`, `Marked 64 chunks in The End ...`
  - `Island created at chunk (200, 200)` and `Initial fill ... done` (OneChunk)
  - `Gamerule keepInventory is currently set to: false`
  - 20.000 TPS in Overworld, Nether, End, Twilight Forest, `ipl_sable:sublevels`,
    `onechunk:onechunk`, `onechunk:source`; `Overall: 20.000 TPS (2.807 ms/tick)`
  - one `[IPL-WATCHDOG] SERVER THREAD STALLED ~8s` while the test force-generated 384 chunks in
    a single tick burst (same moment as `Can't keep up! ... 8998ms`); normal play does not do that
  - `All dimensions are saved`, exit 0
- `boot10-relics-0.12.11-with-RTF-0.5.3-CRASH.log` (+ `boot10-crash-report.txt`): newest Relics set
  with Reliquified Twilight Forest 0.5.3. Mod loading fails (see section 4).
- `boot11-relics-0.12.11-WITHOUT-RTF-clean.log`: the same set without Reliquified Twilight Forest
  (branch `test/relics-0.12`): `Done (5.612s)!`, `Overall: 20.000 TPS`.
- `boot12-artifacts-13.2.5-WDA-2.1.68-CLEAN.log`: `master` with 20 jars. Key lines:
  `Done (5.093s)!`, `The nearest dungeons_arise:heavenly_rider is at [1616, ~, -784]`,
  `dungeons_arise:bandit_towers is at [2416, ~, -752]`, `dungeons_arise:illager_windmill is at
  [-1584, ~, 1632]`, 256 Twilight Forest chunks, `hedge_maze` located, OneChunk island created and
  filled, `keepInventory ... false`, 20.000 TPS in all 7 dimensions, clean stop. One harmless WDA
  line: `Couldn't load advancements: [dungeons_arise:find_thornborn_towers, dungeons_arise:find_fishing_hut]`
  (upstream data issue, only two "find this structure" advancements).
- `boot14a-packwiz-sync-TIMEOUT-before-ipv4-fix.log`: the sync step timed out on four Modrinth
  downloads; fixed by adding `-Djava.net.preferIPv4Stack=true` to the sync call in `start.sh`.
- `boot14-relics-0.12.11-WDA-packbalance-trueuuid-CLEAN.log` (+ `boot14-pack_balance_recipe_dump.txt`):
  the current `master`, 21 jars. Key lines:
  - `Finished successfully!` (sync), `TrueUUID NeoForge adapter loaded`, `Done (5.651s)!`
  - `Marked 64 chunks in Twilight Forest ...`, `The nearest dungeons_arise:heavenly_rider is at [-1552, ~, 1616]`
  - `Island created at chunk (200, 200)`, `Initial fill ... done` (OneChunk)
  - `/packbalance dumprecipes`: crimsite/ochrum crushing and redstone filling still absent, gravel
    splashing still flint only
  - 20.000 TPS in all 7 dimensions, `Overall: 20.000 TPS (1.752 ms/tick)`, clean stop
  - zero mixin or injection errors. New harmless warnings: `Ignoring unknown attribute
    'forge:entity_gravity'` (a mob NBT key from the Forge era) and Reliquified Artifacts' tag
    warnings (same as rarcompat's before)
- `packwiz-sync.log`: server-side sync, `Finished successfully!`.
- `installer-run.log`: NeoForge 21.1.265 server install, `The server installed successfully`.

## 9. Open decisions for Jef

1. **TrueUUID needs `online-mode=false`** (section 13). Not changed yet.
2. **G.L.A.S.S vs Immersive Portals** (section 1): test it first. If it crashes, which one goes?
   Portals were a hard requirement, so the default answer is "untick G.L.A.S.S".
3. **IPSable instead of official Immersive Portals.** Accept a one-person pre-release fork, or
   give up see-through portals? There is no maintained official build that works with Sable.
4. **Backpacks drop on death.** Flip `keepOnDeath = true` in
   `~/minecraft-packs/Portals-1.21.1/config/backpacked.backpack.toml` if backpacks should count
   as "slots that survive death".
5. **Hosting:** which machine, Java 21 install, port forward/firewall, systemd or not. On a Linux
   host IPSable runs without its patched physics natives.
6. **Optional extra:** the "Immersive Portals & Twilight Forest Compatibility" datapack on Modrinth
   makes Twilight portals see-through. Not added, untested.
7. **Publishing:** this folder is a local git repo only. Pushing it to GitHub (like the other
   packs) and pointing the Prism pre-launch URL at the raw `pack.toml` is up to Jef.

## 10. Maintaining the pack

Run these in `~/minecraft-packs/Portals-1.21.1`:

- `~/go/bin/packwiz refresh` after editing any file in `mods/`, `config/` or `resourcepacks/`.
- `~/go/bin/packwiz mr add <slug>` / `~/go/bin/packwiz cf add <slug>` to add a mod. Answer "n" to
  the dependency prompt if the dependency is already in the pack from the other site (mixed
  CurseForge and Modrinth sources are not de-duplicated).
- `~/go/bin/packwiz update <name>` to update. Do NOT update Immersive Portals back to the
  official build (crashes with Sable).
- `~/minecraft-packs/Portals-1.21.1/.packwizignore` keeps `server/`, `evidence/` and this README
  out of the pack, so clients never download them.

## 11. OneChunk (custom mod)

Source: `~/mc-mods/onechunk-neoforge` (README: `~/mc-mods/onechunk-neoforge/README.md`).
It adds the void dimension `onechunk:onechunk` and a hidden source dimension `onechunk:source`.
Way in: a flat 3x3 pad of crying obsidian, sneak + right-click it with an Eye of Ender.
No blocks, items or mixins; everything runs on the server, but it is shipped on both sides
(the client needs the dimension type and datapack registrations).

### Re-syncing a new OneChunk build (one step)

The mod is still being changed (grace-area feature). After a new jar lands in
`~/mc-mods/onechunk-neoforge/dist/`, run:

```
~/minecraft-packs/Portals-1.21.1/sync-onechunk.sh
```

It deletes the old `onechunk-neoforge-*.jar` from `~/minecraft-packs/Portals-1.21.1/mods/`,
copies the newest jar from `dist/` (or the path you pass as the first argument), runs
`~/go/bin/packwiz refresh` and prints the git commit command. Prism picks the new jar up on the
next launch, the server on the next `start.sh`. Re-test the server afterwards (section 8 shows how
the console was driven).

### Integration test (server, headless, full pack)

Evidence: `~/minecraft-packs/Portals-1.21.1/evidence/boot6-onechunk-CLEAN-island-link-reset.log`
and `~/minecraft-packs/Portals-1.21.1/evidence/boot7-onechunk-CLEAN-restart-persistence.log`.
Run on port 25591 because another agent's dev server used 25565 earlier; `server.properties` is
back on 25565, and the test world was deleted.

- `Done (11.279s)!` with OneChunk loaded (`OneChunk 1.0.0 (onechunk)`).
- No `@Redirect conflict`, `InjectionError` or registry errors in the log. The only overwrite
  warnings are ModernFix vs Lithium, which exist without OneChunk too.
- Both dimensions register with every mod that hooks levels: IP `Global portal storage
  initialized onechunk:onechunk` / `onechunk:source`, Sable creates a physics pipeline for both,
  IP's dimension id map gets `onechunk:onechunk -> 2`, `onechunk:source -> 5`.
- `/onechunk status` from the console: `Islands: 0, cycles done: 0`, `Next reset in 888 s`.
- Built a pad with `fill`, then `/onechunk link minecraft:overworld 200 69 200`:
  `Island created at chunk (200, 200)`, `Initial fill ... done ... copy 11 ticks / 548 ms wall`.
- `/onechunk reset`: `Cycle #1 complete: 1 islands replaced`.
- `neoforge tps`: 20.000 TPS in Overworld, Nether, End, Twilight Forest, `ipl_sable:sublevels`,
  `onechunk:onechunk` and `onechunk:source`.
- Restart: `Wiped hidden source dimension data`, `Loaded 1 islands, 1 cycles so far`,
  `Done (2.212s)!`, 20 TPS everywhere, clean stop.

### Immersive Portals / IPSable checks

- Dimension handling: IPSable registers its portal storage, dimension id and Sable pipeline for
  the OneChunk dimensions without errors. `ipl_sable:sublevels` keeps loading and ticking next to
  them. OneChunk only links Overworld and OneChunk, so it never targets `ipl_sable:sublevels`.
- Teleport path: OneChunk teleports with `ServerPlayer.teleportTo(ServerLevel, x, y, z, yaw, pitch)`.
  IP has an `@Inject` on that method (`MixinServerPlayerEntity_MA.onTeleported`) that only runs
  its "before dimension travel" bookkeeping (chunk tracker cleanup, custom portal gen hook) and
  does not cancel the teleport. This is the same path vanilla `/tp` uses with IP, so it is
  compatible by design. Not exercised with a real player.
- Portal frames: no mod in the pack ships an Immersive Portals custom portal generation datapack,
  so nothing else claims a crying obsidian frame.
- Not tested: a player walking through a gateway, an airship near an island at reset time, and
  `coordinate_scale 0.0625` together with IP's "adaptive" nether portal mode (the OneChunk
  dimension is not a Nether-portal target, so this should not matter).

## 12. Pack Balance (custom mod)

Source: `~/mc-mods/pack-balance-neoforge`. Mod id `pack_balance`, both sides, jar shipped in
`~/minecraft-packs/Portals-1.21.1/mods/` like OneChunk. Config defaults are NOT changed by the pack
(the server writes `server/config/pack_balance-common.toml` with the mod's own defaults).

What it does:
- Removes or strips Create recipes that make iron, gold, redstone, lapis, diamond, netherite or
  emerald out of other materials (for example crushing crimsite or ochrum, filling redstone,
  splashing gravel into iron nuggets). Processing the actual ores stays.
- Caps drills at 25 per contraption or ship (Create contraptions, Simulated/Aeronautics assembly,
  Sable sub-levels).
- Caps the Artifacts Crystal Heart at 1 worn.

Re-sync after a new build (one step):

```
~/minecraft-packs/Portals-1.21.1/sync-pack-balance.sh
```

Same behaviour as `sync-onechunk.sh`: deletes the old `pack_balance-neoforge-*.jar` from `mods/`,
copies the newest one from `~/mc-mods/pack-balance-neoforge/dist/` (or the path you pass),
refreshes the index and prints the commit command.

### Test with the full pack and Artifacts 13.2.5

The mod was built and tested against Artifacts 13.2.1; the pack has 13.2.5. Evidence:
`~/minecraft-packs/Portals-1.21.1/evidence/boot13-pack-balance-artifacts-13.2.5-CLEAN.log` and the
recipe dump `~/minecraft-packs/Portals-1.21.1/evidence/boot13-pack_balance_recipe_dump.txt`.

- `[PackBalance] loaded: sable=true simulated=true curios=true`
- `Done (7.615s)!`, no mixin conflicts or injection errors (its mixins into Create, Sable and
  Simulated all applied; they are `required`).
- `[PackBalance] recipes loaded: 3607 total, 1624 create:*, 6 pack_balance:* (stripped variants);
  blocked materials: iron gold redstone lapis diamond netherite emerald`
- `/packbalance dumprecipes` wrote 3607 recipes. In the dump:
  - `create:crushing/crimsite`, `create:crushing/ochrum` and `create:filling/redstone` are absent.
  - `create:splashing/gravel` is absent; the only gravel splashing recipe is
    `pack_balance:create/splashing/gravel/without_iron  create:splashing  minecraft:flint`.
- 20.000 TPS in all 7 dimensions (`Overall: 20.000 TPS (3.286 ms/tick)`), clean stop.
- Crystal Heart cap and Artifacts 13.2.5: Pack Balance does not use any Artifacts class. It only
  matches the item id `artifacts:crystal_heart` through the Curios API, and that item is still
  registered in 13.2.5 (`artifacts/registry/ModItems`). The cap itself needs a player to test
  (its test commands are off by default and were left off).
- Not tested in game: the drill cap (needs a contraption or ship) and the heart cap (needs a player).

## 13. TrueUUID (account verification for offline-mode servers)

Modrinth `trueuuid`, version 1.3.0+neoforge-1.21.1 (`trueuuid-1.3.0-neoforge-1.21.1.jar`).
Hard dependencies: none besides NeoForge `[21.1.213,)` and Minecraft `[1.21.1,1.21.2)`. One mixin
config (`trueuuid.mixins.json`), applied cleanly.

Side: **both**. Its README says the same TrueUUID jar must be on the client and the server (the
client answers the server's login challenge with its own Mojang session, so the access token never
leaves the player's PC). It shows a small premium/offline badge in the HUD.

**Server setting it needs: `online-mode=false`** in
`~/minecraft-packs/Portals-1.21.1/server/server.properties`. The pack still has
`online-mode=true`: it was not changed (Jef decides). Things to know when switching:

- With `online-mode=true` vanilla already verifies everyone, so TrueUUID only loads
  (`TrueUUID NeoForge adapter loaded`) and does nothing visible.
- With `online-mode=false`, premium players keep their real UUID and skin through TrueUUID.
  Defaults in `server/config/trueuuid-common.toml` (generated by the mod, not changed):
  `allowOfflineOnFailure = true` (players without a Mojang session may still join, as offline),
  `knownPremiumDenyOffline = true` and `allowOfflineForUnknownOnly = true` (a name that once logged
  in as premium can never be reused offline). Set `allowOfflineOnFailure = false` to admit only
  verified premium accounts.
- The whitelist is on (`white-list=true`). Offline players get offline-mode UUIDs, so whitelist
  entries for them must match those; verified premium players keep their normal UUID.
- `enforce-secure-profile=true` is the vanilla default; check chat signing works with offline
  mode in a real test, and set it to `false` if offline players get kicked for chat.
- Known verified names are stored in `server/trueuuid-registry.json`.
- Not tested: an actual login (needs a client).
