extends RefCounted
## Layouts.gd — extra room templates. The six built-in rooms (A-F) live in Dungeon.gd; these are the
## extra ones that rooms B-E and the new templates are drawn from (the start is always A, the boss F).
## Coordinates are room-local (room is 1152 x 648).
##   props     [x, y, w, h, kind]   solid: crate, pillar, shelf, rack (block movement and sight)
##   curtains  [x, y, w, h]         walk-through cover: a guard that is not right next to you cannot see you
##   spikes    [x, y, w, h]         floor traps
##   pools     [x, y, w, h]         lava / water
##   guards    [[route points], tier]
##   hearts    [x, y]
##   key       [x, y]               optional spot for a key
##   dark      true                 no torches, darker floor
## Keep the door lanes clear: top and bottom middle (x 480-672), left and right middle (y 230-420).
## Keep coins (150,130) (1000,130) (150,520) (1000,520) and the arrow bundle (576,596) free.

## Room templates that the random graph may draw from for ordinary rooms.
const POOL: Array[String] = ["B", "C", "D", "E", "corridor", "hall", "maze", "ell", "cross", "vault", "lava", "dark",
		"gallery", "arena", "zigzag", "shrine", "garden", "moat"]

const TEMPLATES: Dictionary = {
	"corridor": {
		"name": "Long Corridor",
		"dark": false,
		"props": [
			[180, 200, 64, 40, "shelf"], [300, 200, 64, 40, "shelf"], [420, 200, 64, 40, "shelf"],
			[668, 200, 64, 40, "shelf"], [788, 200, 64, 40, "shelf"], [908, 200, 64, 40, "shelf"],
			[180, 410, 64, 40, "shelf"], [300, 410, 64, 40, "shelf"], [420, 410, 64, 40, "shelf"],
			[668, 410, 64, 40, "shelf"], [788, 410, 64, 40, "shelf"], [908, 410, 64, 40, "shelf"],
		],
		"curtains": [[546, 260, 60, 120]],
		"spikes": [], "pools": [],
		"guards": [[[Vector2(260, 300), Vector2(900, 300)], 2], [[Vector2(900, 350), Vector2(260, 350)], 1]],
		"hearts": [[110, 90], [1060, 580]],
	},
	"hall": {
		"name": "Great Hall",
		"dark": false,
		"props": [
			[300, 180, 56, 56, "pillar"], [796, 180, 56, 56, "pillar"],
			[300, 412, 56, 56, "pillar"], [796, 412, 56, 56, "pillar"],
		],
		"curtains": [],
		"spikes": [], "pools": [],
		"guards": [
			[[Vector2(200, 300), Vector2(950, 300)], 2],
			[[Vector2(950, 360), Vector2(200, 360)], 2],
			[[Vector2(576, 160), Vector2(576, 500)], 1],
			[[Vector2(480, 460), Vector2(680, 460)], 1],
		],
		"hearts": [[110, 580], [1070, 580]],
	},
	"maze": {
		"name": "Pillar Maze",
		"dark": false,
		"props": [
			[240, 100, 56, 140, "shelf"], [420, 100, 56, 140, "shelf"], [720, 100, 56, 140, "shelf"], [900, 100, 56, 140, "shelf"],
			[240, 400, 56, 140, "shelf"], [420, 400, 56, 140, "shelf"], [720, 400, 56, 140, "shelf"], [900, 400, 56, 140, "shelf"],
		],
		"curtains": [[930, 250, 60, 120]],
		"spikes": [], "pools": [],
		"guards": [[[Vector2(200, 300), Vector2(950, 300)], 2], [[Vector2(950, 340), Vector2(200, 340)], 1]],
		"hearts": [[110, 90], [1060, 580]],
	},
	"ell": {
		"name": "Side Chamber",
		"dark": false,
		"props": [
			[330, 150, 64, 64, "crate"], [330, 410, 64, 64, "crate"],
			[760, 170, 56, 300, "shelf"], [760, 170, 220, 56, "shelf"],
		],
		"curtains": [[420, 400, 110, 80]],
		"spikes": [], "pools": [],
		"guards": [
			[[Vector2(250, 300), Vector2(650, 300)], 2],
			[[Vector2(650, 380), Vector2(650, 540)], 1],
			[[Vector2(900, 320), Vector2(900, 400)], 2],
		],
		"hearts": [[110, 580]],
	},
	"cross": {
		"name": "Crossroads",
		"dark": false,
		"props": [
			[420, 220, 64, 64, "pillar"], [640, 220, 64, 64, "pillar"],
			[420, 400, 64, 64, "pillar"], [640, 400, 64, 64, "pillar"],
			[230, 150, 64, 64, "crate"], [858, 150, 64, 64, "crate"],
			[230, 434, 64, 64, "crate"], [858, 434, 64, 64, "crate"],
		],
		"curtains": [[330, 180, 90, 60]],
		"spikes": [], "pools": [],
		"guards": [[[Vector2(330, 340), Vector2(820, 340)], 2], [[Vector2(576, 150), Vector2(576, 500)], 1]],
		"hearts": [[110, 580], [1060, 90]],
	},
	"vault": {
		"name": "Vault",
		"dark": false,
		"props": [
			[380, 200, 392, 56, "shelf"],     # top wall of the vault
			[380, 200, 56, 248, "shelf"],     # left wall
			[716, 200, 56, 248, "shelf"],     # right wall
			[380, 392, 150, 56, "shelf"],     # bottom wall, left of the gate
			[606, 392, 166, 56, "shelf"],     # bottom wall, right of the gate
		],
		"curtains": [[880, 300, 90, 120]],
		"spikes": [], "pools": [],
		"guards": [[[Vector2(490, 320), Vector2(660, 320)], 3]],
		"hearts": [[110, 90], [1060, 580]],
		"key": [576, 320],
	},
	"lava": {
		"name": "Lava Ring",
		"dark": false,
		"props": [],
		"curtains": [],
		"spikes": [],
		"pools": [
			[380, 170, 90, 60], [682, 170, 90, 60], [380, 418, 90, 60], [682, 418, 90, 60],
			[300, 170, 60, 60], [792, 170, 60, 60], [300, 418, 60, 60], [792, 418, 60, 60],
		],
		"guards": [[[Vector2(450, 324), Vector2(700, 324)], 2], [[Vector2(576, 250), Vector2(576, 400)], 1]],
		"hearts": [[110, 90], [1060, 580]],
	},
	"dark": {
		"name": "Dark Room",
		"dark": true,
		"props": [
			[260, 170, 64, 64, "crate"], [260, 400, 64, 64, "crate"],
			[830, 170, 64, 64, "crate"], [830, 400, 64, 64, "crate"],
		],
		"curtains": [[440, 260, 100, 130], [640, 260, 100, 130]],
		"spikes": [], "pools": [],
		"guards": [[[Vector2(180, 300), Vector2(970, 300)], 1], [[Vector2(576, 150), Vector2(576, 500)], 1]],
		"hearts": [[110, 580], [1060, 90]],
	},
	"gallery": {
		"name": "Long Gallery",
		"dark": false,
		"props": [
			[200, 110, 260, 44, "rack"], [692, 110, 260, 44, "rack"],
			[200, 494, 260, 44, "rack"], [692, 494, 260, 44, "rack"],
		],
		"curtains": [[250, 170, 100, 70], [800, 410, 100, 70]],
		"spikes": [], "pools": [],
		"guards": [[[Vector2(260, 300), Vector2(900, 300)], 2], [[Vector2(576, 180), Vector2(576, 470)], 1]],
		"hearts": [[110, 300], [1060, 300]],
	},
	"arena": {
		"name": "Open Arena",
		"dark": false,
		"props": [],
		"curtains": [[250, 160, 90, 90], [812, 160, 90, 90], [250, 398, 90, 90], [812, 398, 90, 90]],
		"spikes": [], "pools": [],
		"guards": [[[Vector2(300, 324)], 1], [[Vector2(850, 324)], 1], [[Vector2(576, 150), Vector2(576, 500)], 2]],
		"hearts": [[110, 90], [1060, 580]],
	},
	"zigzag": {
		"name": "Zigzag Halls",
		"dark": false,
		"props": [
			[260, 100, 56, 300, "shelf"], [880, 248, 56, 300, "shelf"],
			[560, 130, 64, 64, "crate"], [560, 454, 64, 64, "crate"],
		],
		"curtains": [[380, 440, 100, 80]],
		"spikes": [], "pools": [],
		"guards": [[[Vector2(200, 460), Vector2(780, 460)], 2], [[Vector2(980, 200), Vector2(400, 200)], 1]],
		"hearts": [[110, 580], [1060, 90]],
	},
	"shrine": {
		"name": "Shrine",
		"dark": false,
		"props": [[500, 250, 152, 148, "pillar"]],
		"curtains": [[330, 260, 80, 130], [742, 260, 80, 130]],
		"spikes": [], "pools": [],
		"guards": [[[Vector2(380, 180), Vector2(780, 180), Vector2(780, 470), Vector2(380, 470)], 2]],
		"hearts": [[110, 90], [1060, 580]],
	},
	"garden": {
		"name": "Overgrown Garden",
		"dark": false,
		"props": [[200, 330, 64, 64, "crate"], [880, 330, 64, 64, "crate"], [360, 480, 64, 64, "crate"], [730, 110, 64, 64, "crate"]],
		"curtains": [[250, 150, 100, 90], [760, 430, 100, 90], [400, 300, 90, 90], [662, 300, 90, 90]],
		"spikes": [], "pools": [],
		"guards": [[[Vector2(300, 250), Vector2(850, 250)], 1], [[Vector2(850, 400), Vector2(300, 400)], 1]],
		"hearts": [[110, 580], [1060, 90]],
	},
	"moat": {
		"name": "Moat Room",
		"dark": false,
		"props": [[500, 120, 152, 40, "rack"], [500, 488, 152, 40, "rack"]],
		"curtains": [],
		"spikes": [[460, 250, 70, 70], [622, 250, 70, 70]],
		"pools": [[190, 190, 200, 60], [762, 190, 200, 60], [190, 400, 200, 60], [762, 400, 200, 60]],
		"guards": [[[Vector2(250, 324), Vector2(900, 324)], 2], [[Vector2(576, 160), Vector2(576, 480)], 1]],
		"hearts": [[110, 90], [1060, 580]],
	},
	# Hidden room behind a curtain. Not in POOL: the graph adds it on purpose (see Dungeon._add_secret_room).
	"secret": {
		"name": "Hidden Vault",
		"dark": false,
		"props": [
			[300, 200, 56, 56, "pillar"], [796, 200, 56, 56, "pillar"],
			[300, 392, 56, 56, "pillar"], [796, 392, 56, 56, "pillar"],
		],
		"curtains": [],
		"spikes": [], "pools": [],
		"guards": [],
		"hearts": [[576, 200]],
		"loot": [[576, 300, "coin", 60]],
	},
}


