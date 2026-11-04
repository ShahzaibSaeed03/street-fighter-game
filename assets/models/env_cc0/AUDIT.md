# Environment CC0 audit

Kenney kits: CC0. Normalize so **1 modular tile ≈ 2 m** in Blender/Godot.
Game mapping: 64 px (TILE) → 2.0 m (`px_to_m = 2/64`).

## World mapping (usable kits)

| World | Kits | Poly Haven textures |
|-------|------|---------------------|
| 1 Emberfall | dungeon + cave | volcanic_rock_tiles, rock_boulder_cracked, volcanic_herringbone_01 |
| 2 Whispering Mire | graveyard + fantasy-town + nature | mud/moss |
| 3 Crystal Deep | cave | rock_05/06, boulder_dry |
| 4 Clockwork | factory | rusty_metal, metal_plate, corrugated_iron |
| 5 Coral Abyss | pirate + nature | sand/rocks |
| 6 Frostpeak | nature | snow + rock_01 |
| 7 Gilded Palace | fantasy-town + castle | sandstone/marble/sand |
| 8 Night Citadel | castle + graveyard + dungeon | castle brick |

## kenney_modular-dungeon-kit_1.0 (W1 Emberfall / W8 Night Citadel)

| File | KB | Tris | Meshes | Size XYZ | Scale→2m | Textures |
|------|----|------|--------|----------|----------|----------|
| `corridor-corner.glb` | 78.7 | 858 | 1 | 4.00×4.00×4.23 | 0.5 | colormap (512x512) |
| `corridor-end.glb` | 123.8 | 1348 | 1 | 4.00×4.00×4.15 | 0.5 | colormap (512x512) |
| `corridor-intersection.glb` | 34.2 | 340 | 1 | 4.00×4.00×4.05 | 0.5 | colormap (512x512) |
| `corridor-junction.glb` | 58.7 | 620 | 1 | 4.01×4.00×4.15 | 0.4993 | colormap (512x512) |
| `corridor-transition.glb` | 230.8 | 2524 | 1 | 8.00×8.00×4.15 | 0.25 | colormap (512x512) |
| `corridor-wide-corner.glb` | 161.0 | 1766 | 1 | 8.00×8.00×4.23 | 0.25 | colormap (512x512) |
| `corridor-wide-end.glb` | 319.6 | 3514 | 1 | 8.00×8.00×4.23 | 0.25 | colormap (512x512) |
| `corridor-wide-intersection.glb` | 35.4 | 352 | 1 | 8.00×8.00×4.05 | 0.25 | colormap (512x512) |
| `corridor-wide-junction.glb` | 124.8 | 1350 | 1 | 8.00×8.00×4.23 | 0.25 | colormap (512x512) |
| `corridor-wide.glb` | 214.1 | 2348 | 1 | 8.00×8.00×4.23 | 0.25 | colormap (512x512) |
| `corridor.glb` | 83.1 | 900 | 1 | 4.00×4.00×4.15 | 0.5 | colormap (512x512) |
| `gate-door-window.glb` | 92.9 | 1048 | 2 | 4.40×1.88×4.40 | 0.4545 | colormap (512x512) |
| `gate-door.glb` | 88.5 | 984 | 2 | 4.40×1.88×4.40 | 0.4545 | colormap (512x512) |
| `gate-metal-bars.glb` | 66.6 | 720 | 2 | 4.40×1.40×4.40 | 0.4545 | colormap (512x512) |
| `gate.glb` | 52.5 | 592 | 1 | 4.40×1.40×4.40 | 0.4545 | colormap (512x512) |
| `room-corner.glb` | 426.9 | 4718 | 1 | 12.00×12.00×4.23 | 0.1667 | colormap (512x512) |
| `room-large-variation.glb` | 855.3 | 9304 | 1 | 20.00×20.00×4.23 | 0.1 | colormap (512x512) |
| `room-large.glb` | 899.9 | 9776 | 1 | 20.00×20.00×4.23 | 0.1 | colormap (512x512) |
| `room-small-variation.glb` | 411.5 | 4464 | 1 | 12.00×12.00×4.23 | 0.1667 | colormap (512x512) |
| `room-small.glb` | 403.3 | 4388 | 1 | 12.00×12.00×4.23 | 0.1667 | colormap (512x512) |
| `room-wide-variation.glb` | 808.3 | 8864 | 1 | 20.00×12.00×4.23 | 0.1 | colormap (512x512) |
| `room-wide.glb` | 668.1 | 7268 | 1 | 20.00×12.00×4.23 | 0.1 | colormap (512x512) |
| `stairs-wide.glb` | 274.4 | 3194 | 1 | 8.40×8.40×8.55 | 0.2381 | colormap (512x512) |
| `stairs.glb` | 264.8 | 3074 | 1 | 4.40×8.40×8.55 | 0.4545 | colormap (512x512) |
| `template-corner.glb` | 70.7 | 774 | 1 | 4.00×4.00×4.23 | 0.5 | colormap (512x512) |
| `template-detail.glb` | 17.8 | 176 | 1 | 1.79×1.79×4.23 | 1.1165 | colormap (512x512) |
| `template-floor-big.glb` | 49.2 | 492 | 1 | 8.00×8.00×4.23 | 0.25 | colormap (512x512) |
| `template-floor-detail-a.glb` | 22.1 | 204 | 1 | 4.00×4.00×0.10 | 0.5 | colormap (512x512) |
| `template-floor-detail.glb` | 22.1 | 204 | 1 | 4.00×4.00×0.10 | 0.5 | colormap (512x512) |
| `template-floor-layer-hole.glb` | 40.1 | 384 | 1 | 4.04×4.00×3.09 | 0.4946 | colormap (512x512) |
| `template-floor-layer-raised.glb` | 32.9 | 312 | 1 | 4.02×4.00×3.00 | 0.4971 | colormap (512x512) |
| `template-floor-layer.glb` | 18.5 | 168 | 1 | 4.02×4.00×0.50 | 0.4971 | colormap (512x512) |
| `template-floor.glb` | 2.0 | 4 | 1 | 4.00×4.00×0.00 | 0.5 | colormap (512x512) |
| `template-wall-corner.glb` | 9.5 | 84 | 1 | 1.00×1.00×4.05 | 1.996 | colormap (512x512) |
| `template-wall-detail-a.glb` | 57.4 | 614 | 1 | 4.00×1.99×4.23 | 0.5 | colormap (512x512) |
| `template-wall-half.glb` | 26.6 | 276 | 1 | 2.00×1.81×4.15 | 1.0 | colormap (512x512) |
| `template-wall-stairs.glb` | 15.0 | 170 | 1 | 4.00×0.63×4.50 | 0.5 | colormap (512x512) |
| `template-wall-top.glb` | 27.0 | 330 | 1 | 4.00×0.62×4.50 | 0.5 | colormap (512x512) |
| `template-wall.glb` | 42.2 | 448 | 1 | 4.00×1.99×4.15 | 0.5 | colormap (512x512) |

