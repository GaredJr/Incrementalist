# Incrementalist

Sticker Street Tycoon is a Rojo-based Roblox incremental game prototype focused on an alpha-ready loop:
manual Hype collection, printable sticker families, zone unlocks, daily objectives, collection bonuses,
Reprint prestige, offline progress, and automation toggles.

## What Is In The Repo

- `default.project.json`: Rojo project mapping.
- `src/ReplicatedStorage/Shared`: shared configs, formulas, payload names, player schema, and pure utility tests.
- `src/ServerScriptService`: runtime bootstrap plus analytics, data, economy, zone, upgrade, prestige, quest, settings, session, and collection services.
- `src/StarterPlayer/StarterPlayerScripts`: client UI, camera/input control, and lightweight feedback effects.
- `src/Workspace/Map/Zones.model.json`: authored zone folders and anchor parts used by the world bootstrap.

## Alpha Features Implemented

- Server-authoritative economy mutations and remote validation.
- `PlayerData` v3 schema with migration/backfill support for zones, dailies, collection progress, and tutorial state.
- Two zones with authored map anchors, unlock flow, active-zone production multipliers, and camera switching.
- Three sticker families with four tiers each, printable base stickers, merge progression, and collection-book tracking.
- Six standard upgrades, four prestige upgrades, and deterministic Auto Buy ordering.
- Auto Collect, Auto Merge, Auto Buy, and Reduced Motion toggles.
- Permanent starter quests plus a three-slot UTC daily board.
- Server-driven onboarding, recommended next actions, toast notifications, and a first-Reprint milestone card.
- Reprint prestige with persistent Ink upgrades and collection progress.
- Offline reward payout with an 8-hour base cap plus collection and prestige modifiers.
- Shared tests covering migration, formulas, automation gating, collections, and daily board generation.

## Local Workflow

1. Open a Roblox place in Studio.
2. Run your local `rojo serve` or `rojo build default.project.json -o out.rbxlx`.
3. Connect the Studio Rojo plugin to the running server, or open the built place file.
4. Play in Studio and use the generated UI to collect Hype, print sticker copies, merge up families, unlock Neon Alley, finish dailies, and Reprint.
5. Sanity-check startup: `StarterGui > GameUI` exists, `StarterPlayerScripts > Main` runs, the loading shell appears immediately, and the first snapshot replaces it without a blank screen.

## Notes

- The top-level HUD, tabs, pages, templates, and loading/error shells are authored in `src/StarterGui`; the client binds data into those templates at runtime.
- The server still creates world/remotes fallbacks if authored map anchors are missing in the place.
- Shared specs live under `src/ReplicatedStorage/Shared/Tests` for future TestEZ/Studio execution.
