# Creative & Fun 2D Roblox Incremental Game Plan (Rojo-Based)

## 1) Game Concept: **"Sticker Street Tycoon"**
A colorful 2D-feeling incremental game where players collect, merge, and evolve magical stickers that produce "Hype" over time.

- **Core fantasy:** Build the coolest sticker board in town.
- **Tone:** Playful, collectible, meme-friendly, highly visual.
- **2D approach in Roblox:** Top-down board gameplay with billboard/UI-heavy presentation and flat sprite-style art.

---

## 2) Core Gameplay Loop (Simple + Addictive)
1. **Tap/Collect** starter stickers to generate Hype.
2. **Buy upgrades** that automate Hype generation.
3. **Unlock new sticker zones** with better multipliers.
4. **Merge/evolve stickers** into rare variants.
5. **Prestige ("Reprint")** to reset progress for permanent Ink bonuses.
6. Repeat with faster growth and new meta goals.

Design goals:
- First upgrade in <30 seconds.
- First automation in <2 minutes.
- First prestige in ~15–25 minutes.

---

## 3) Progression & Economy Design

### Currencies
- **Hype (soft currency):** Main spend currency.
- **Ink Shards (prestige):** Earned after Reprint, used for permanent upgrades.
- **Sparkles (event/limited):** Optional seasonal currency.

### Upgrade Types
- **Production upgrades:** +Hype/sec per sticker rarity.
- **Multiplier upgrades:** Global boosts, combo boosts, idle gains.
- **Automation upgrades:** Auto-collect, auto-merge, auto-buy toggles.
- **Quality-of-life upgrades:** Better UI sorting, larger inventory caps.

### Prestige System (Reprint)
- Reset stickers + upgrades.
- Grant Ink Shards based on lifetime Hype.
- Unlock prestige tree (branching upgrades):
  - Speed branch
  - Rarity branch
  - Offline earnings branch

### Mid/Endgame
- **Collections book:** Fill sticker sets for permanent buffs.
- **Challenge runs:** "No merge", "No auto-buy", etc. for unique badges and multipliers.
- **Zones/worlds:** Neon Alley, Arcade Roof, Cosmic Billboard.

---

## 4) 2D Presentation Strategy in Roblox
Use Roblox as a 3D platform while presenting a 2D game feel:
- Fixed camera angle and constrained movement.
- Flat planes/parts with decals/images as sprites.
- UI-first board with drag/drop sticker slots.
- Tween-heavy feedback (pop, squash, glow bursts).
- Layered parallax backgrounds in ScreenGui.

---

## 5) Technical Plan Using Rojo

### Recommended Project Structure

```text
.
├── default.project.json
├── rojo.toml (optional, if using newer workflows)
├── src
│   ├── ReplicatedStorage
│   │   ├── Shared
│   │   │   ├── Config
│   │   │   │   ├── EconomyConfig.lua
│   │   │   │   ├── StickerConfig.lua
│   │   │   │   └── PrestigeConfig.lua
│   │   │   ├── Types
│   │   │   └── Util
│   │   ├── Remotes
│   │   │   ├── RequestCollect
│   │   │   ├── RequestBuyUpgrade
│   │   │   └── RequestReprint
│   │   └── Assets
│   ├── ServerScriptService
│   │   ├── Services
│   │   │   ├── DataService.lua
│   │   │   ├── EconomyService.lua
│   │   │   ├── UpgradeService.lua
│   │   │   ├── PrestigeService.lua
│   │   │   └── SessionService.lua
│   │   └── Main.server.lua
│   ├── StarterPlayer
│   │   └── StarterPlayerScripts
│   │       ├── Controllers
│   │       │   ├── UIController.client.lua
│   │       │   ├── InputController.client.lua
│   │       │   └── FXController.client.lua
│   │       └── Main.client.lua
│   └── StarterGui
│       └── GameUI
└── packages (if using Wally)
```

### Rojo Workflow
1. Create place file in Roblox Studio.
2. Initialize Rojo project (`default.project.json`).
3. Run `rojo serve` and connect from Studio plugin.
4. Keep all game logic in `src/` and sync continuously.
5. Use version control for every config/gameplay change.

### Optional Tooling
- **Wally** for package management.
- **Selene + StyLua** for lint/format.
- **TestEZ** for unit tests on pure Lua modules.

---

## 6) Data Model & Save Strategy