**Emberfall picks:** `template-floor*`, `template-wall*`, `template-wall-corner`, `corridor`, `corridor-corner`, `stairs`, `gate`, `gate-door`, `room-corner` (retexture with volcanic PBR; avoid shipping raw Kenney materials).

## kenney_modular-cave-kit_1.0 (W1 Emberfall / W3 Crystal Deep)

| File | KB | Tris | Meshes | Size XYZ | Scale→2m | Textures |
|------|----|------|--------|----------|----------|----------|
| `corridor-corner.glb` | 65.0 | 624 | 1 | 4.00×4.00×4.40 | 0.5 | colormap (512x512) |
| `corridor-end.glb` | 125.9 | 1324 | 1 | 4.00×4.00×4.05 | 0.5 | colormap (512x512) |
| `corridor-intersection.glb` | 23.9 | 244 | 1 | 4.00×4.00×4.05 | 0.5 | colormap (512x512) |
| `corridor-junction.glb` | 54.3 | 564 | 1 | 4.01×4.00×4.05 | 0.4993 | colormap (512x512) |
| `corridor-transition.glb` | 214.3 | 2276 | 1 | 8.00×8.00×4.05 | 0.25 | colormap (512x512) |
| `corridor-wide-corner.glb` | 148.8 | 1516 | 1 | 8.00×8.00×4.40 | 0.25 | colormap (512x512) |
| `corridor-wide-end.glb` | 228.0 | 2428 | 1 | 8.12×8.23×4.40 | 0.2464 | colormap (512x512) |
| `corridor-wide-intersection.glb` | 25.1 | 256 | 1 | 8.00×8.00×4.05 | 0.25 | colormap (512x512) |
| `corridor-wide-junction.glb` | 89.1 | 940 | 1 | 8.00×8.12×4.40 | 0.25 | colormap (512x512) |
| `corridor-wide.glb` | 153.0 | 1624 | 1 | 8.00×8.23×4.40 | 0.25 | colormap (512x512) |
| `corridor.glb` | 84.5 | 884 | 1 | 4.00×4.00×4.05 | 0.5 | colormap (512x512) |
| `gate-metal-bars.glb` | 66.6 | 720 | 2 | 4.40×1.40×4.40 | 0.4545 | colormap (512x512) |
| `gate-overhang.glb` | 9.9 | 104 | 1 | 4.00×2.05×0.80 | 0.5 | colormap (512x512) |
| `gate-rock.glb` | 31.0 | 360 | 1 | 4.00×2.45×4.05 | 0.5 | colormap (512x512) |
| `gate.glb` | 52.5 | 592 | 1 | 4.40×1.40×4.40 | 0.4545 | colormap (512x512) |
| `ladder.glb` | 16.9 | 160 | 1 | 1.15×0.28×2.90 | 1.7452 | colormap (512x512) |
| `room-corner.glb` | 354.5 | 3612 | 1 | 12.12×12.12×4.40 | 0.1651 | colormap (512x512) |
| `room-large-variation.glb` | 773.2 | 7956 | 1 | 20.00×20.23×4.40 | 0.1 | colormap (512x512) |
| `room-large.glb` | 786.1 | 8080 | 1 | 20.00×20.23×4.40 | 0.1 | colormap (512x512) |
| `room-small-variation.glb` | 376.7 | 3868 | 1 | 12.00×12.00×4.40 | 0.1667 | colormap (512x512) |
| `room-small.glb` | 338.4 | 3356 | 1 | 12.00×12.00×4.40 | 0.1667 | colormap (512x512) |
| `room-wide-variation.glb` | 650.9 | 6704 | 1 | 20.00×12.23×4.40 | 0.1 | colormap (512x512) |
| `room-wide.glb` | 537.5 | 5460 | 1 | 20.00×12.23×4.40 | 0.1 | colormap (512x512) |
| `stairs-wide.glb` | 231.9 | 2506 | 1 | 8.00×8.00×8.55 | 0.25 | colormap (512x512) |
| `stairs.glb` | 222.6 | 2386 | 1 | 4.00×8.00×8.55 | 0.5 | colormap (512x512) |
| `template-corner.glb` | 59.6 | 564 | 1 | 4.00×4.00×4.40 | 0.5 | colormap (512x512) |
| `template-detail.glb` | 31.9 | 320 | 1 | 2.64×2.81×4.35 | 0.7563 | colormap (512x512) |
| `template-floor-big.glb` | 63.3 | 636 | 1 | 8.00×8.00×4.35 | 0.25 | colormap (512x512) |
| `template-floor-detail-a.glb` | 22.1 | 204 | 1 | 4.00×4.00×0.10 | 0.5 | colormap (512x512) |
| `template-floor-detail.glb` | 22.1 | 204 | 1 | 4.00×4.00×0.10 | 0.5 | colormap (512x512) |
| `template-floor-layer-hole.glb` | 40.1 | 384 | 1 | 4.04×4.00×3.09 | 0.4946 | colormap (512x512) |
| `template-floor-layer-raised.glb` | 32.9 | 312 | 1 | 4.02×4.00×3.00 | 0.4971 | colormap (512x512) |
| `template-floor-layer.glb` | 18.6 | 168 | 1 | 4.02×4.00×0.50 | 0.4971 | colormap (512x512) |
| `template-floor.glb` | 2.0 | 4 | 1 | 4.00×4.00×0.00 | 0.5 | colormap (512x512) |
| `template-wall-corner.glb` | 7.0 | 60 | 1 | 1.00×1.00×4.05 | 2.0 | colormap (512x512) |
| `template-wall-detail-a.glb` | 41.0 | 420 | 1 | 4.00×2.02×4.40 | 0.5 | colormap (512x512) |
| `template-wall-half.glb` | 19.5 | 192 | 1 | 2.00×1.81×4.05 | 1.0 | colormap (512x512) |
| `template-wall-stairs.glb` | 10.6 | 104 | 1 | 4.00×1.13×4.50 | 0.5 | colormap (512x512) |
| `template-wall-top.glb` | 15.0 | 148 | 1 | 4.00×1.13×4.50 | 0.5 | colormap (512x512) |
| `template-wall.glb` | 42.9 | 440 | 1 | 4.00×2.16×4.05 | 0.5 | colormap (512x512) |

