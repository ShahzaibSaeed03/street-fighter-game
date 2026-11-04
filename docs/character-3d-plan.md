# Character 3D Redesign Plan

Inventory + options for making all characters look 3D / professional / realistic.  
**No game code or assets changed yet** — planning only.

Engine: **Godot 4.7** (`project.godot` `config/features` = `4.7`, `config_version=5`, Forward Plus).  
3D today: **none** — no `.gltf` / `.glb` / `.fbx` / `Node3D` gameplay scenes; only a default MeshInstance3D compatibility flag in `project.godot`. Gameplay is fully **2D** (`CharacterBody2D`, `Node2D`, CanvasItem `_draw()`).

---

## Current art approach

Almost every character is **procedural vector art drawn in GDScript** (`queue_redraw` + `draw_*`), not sprite sheets. In-game heroes are a top-down armored knight (`HeroArt.gd` on `Player.tscn` → `$Art`). Enemies use either a generic hunched ghoul (`EnemyArt.gd`) or a species-specific body in `CreatureArt.gd`, selected by `Guard.gd` from each world’s `roster` in `Worlds.gd`. Story cutscenes draw a **side-view** hero, Princess, and villain in `StoryScene.gd`. Menu faces use `Portrait.gd`. Bitmap art on disk is limited to cave tiles, weapon icons (`assets/weapons/w0–w9.png`), app icons — **no character sprites**.

---

## Full character list to convert

### Heroes (3) — playable top-down + menu + story
| Name | ID | Art today |
|---|---|---|
| Jake (The Shadow Knight) | `ayaan` | `HeroArt.gd` (cape/plume tint) + `Portrait.gd` + story `_draw_hero` |
| Maya (The Keen Archer) | `zara` | same + `female` skirt/hair |
| Marcus (The Iron Guard) | `kabir` | same (blue cape/plume) |

Key paths: `W:\street-fighter-game\Heroes.gd`, `HeroArt.gd`, `Player.tscn`, `Player.gd`, `Portrait.gd`, `Menu.gd` (spawns HeroArt + HeroPortrait).

### NPCs (1 story character)
| Name | Art today |
|---|---|
| Princess (unnamed in lore; comment “Princess Zara” in StoryScene) | Procedural side-view only — `StoryScene.gd` `_draw_princess` |

### Enemy species / art bodies (17)
Drawn in `CreatureArt.gd` except **ghoul**, which is `EnemyArt.gd`:

1. ghoul (fallback)  
2. bat · 3. wasp · 4. vulture · 5. spider · 6. scorpion · 7. golem · 8. wraith · 9. skeleton · 10. ghost · 11. hound · 12. imp · 13. yeti · 14. crab · 15. shroom · 16. knight · 17. slime  

Wiring: `Guard.gd` → if `species == "ghoul"` use `EnemyArt.gd`, else `CreatureArt.gd` with `species` + tier palette. Roster maps live in `Worlds.gd` (`roster` per world). Behaviour kinds (grunt/archer/flyer/hound/brute/shield/blinder/listener/scout/boss) are **AI**, not separate meshes — same species art reused.

### Bosses (40 named; 1 per level)
Boss **stats/names** in `Worlds.gd` `bosses` arrays; boss **visual** = world’s `roster["boss"]` species (scaled via `is_boss` / kind), not unique meshes.

Notable finale: **THE NIGHT KING** (Night Citadel L40) → art species `wraith` tier 3. Other examples: Ember King → `knight`; Mire Tyrant → `spider`; Crystal Queen → `golem`; Winter Queen → `yeti`; Golden Tyrant → `skeleton`.

Full 40 names (8 worlds × 5): Cinder Captain, Ash Widow, Torchbearer, Charred Knight, Ember King; Bog Witch, Spore Mother, Leech Lord, Muddy Deacon, Mire Tyrant; Gem Cutter, Shard Spider, Geode Golem, Prism Warden, Crystal Queen; Tinkerer, Cog Knight, Steam Baron, Great Pendulum, Clockwork Emperor; Tide Caller, Pearl Diver, Kraken’s Hand, Drowned Admiral, Leviathan; Snow Stalker, Ice Hermit, Avalanche, Frost Wyrm, Winter Queen; Court Jester, Gilded Guard, Crown Minister, Masked Duke, Golden Tyrant; Dusk Herald, Moon Eater, Shadow Twin, Night Knight, **Night King**.