### Player Data Shape (example)
- `hype: number`
- `lifetimeHype: number`
- `inkShards: number`
- `ownedStickers: { [stickerId] = count }`
- `upgrades: { [upgradeId] = level }`
- `prestigeCount: number`
- `settings: { autoMerge: boolean, autoBuy: boolean }`
- `lastOnlineUnix: number`

### Save/Load Principles
- Use ProfileService/DataStore abstraction.
- Autosave every 60–120 seconds.
- Save on player leave + server shutdown.
- Schema versioning and migration functions.

### Offline Progress
- Compute from `lastOnlineUnix` on join.
- Cap max offline hours (e.g., 8h base, expandable).
- Apply reduced efficiency (e.g., 60–80%) for balance.

---

## 7) Balancing Framework
Use predictable formulas early, then tune with analytics.

- **Upgrade cost curve:** `baseCost * growth^level`
- **Production curve:** `baseProd * (1 + level*scalar)` or rarity multiplier stack.
- **Prestige gain:** `floor((lifetimeHype / k)^p)` where `p` is 0.35–0.6.

Balancing checkpoints:
- Time to first automation
- Time to first prestige
- Reprint value feeling meaningful but not mandatory too early

---

## 8) Content Roadmap (Fun Features)

### Launch (MVP)
- Core Hype generation loop
- 20–30 stickers
- Merge/evolve mechanic
- Basic upgrades and first prestige layer
- Offline earnings
- 1 zone + starter quests

### Update 1
- Sticker collection book bonuses
- Limited-time event stickers
- Daily login streak rewards
- 2nd zone

### Update 2
- Challenge modes with mutators
- Cosmetic trails/board skins
- Leaderboards (lifetime Hype, prestige count)

### Update 3
- Guild-lite social mechanic (crew buffs)
- Trading duplicates (restricted, anti-exploit checks)

---

## 9) UX & Retention Features
- **Clear dopamine moments:** level-up bursts, rarity reveals, merge VFX.
- **Short quests:** “Collect 500 Hype in 60s”, “Merge 3 commons.”
- **Daily goals:** rotating 3-task board.
- **Session pacing:** meaningful actions every 10–20 seconds early game.
- **Accessibility:** reduced motion option, colorblind-safe rarity indicators.

---

## 10) Multiplayer & Social Layer (Lightweight)
- Public plaza where players show off sticker boards.
- Inspect another player’s collection progress.
- Server-wide boost events (“Hype Rush: +50% for 3 minutes”).
- Emotes/reactions on rare pulls.

---

## 11) Anti-Exploit & Security
- Never trust client economy actions.
- Server-side validation for all purchase/collect/prestige remotes.
- Cooldowns and sanity checks on RemoteEvents.
- Centralized economy transaction service with logs.
- Rate limits per player for high-frequency actions.

---

## 12) Development Milestones (8-Week Example)

### Week 1–2: Foundation
- Rojo project, architecture, data profile setup.
- Core currency tick and starter UI.

### Week 3–4: Systems
- Upgrades, merge/evolve, first zone content.
- Save/load + offline progress.

### Week 5: Prestige + Balance Pass 1
- Reprint loop and prestige upgrades.
- Economy tuning pass.

### Week 6: Polish
- Juice/VFX, SFX, tutorial, quest layer.

### Week 7: Testing + Hardening
- Exploit testing, data migration tests, bugfixes.

### Week 8: Launch Prep
- Analytics hooks, thumbnails/icons, release checklist.

---

## 13) Analytics Plan (Must-Have)
Track at minimum:
- Time to first upgrade, auto-upgrade, prestige.
- Session length and return rate (D1, D3, D7).
- Most/least purchased upgrades.
- Where players churn (UI screen, progression wall).

Use data to tune cost curves and reduce dead zones.

---

## 14) Quick Start Checklist
- [ ] Set up Rojo sync and baseline place file.
- [ ] Build economy config modules first (numbers in data, not hardcoded).
- [ ] Implement server-authoritative economy transaction API.
- [ ] Ship playable core loop before adding large content.
- [ ] Add analytics events before first public test.
- [ ] Run small closed test and tune based on funnel metrics.

---

## 15) Stretch Ideas (High Fun Potential)
- **Sticker Fusion Lab:** temporary experiments that mutate production.
- **Weather system:** rain, neon night, glitch storm each with modifiers.
- **Mini active game:** 15-second rhythm tap burst for temporary multiplier.
- **Creator codes:** vanity support with tiny non-P2W perks.

This plan is intentionally structured so you can build the MVP quickly in Rojo, then scale content and systems without rewriting core architecture.