**Emberfall/Crystal picks:** cave `template-*`, `gate-rock`, `ladder`, `stairs` (pair with volcanic or crystal textures).

## Other kits (file inventory — full mesh audit deferred to per-world builds)

### kenney_graveyard-kit_5.0 (W2 / W8)
- 91 GLB, 3.4 MB total
- Sample: `altar-stone.glb`, `altar-wood.glb`, `bench-damaged.glb`, `bench.glb`, `border-pillar.glb`, `brick-wall-curve-small.glb`, `brick-wall-curve.glb`, `brick-wall-end.glb`, `brick-wall.glb`, `candle-multiple.glb`, `candle.glb`, `character-ghost.glb`, `character-keeper.glb`, `character-skeleton.glb`, `character-vampire.glb`, `character-zombie.glb`, `coffin-old.glb`, `coffin.glb`, `column-large.glb`, `cross-column.glb`, `cross-wood.glb`, `cross.glb`, `crypt-a.glb`, `crypt-b.glb`, `crypt-door.glb`, `crypt-large-door.glb`, `crypt-large-roof.glb`, `crypt-large.glb`, `crypt-small-roof.glb`, `crypt-small.glb`, `crypt.glb`, `debris-wood.glb`, `debris.glb`, `detail-bowl.glb`, `detail-chalice.glb`, `detail-plate.glb`, `fence-damaged.glb`, `fence-gate.glb`, `fence.glb`, `fire-basket.glb`
- … +51 more

