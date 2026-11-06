# Portals 1.21.1

Minecraft **1.21.1**, NeoForge **21.1.265**. A packwiz pack for Jef and about 12 friends,
plus a dedicated server in `~/minecraft-packs/Portals-1.21.1/server`.

It starts from Jef's pack "Psychokring return of the PSY" (Prism instance
`~/.local/share/PrismLauncher/instances/Psychokring return of the PSY-1.0.0`, repo
github.com/JefNotelteirs/Psychokring_return_of_the_PSY). Its `.pw.toml` files and configs were
copied, not re-resolved. That instance and that repo were not touched.

Theme: Create + Create Aeronautics airships, see-through Immersive Portals, Relics and Artifacts
trinkets, Twilight Forest, Backpacked, and the custom OneChunk void dimension. Curios/relic slots
survive death, nothing else does.

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
(Minecraft 1.21.1, NeoForge 21.1.265, Java 21 from Prism, 8 GB max RAM).

Its pre-launch command syncs from the LOCAL pack, no GitHub needed:

```
"$INST_JAVA" -jar packwiz-installer-bootstrap.jar --bootstrap-no-update -s client "file:///home/jefno/minecraft-packs/Portals-1.21.1/pack.toml"
```

`--bootstrap-no-update` is there because the bootstrap's self-update hit a GitHub API 403
(rate limit) during setup. `packwiz-installer.jar` is already in the instance folder.
The mods were pre-synced into the instance (55 jars, including OneChunk). Edit the pack, run
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
- `server.properties`: max 14 players, whitelist ON (add friends with `whitelist add <name>`),
  difficulty normal, view distance 10, simulation distance 8, `allow-flight=true` (jetpacks and
  airships would otherwise get players kicked), `max-tick-time=-1` (no watchdog kill during heavy
  Create/portal ticks), spawn protection 0, command blocks on, port 25565.
- `eula.txt` is set to true.
- The test world was deleted after the boot tests (it had force-loaded chunks). The first real
  start generates a fresh world with a random seed.

Port note: during testing another agent's NeoForge dev server
(`~/mc-mods/onechunk-neoforge/run`) was holding port 25565 on this machine, so the restart test ran
on port 25591. `server.properties` is back on 25565.

## 4. Mod list

55 jars. Everything from the PSY pack is kept unless listed below.

### Added

| Mod | Why |
| --- | --- |
| Immersive Portals x Sable (IPSable) 0.5.0 (fork of Immersive Portals 6.0.7) | See-through portals. The official build crashes with Sable, see section 6. GitHub release, hash-pinned in `mods/immersive-portals-ipsable.pw.toml` |
| Cloth Config API 15.0.140 | Required by Immersive Portals on the client |
| G.L.A.S.S Remastered 1.0.0-experimental.sable (NeoForge build) | Official NeoForge build from the author (Modrinth `glass-remastered`, version `hSDwnXJr`). Optional, default on. See section 1 |
| Reliquified Twilight Forest 0.5.3 | Relics addon, see section 5 |
| More Relics 1.7.7 | Relics addon, see section 5 |
| OneChunk 1.0.0 (custom, `mods/onechunk-neoforge-1.21.1-1.0.0.jar`) | Void dimension with resetting one-chunk islands. Shipped as a jar in the repo, both sides, like ChaosServer's Soulbound. See section 11 |

### Changed

| Mod | From | To | Why |
| --- | --- | --- | --- |
| NeoForge | 21.1.219 | 21.1.265 | G.L.A.S.S needs `[21.1.249,)`. 21.1.265 is the newest 21.1 on maven. Every mod's `neoforge` range was re-checked and accepts it |
| Sable | 1.2.2 | 2.0.6 | G.L.A.S.S declares `sable [2.0.6,3.0.0)`, which NeoForge enforces when Sable is present |
| Create Aeronautics (bundles Simulated + Offroad) | 1.2.1 | 1.3.2 | Aeronautics 1.2.x is built for Sable 1.x; 1.3.2 needs Sable `[2.0.0,3.0.0)` |
| Create: Oxidized 0.1.3 | CurseForge | Modrinth | Same file (same sha1). CurseForge blocks API downloads of it, so packwiz-installer could not fetch it headless |

### Dropped

| Mod | Why |
| --- | --- |
| Curios API Continuation 9.0.15 | Duplicate Curios jar (the known bug). Kept official Curios 9.5.1, which every Curios user in the pack accepts (Relics, rarcompat and Reliquified Twilight Forest need `>= 9.3.1`) |
| Immersive Portals for (Neo)Forge 6.0.7 (official) | Crashes at startup with Sable: `Critical injection failure: Redirector redirectHandleCollisions ... failed injection check`. Replaced by IPSable, so portals are still in |
| Relics: Sable Compat 1.0.0 | Tried, then removed. It patches `ChorusStaffItem`, which does not exist in Relics 0.10.7.8 (log: "@Mixin target ... ChorusStaffItem was not found"). It did nothing |

Create Aeronautics and Immersive Portals are both in. Nothing else was dropped.

### Full list (name, file, source)

Libraries: Architectury API 13.0.8, ShatterLib/OctoLib 0.6.2, Caelus API 7.0.1, Cloth Config 15.0.140,
Framework 0.13.11, GeckoLib 4.8.4, Kotlin for Forge 5.11.0, Necronomicon API 1.6.0, Platform 1.3.3,
Resourceful Lib 3.0.12, StateObserver 1.6.4, YetAnotherConfigLib 3.8.2, Curios API 9.5.1.