### Counts (conversion surface)
| Category | Count | Notes |
|---|---:|---|
| Heroes | 3 | Top-down + portrait + story side-view |
| Princess | 1 | Story / UI only |
| Enemy art species | 17 | Includes ghoul |
| Named bosses | 40 | Mostly recolors/scale of species art |
| **Unique visual bodies (min)** | **~21** | 3 heroes + princess + 17 species |
| **If bosses get unique looks** | **~61** | +40 boss variants |

---

## Realistic options (for this codebase)

### (A) Full 3D meshes in Godot
Import GLB characters, `Node3D` / `MeshInstance3D`, top-down or angled camera, AnimationPlayer/Tree.

- **Effort:** Very high — rewrite player/enemy presentation, lighting, shadows, collision visual sync; risk of reworking dungeon/tiles too. Mobile APK already ships as 2D Forward+/compat.
- **Risk:** High. Breaks `HeroArt`/`CreatureArt`/`EnemyArt` contracts; vision cones, Y-sort, scaling, and story scenes all assume CanvasItem. Photoreal 3D at this camera distance often looks uncanny or muddy on mobile.
- **Fit:** Poor as a first step for a top-down stealth dungeon already tuned in 2D.

### (B) High-quality 3D-rendered 2D sprites (from 3D models)
Author/buy 3D models → render orthographic top-down (and side-view for story) sprite sheets / atlases → swap procedural `_draw` for `AnimatedSprite2D` / `Sprite2D` while keeping `CharacterBody2D` gameplay.

- **Effort:** Medium–high on art pipeline; **medium** on code (replace art nodes, keep Guard/Player APIs).
- **Risk:** Medium. Animation frame counts (idle/walk/attack/death × directions) must match gameplay; file size vs current near-zero character textures. Best “real-looking” result without engine rewrite.
- **Fit:** Strong — preserves stealth/top-down readability and Godot 2D systems.

### (C) AI / photoreal texture pass still in current pipeline
Keep procedural silhouettes; bake AI textures onto polygons, or generate stills used as sprites; or lightly shade existing `_draw` shapes.

- **Effort:** Low–medium.
- **Risk:** Medium–high quality inconsistency; hard to get “professional real” from geometric blobs; direction/animation still fake.
- **Fit:** Fast prototype only — unlikely to satisfy “all characters 3D professional real-looking.”

---

## Recommended approach

**Prefer (B): 3D-authored models → orthographic 2D sprites**, keep Godot **4.x 2D** gameplay.

Why:
1. Game is top-down stealth with vision cones — silhouette clarity beats cinematic 3D lighting.
2. All character presentation is already swappable art children (`Player.$Art`, `Guard.art`); logic need not move to 3D.
3. Delivers the “real / professional” look the user wants without a full 3D migration.
4. Story scenes can reuse the same models rendered in side view for Princess / Night King / heroes.

Use (C) only for throwaway moodboards. Reserve (A) for a later ground-up remake if the team explicitly wants a 3D camera.

---

## Suggested first milestone

**Milestone 1 — 3 heroes only (Jake / Maya / Marcus)**  
1. Define top-down orthographic turntable (8 or 4 directions) + idle / walk / attack / dodge frames.  
2. Replace `HeroArt.gd` drawing with sprite-driven art behind the same `apply_hero` / `apply_loadout` / state properties (`aim_angle`, `move_amount`, `attack_progress`, `dodging`).  
3. Update `Portrait.gd` (or stills) and optionally story `_draw_hero` to match.  
4. Playtest stealth readability at dungeon scale on desktop + mobile.

**Milestone 2** — Princess story art + Night King (unique boss wraith/king look).  
**Milestone 3** — 17 enemy species atlases (priority: imp, knight, slime, crab, yeti, wraith, hound — most roster use).  
**Milestone 4** — Unique boss overlays / silhouettes for world-end bosses if needed.

---

## Key file map (do not change yet)

| Role | Paths |
|---|---|
| Engine | `W:\street-fighter-game\project.godot` |
| Heroes data | `Heroes.gd` |
| Hero in-game art | `HeroArt.gd`, `Player.tscn`, `Player.gd` |
| Hero UI face | `Portrait.gd`, `Menu.gd` |
| Enemy pipeline | `Guard.gd`, `EnemyArt.gd`, `CreatureArt.gd`, `EnemyEyes.gd` |
| Rosters / bosses | `Worlds.gd` |
| Princess / story cast | `StoryScene.gd` (`_draw_princess`, `_draw_hero`, `_draw_enemy`) |
| Bitmap assets today | `assets\cave_tiles.png`, `assets\weapons\*.png`, `icons\` |
| No 3D character assets | (none in repo) |