### kenney_factory-kit_3.0 (W4 Clockwork)
- 143 GLB, 3.1 MB total
- Sample: `arrow-basic-rounded.glb`, `arrow-basic.glb`, `arrow-rounded.glb`, `arrow.glb`, `box-large.glb`, `box-long.glb`, `box-small.glb`, `box-wide.glb`, `button-floor-round-small.glb`, `button-floor-round.glb`, `button-floor-square-small.glb`, `button-floor-square.glb`, `catwalk-corner.glb`, `catwalk-cross.glb`, `catwalk-junction.glb`, `catwalk-stairs-loop.glb`, `catwalk-stairs.glb`, `catwalk-straight.glb`, `cog-a.glb`, `cog-b.glb`, `cog-c.glb`, `cog-d.glb`, `cog-e.glb`, `cone.glb`, `conveyor-bars-fence-slope.glb`, `conveyor-bars-fence.glb`, `conveyor-bars-high-slope.glb`, `conveyor-bars-high.glb`, `conveyor-bars-sides.glb`, `conveyor-bars-stripe-fence-slope.glb`, `conveyor-bars-stripe-fence.glb`, `conveyor-bars-stripe-high-slope.glb`, `conveyor-bars-stripe-high.glb`, `conveyor-bars-stripe-side.glb`, `conveyor-bars-stripe.glb`, `conveyor-bars.glb`, `conveyor-corner.glb`, `conveyor-cross.glb`, `conveyor-junction-t.glb`, `conveyor-long-part-end.glb`
- … +103 more

### kenney_fantasy-town-kit_2.0 (W2 / W7)
- 167 GLB, 2.5 MB total
- Sample: `balcony-wall-fence.glb`, `balcony-wall.glb`, `banner-green.glb`, `banner-red.glb`, `blade.glb`, `cart-high.glb`, `cart.glb`, `chimney-base.glb`, `chimney-top.glb`, `chimney.glb`, `fence-broken.glb`, `fence-curved.glb`, `fence-gate.glb`, `fence.glb`, `fountain-center.glb`, `fountain-corner-inner-square.glb`, `fountain-corner-inner.glb`, `fountain-corner.glb`, `fountain-curved.glb`, `fountain-edge.glb`, `fountain-round-detail.glb`, `fountain-round.glb`, `fountain-square-detail.glb`, `fountain-square.glb`, `hedge-curved.glb`, `hedge-gate.glb`, `hedge-large-curved.glb`, `hedge-large-gate.glb`, `hedge-large.glb`, `hedge.glb`, `lantern.glb`, `overhang.glb`, `pillar-stone.glb`, `pillar-wood.glb`, `planks-half.glb`, `planks-opening.glb`, `planks.glb`, `poles-horizontal.glb`, `poles.glb`, `road-bend.glb`
- … +127 more