Create: Create 6.0.10, Create Aeronautics 1.3.2 (with Simulated and Offroad), Sable 2.0.6
(with Sable Companion and Veil), Create Crafts & Additions 1.5.10, Create: Aquatic Ambitions 2.0.2,
Create: Dragons Plus 1.10.0b, Create: Enchantment Industry 2.3.1, Create Goggles 6.1.1,
Create Jetpack 5.1.2, Create: Curios Jetpack & Backtank 1.2.0, Create: Oxidized 0.1.3,
Create: Ultimate Factory 2.2.4.

Trinkets: Relics 0.10.7.8, Artifacts 13.2.1, Reliquified Artifacts (rarcompat) 0.9.7,
Reliquified Twilight Forest 0.5.3, More Relics 1.7.7, Charm of Undying 9.1.0, Elytra Slot 9.0.2,
KeepCuriosInventory 1.0.0.

World: The Twilight Forest 4.8.3345, Terralith 2.5.8, Formations 1.0.4 + Formations Overworld 1.0.5,
Sky Villages 1.0.6, Vanilla Backport 1.1.7.4.

Other: Immersive Portals x Sable 0.5.0, G.L.A.S.S Remastered 1.0.0-experimental.sable,
Backpacked 3.0.5, Enchanted: Witchcraft 4.2.7, Modopedia 1.1.11, Iron Chests 16.0.7,
Macaw's Bridges 3.1.2, Trade Cycling 1.0.18, Item Obliterator 2.3.0, JEI 19.27.0.336,
Xaero's Minimap 25.3.13, Xaero's World Map 1.40.16, ModernFix 5.27.7, FerriteCore 7.0.3,
Lithium 0.15.3. Resource pack: Baby Mobs.

`~/go/bin/packwiz list` in `~/minecraft-packs/Portals-1.21.1` prints the live list.

## 5. Relics / Artifacts addons (picked 2)

The rule was "tasteful, not over the top": no gear packs that add dozens of overpowered items.

Picked:

- **Reliquified Twilight Forest 0.5.3**. Adds a few
  relics that drop from Twilight Forest bosses and copy one ability of that boss. Gated behind
  boss fights, ties two pillars of the pack together, uses the normal Relics levelling.
- **More Relics 1.7.7**. A curated set of extra relics in the same Relics system. The 1.7.7
  release is the one built for Relics 0.10.7.8 (the version in this pack); the newer beta line is
  for Relics 0.12.8.

Looked at and rejected:

- Relics: Sable Compat: no-op on this Relics version (see Dropped).
- Create: Relics+ and Create: Relics Integration: their Modrinth versions require a newer Relics
  build than 0.10.7.8, and Relics Integration replaces relic loot with crafting lines.
- Compat Artifacts (100+ artifacts), L2 Artifacts (long RPG progression): too much.
- Artifacts crafting: makes artifacts craftable, kills the exploration reward.

## 6. Keep inventory: curios slots only

Rules: vanilla `keepInventory` stays **false**, so the main inventory, armor and offhand drop on
death. Items in Curios slots (Relics, Artifacts, charms, elytra slot, jetpack curio) are kept.

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
- **Sodium / Embeddium:** not in the pack (the PSY pack has neither). Good, because IP has open
  crash reports with Embeddium (#61) and Sodium 0.8.12+ (#74, #67), and Sable refuses Sodium older
  than 0.8.12-alpha.2. Do not add either without testing. G.L.A.S.S has its own Sodium compat.
- **Create / Flywheel:** upstream lists Create as "sometimes some contraptions will be invisible"
  (issue #38, visual). IP's Flywheel compat mixins target Flywheel 0.6 classes
  (`com.jozufozu.flywheel...`) that do not exist in Create 6's Flywheel 1.0, so they are skipped
  (logged as "not found"). Expect moving Create parts to sometimes not render through portals.
- **Twilight Forest:** upstream lists "the Twilight Forest map sometimes doesn't work" (the magic
  map item). Twilight portals stay normal teleport portals.
- **Xaero's Minimap / World Map:** no reports in the IP issue tracker or incompatibility list.
  Untested.
- **ModernFix, Lithium, FerriteCore:** no reports; all three load with IPSable on the server.
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
- `packwiz-sync.log`: server-side sync, `Finished successfully!`.
- `installer-run.log`: NeoForge 21.1.265 server install, `The server installed successfully`.

## 9. Open decisions for Jef

1. **G.L.A.S.S vs Immersive Portals** (section 1): test it first. If it crashes, which one goes?
   Portals were a hard requirement, so the default answer is "untick G.L.A.S.S".
2. **IPSable instead of official Immersive Portals.** Accept a one-person pre-release fork, or
   give up see-through portals? There is no maintained official build that works with Sable.
3. **Backpacks drop on death.** Flip `keepOnDeath = true` in
   `~/minecraft-packs/Portals-1.21.1/config/backpacked.backpack.toml` if backpacks should count
   as "slots that survive death".
4. **Hosting:** which machine, Java 21 install, port forward/firewall, systemd or not. On a Linux
   host IPSable runs without its patched physics natives.
5. **Optional extra:** the "Immersive Portals & Twilight Forest Compatibility" datapack on Modrinth
   makes Twilight portals see-through. Not added, untested.
6. **Publishing:** this folder is a local git repo only. Pushing it to GitHub (like the other
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
