# Story / Guide vs Code Analysis

Compared `docs/GAME_STORY_AND_GUIDE.md` (also mirrored at `W:\street-fighter-game\GAME_STORY_AND_GUIDE.md`) against Godot sources at `W:\street-fighter-game\` (`Story.gd`, `Worlds.gd`, `Heroes.gd`, `Items.gd`, `Missions.gd`, `Progression.gd`, `Guard.gd`, `Dungeon.gd`, plus `Game.gd`, `Player.gd`, `PowerUp.gd`, `Layouts.gd`, `TouchControls.gd`, `CreatureArt.gd`, `Bell.gd`).

## Verdict

The guide is a faithful dump of the current content data: premise, 8×5 levels/bosses/rooms, heroes, enemy behaviours, dungeon rules, shop, progression, and controls all match the live scripts with only minor naming/completeness gaps. It is not outdated in any structural way. Story quality is coherent at the arc level, with a few line-level lore slips inside `Story.gd` that the guide mostly does not repeat.

## What matches

- **Premise & ending** (`Story.gd`): Dawn Crystal → 8 shards / 8 worlds → Night Citadel → Princess freed → sunrise / THE END; `{hero}` placeholder; Princess unnamed; `SKIP_SEEN := true`.
- **Worlds 1–8 tables** (`Worlds.gd`): titles, level names, descs, bosses, `kinds` unlock order, summon kinds, hazards, weather, favor layouts, room names — line-for-line with the guide.
- **Shard cadence** (`Story.gd` `shardget`): levels 5 / 10 / 15 / 20 / 25 / 30 / 35 / **38** (Star Vault / Shadow Twin), then Night King at 40 — guide §2/§4 is correct that the 8th shard is not on the final boss.
- **Heroes** (`Heroes.gd`): Jake / Maya / Marcus prices, titles, powers, and numeric bonuses match (Marcus `dmg: 0.85` is correctly damage-*taken* via `Player.gd`).
- **Enemy behaviours & AI** (`Worlds.gd` header, `Guard.gd`): grunt/archer/flyer/hound/brute/shield/blinder/listener/scout; PATROL → SUSPECT → CHASE; elite + sleeping guards.
- **Art species list** (`CreatureArt.gd` + `EnemyArt.gd` ghoul fallback): the 17 species the guide lists are present; per-world roster art sets match `Worlds.gd`.
- **Boss scaling** (`Worlds.gd` `_level`): HP `240 + 2100*(d/39)` → ~2340 at L40; burst from `d >= 4` (level 5+); summons on world stages 4–5.
- **Dungeon rules** (`Dungeon.gd`, `Worlds.gd`, `Game.gd`, `PowerUp.gd`): 5–9 rooms; start/boss fixed; bronze/gold keys; modes patrol/ambush/sleep/mini; curtains + secrets; bells every 4th level; timer every 7th from level 7; hazards from level 4; Haste 6s / Quiet 8s; stars at alerts ≤8 / ≤3.
- **Controls** (`Game.gd`, `Player.gd`, `TouchControls.gd`, `Bell.gd`): WASD, C sneak, Space/LMB sword, F/RMB bow, Shift roll, E decoy/bell, R restart, ESC menu; touch sticks + AUTO BOW / SNEAK / DECOY etc.
- **Shop** (`Items.gd`): sword / armor / bow catalogue, unlock challenges, Vitality 5 tiers.
- **Progression** (`Progression.gd`): XP 10 / +5 silent / 150 boss / 100 clear; the six perks and five challenges named in the guide.

## Gaps / mismatches / outdated claims

| Issue | Guide | Code | Severity |
|---|---|---|---|
| Part 6 chapter name | Guide §2 “FROSTPEAK” | `Worlds.gd` title `FROSTPEAK`, but `Story.gd` chapter card `PART VI - THE FROZEN PEAKS` | Low — guide matches Worlds, not Story card |
| Missions §10 | Examples only (“jaise…”) | Full `Missions.gd` has 16 coin + 7 hard missions (e.g. Dream Thief, Orb Collector, World Walker, Warden’s Bane, Giant Slayer, Star Master) | Incomplete, not wrong |
| Hard gifts | Names Ghost Blade / Perfectionist / World Breaker / Night’s End | Match; also note World Breaker gifts `frostlong` which is already a 1900 shop sword (`Items.gd`) | Omission / design smell |
| Controls | C sneak; E decoy/bell | Also Ctrl sneak; arrow keys move; N/B level skip (`Game.gd` help overlay) | Low omission |
| Armor label | “Leather” | `Leather Armor` | Trivial |
| Vitality | “+HP” per level | `VITALITY_HP := 20` each | Omission |
| Layout name | “L-shape” | `Layouts.gd` id `ell` | Naming only |
| Guide §4 heading “40 boss” | Implies 40 bosses | True (one boss per level) — not a mismatch | — |

No evidence the guide describes removed systems or wrong level/boss matrices. Content files are the source of truth the guide claims.

## Story quality notes

- **Arc works**: raid → shard hunt → Herald watch → Ice Hermit reveal (Night King was a failed Crystal guardian) → Golden Tyrant temptation → Night Citadel → dawn. Emotional beats land for a short interstitial format.
- **Missing names (by design)**: Princess never named (`Story.gd` comment + guide). Hero is profile `{hero}`. Fine for a freemium profile game; naming the Princess would strengthen reunion line (“I knew you would come”).
- **Lore slip in `Story.gd` L33 outro**: Crown Minister claims “Only one shard remains, and it is in the Night Citadel,” but after L30 the player has 6 shards — **two** remain (Golden Tyrant L35 + Shadow Twin L38). Guide §2 Part 7 does not copy this error.
- **L1 “shard glitters”** (`Story.gd` L1 outro) is flavor before the first counted Dawn Shard at L5 — easy to misread as shard #1; guide correctly assigns first shard to Ember King.
- **Ice Hermit as boss + lore NPC** (L27): defeat beat then exposition works, but the name “Hermit” reads ally-like for a boss fight.
- **Opportunities**: name the Princess; fix L33 shard count; give Night King / Herald a bit more connective tissue between worlds 4 and 8; optional brief hub/journal so shard count is visible outside scene text.

## Suggested next work (grounded)

1. Fix `Story.gd` level-33 outro shard count (“two shards remain: one in the Gilded Palace, one in the Night Citadel”).
2. Align chapter card “THE FROZEN PEAKS” with world title `FROSTPEAK` (or update the guide to quote both).
3. Expand guide §10 to the full `Missions.gd` list if the guide is meant as a complete player reference.
4. Optional narrative pass: name the Princess; clarify L1 spark vs Dawn Shard #1.
5. Do **not** treat the guide as stale for combat/meta systems — those sections are current.