### kenney_castle-kit (W7 / W8)
- 76 GLB, 2.1 MB total
- Sample: `bridge-draw.glb`, `bridge-straight-pillar.glb`, `bridge-straight.glb`, `door.glb`, `flag-banner-long.glb`, `flag-banner-short.glb`, `flag-pennant.glb`, `flag-wide.glb`, `flag.glb`, `gate.glb`, `ground-hills.glb`, `ground.glb`, `metal-gate.glb`, `rocks-large.glb`, `rocks-small.glb`, `siege-ballista-demolished.glb`, `siege-ballista.glb`, `siege-catapult-demolished.glb`, `siege-catapult.glb`, `siege-ram-demolished.glb`, `siege-ram.glb`, `siege-tower-demolished.glb`, `siege-tower.glb`, `siege-trebuchet-demolished.glb`, `siege-trebuchet.glb`, `stairs-stone-square.glb`, `stairs-stone.glb`, `tower-base.glb`, `tower-hexagon-base.glb`, `tower-hexagon-mid.glb`, `tower-hexagon-roof-secondary.glb`, `tower-hexagon-roof.glb`, `tower-hexagon-top-wood.glb`, `tower-hexagon-top.glb`, `tower-slant-roof.glb`, `tower-square-arch.glb`, `tower-square-base-border.glb`, `tower-square-base-color.glb`, `tower-square-base.glb`, `tower-square-mid-color.glb`
- … +36 more

### kenney_pirate-kit (W5 Coral Abyss)
- 72 GLB, 3.0 MB total
- Sample: `barrel.glb`, `boat-row-large.glb`, `boat-row-small.glb`, `bottle-large.glb`, `bottle.glb`, `cannon-ball.glb`, `cannon-mobile.glb`, `cannon.glb`, `castle-door.glb`, `castle-gate.glb`, `castle-wall.glb`, `castle-window.glb`, `chest.glb`, `crate-bottles.glb`, `crate.glb`, `flag-high-pennant.glb`, `flag-high.glb`, `flag-pennant.glb`, `flag-pirate-high-pennant.glb`, `flag-pirate-high.glb`, `flag-pirate-pennant.glb`, `flag-pirate.glb`, `flag.glb`, `grass-patch.glb`, `grass-plant.glb`, `grass.glb`, `hole.glb`, `mast-ropes.glb`, `mast.glb`, `palm-bend.glb`, `palm-detailed-bend.glb`, `palm-detailed-straight.glb`, `palm-straight.glb`, `patch-grass-foliage.glb`, `patch-grass.glb`, `patch-sand-foliage.glb`, `patch-sand.glb`, `platform-planks.glb`, `platform.glb`, `rocks-a.glb`
- … +32 more

### kenney_nature-kit (W2 / W5 / W6 / W7)
- 329 GLB, 3.0 MB total
- Sample: `bed.glb`, `bed_floor.glb`, `bridge_center_stone.glb`, `bridge_center_stoneRound.glb`, `bridge_center_wood.glb`, `bridge_center_woodRound.glb`, `bridge_side_stone.glb`, `bridge_side_stoneRound.glb`, `bridge_side_wood.glb`, `bridge_side_woodRound.glb`, `bridge_stone.glb`, `bridge_stoneNarrow.glb`, `bridge_stoneRound.glb`, `bridge_stoneRoundNarrow.glb`, `bridge_wood.glb`, `bridge_woodNarrow.glb`, `bridge_woodRound.glb`, `bridge_woodRoundNarrow.glb`, `cactus_short.glb`, `cactus_tall.glb`, `campfire_bricks.glb`, `campfire_logs.glb`, `campfire_planks.glb`, `campfire_stones.glb`, `canoe.glb`, `canoe_paddle.glb`, `cliff_block_rock.glb`, `cliff_block_stone.glb`, `cliff_blockCave_rock.glb`, `cliff_blockCave_stone.glb`, `cliff_blockDiagonal_rock.glb`, `cliff_blockDiagonal_stone.glb`, `cliff_blockHalf_rock.glb`, `cliff_blockHalf_stone.glb`, `cliff_blockQuarter_rock.glb`, `cliff_blockQuarter_stone.glb`, `cliff_blockSlope_rock.glb`, `cliff_blockSlope_stone.glb`, `cliff_blockSlopeHalfWalls_rock.glb`, `cliff_blockSlopeHalfWalls_stone.glb`
- … +289 more

## Scale notes
- Measured dungeon `template-floor.glb` / wall templates drive `suggested_scale_to_2m_tile`.
- Emberfall export kit applies a uniform scale so floors sit on a 2 m grid.
- Ignore `kenney_car-kit`.