## Floor colour multiplier per template, so each room type reads differently.
const TINTS: Dictionary = {
	"corridor": Color(0.9, 0.92, 1.0),
	"hall": Color(1.05, 1.0, 0.95),
	"maze": Color(0.9, 0.97, 0.9),
	"ell": Color(1.0, 0.97, 0.9),
	"cross": Color(1.0, 1.0, 1.06),
	"vault": Color(0.92, 0.88, 0.85),
	"lava": Color(1.2, 0.8, 0.7),
	"dark": Color(0.85, 0.85, 0.95),
	"secret": Color(0.95, 0.9, 0.82),
	"gallery": Color(0.97, 0.95, 1.0),
	"arena": Color(1.04, 1.0, 0.96),
	"zigzag": Color(0.94, 0.98, 0.96),
	"shrine": Color(1.0, 0.94, 1.06),
	"garden": Color(0.92, 1.04, 0.92),
	"moat": Color(0.9, 0.96, 1.08),
}


static func tint_of(lay: String) -> Color:
	return TINTS.get(lay, Color(1, 1, 1))


static func has_template(lay: String) -> bool:
	return TEMPLATES.has(lay)


static func is_dark(lay: String) -> bool:
	return TEMPLATES.has(lay) and bool(TEMPLATES[lay]["dark"])


static func room_name(lay: String) -> String:
	return String(TEMPLATES[lay]["name"])
