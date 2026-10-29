extends RefCounted
## Worlds.gd — the 40 levels: 8 worlds with 5 levels each. Every world has its own look (colours, floor,
## props, decor, weather), room names, enemy species and enemy mix, hazards, level names and 5 bosses.
## build() turns this data plus a difficulty curve into the level dictionaries that Levels.gd serves
## (hp, damage, view, speed, coins, hazards, bells, timers, extra guards, boss stats ...).
##
## Enemy kinds (behaviour) per world are listed in introduction order: stage 1 of a world uses the first
## two, each later stage unlocks one more. A level's signature enemy (the one most guards are) rotates
## through the unlocked kinds, so no two levels feel the same.
##   grunt    ordinary guard           archer  shoots from range        flyer    flies over props
##   hound    very fast, sniffs you    brute   huge, heavy hits         shield   blocks hits from the front
##   blinder  throws blinding orbs     listener hears everything, sees little (sneak with C!)
##   scout    sees far in a narrow cone, hears almost nothing

const WORLDS: Array[Dictionary] = [
	{
		"title": "EMBERFALL",
		"banner": Color(1.0, 0.55, 0.25), "ambient": Color(0.5, 0.42, 0.38), "floor": Color(0.22, 0.16, 0.13),
		"boss_floor": Color(0.3, 0.12, 0.08), "wall_dark": Color(0.06, 0.04, 0.04), "wall_trim": Color(1.0, 0.5, 0.2, 0.3),
		"torch": Color(1.0, 0.55, 0.25), "torch_boss": Color(1.0, 0.3, 0.15), "rune": Color(1.0, 0.5, 0.2, 0.2), "boss_rune": Color(1.0, 0.35, 0.1),
		"skin": "ruin", "decor": "ash", "tex": "stone", "weather": "ash",
		"hazard": "spikes", "spike_color": Color(0.7, 0.5, 0.35), "pool_color": Color(0.9, 0.4, 0.1), "pool_kind": "pool",
		"rooms": ["Burnt Gate", "Ashen Barracks", "Charred Archive", "Smoking Armory", "Cinder Treasury", "Ember Throne"],
		"names": ["BURNING GATE", "ASHEN MARKET", "CHARRED CHAPEL", "SMOKING GRANARY", "THE EMBER KEEP"],
		"descs": ["The village is on fire. Raiders dragged the Princess through here.", "Smoke fills the market streets. Imps hide in the ruins.",
			"A chapel of black beams. Something whispers in the ash.", "Burnt grain, hungry hounds. The fires are spreading.", "The raiders' fortress. Their king waits in the embers."],
		"bosses": ["THE CINDER CAPTAIN", "THE ASH WIDOW", "THE TORCHBEARER", "THE CHARRED KNIGHT", "THE EMBER KING"],
		"kinds": ["grunt", "hound", "archer", "flyer", "shield"],
		"roster": {"grunt": ["imp", 0], "archer": ["imp", 1], "brute": ["golem", 1], "flyer": ["bat", 1], "shield": ["knight", 1], "blinder": ["ghost", 1],
			"hound": ["hound", 0], "listener": ["ghoul", 1], "scout": ["imp", 0], "boss": ["knight", 1]},
		"summon": "hound", "favor": ["hall", "corridor", "gallery"], "bias": [0.10, 0.10, 0.10],
	},
	{
		"title": "WHISPERING MIRE",
		"banner": Color(0.5, 0.95, 0.6), "ambient": Color(0.36, 0.5, 0.45), "floor": Color(0.12, 0.2, 0.18),
		"boss_floor": Color(0.1, 0.18, 0.14), "wall_dark": Color(0.03, 0.06, 0.05), "wall_trim": Color(0.5, 0.9, 0.6, 0.3),
		"torch": Color(0.7, 1.0, 0.5), "torch_boss": Color(0.4, 1.0, 0.6), "rune": Color(0.4, 0.9, 0.6, 0.2), "boss_rune": Color(0.4, 1.0, 0.5),
		"skin": "mire", "decor": "spores", "tex": "grass", "weather": "spores",
		"hazard": "pools", "spike_color": Color(0.5, 0.75, 0.35), "pool_color": Color(0.3, 0.7, 0.35), "pool_kind": "pool",
		"rooms": ["Reedy Gate", "Fungus Barracks", "Frog Archive", "Bog Armory", "Pearl Hoard", "Witch's Hollow"],
		"names": ["REEDY SHORE", "TOADSTOOL TRAIL", "DROWNED CHAPEL", "THE LEECH PIT", "THE WITCH'S HUT"],
		"descs": ["A foggy swamp. The tracks lead into the reeds.", "Giant mushrooms and sleepy slimes. Watch where you step.",
			"A chapel half sunk in mud. Listeners lurk inside, so sneak.", "Poison pools and hungry leeches fill this pit.", "The swamp witch brews her curses here."],
		"bosses": ["THE BOG WITCH", "THE SPORE MOTHER", "THE LEECH LORD", "THE MUDDY DEACON", "THE MIRE TYRANT"],
		"kinds": ["grunt", "archer", "flyer", "listener", "hound", "shield"],
		"roster": {"grunt": ["slime", 0], "archer": ["shroom", 0], "brute": ["golem", 1], "flyer": ["wasp", 0], "shield": ["shroom", 0], "blinder": ["ghost", 0],
			"hound": ["hound", 0], "listener": ["slime", 0], "scout": ["spider", 0], "boss": ["spider", 0]},
		"summon": "flyer", "favor": ["garden", "maze", "moat"], "bias": [0.15, 0.30, 0.10],
	},
	{
		"title": "CRYSTAL DEEP",
		"banner": Color(0.75, 0.6, 1.0), "ambient": Color(0.4, 0.36, 0.58), "floor": Color(0.15, 0.12, 0.24),
		"boss_floor": Color(0.2, 0.1, 0.3), "wall_dark": Color(0.04, 0.03, 0.08), "wall_trim": Color(0.8, 0.6, 1.0, 0.35),
		"torch": Color(0.7, 0.6, 1.0), "torch_boss": Color(0.9, 0.4, 1.0), "rune": Color(0.7, 0.5, 1.0, 0.25), "boss_rune": Color(0.85, 0.4, 1.0),
		"skin": "crystal", "decor": "sparkle", "tex": "stone", "weather": "motes",
		"hazard": "both", "spike_color": Color(0.8, 0.6, 1.0), "pool_color": Color(0.6, 0.3, 0.9), "pool_kind": "pool",
		"rooms": ["Glimmer Gate", "Miner Barracks", "Gem Archive", "Pick Armory", "Jewel Vault", "Heart Chamber"],
		"names": ["GLIMMER TUNNELS", "GEODE GROTTO", "PRISM HALL", "THE ECHO MINE", "THE HEART CRYSTAL"],
		"descs": ["Glowing tunnels under the mountain. Crabs scuttle in the dark.", "A cave of giant geodes. Many guards sleep here, so strike quietly.",
			"Light bends through prisms. Scouts watch the long halls.", "Every sound echoes. Listeners hear your every step.", "The great crystal heart pulses with power."],
		"bosses": ["THE GEM CUTTER", "THE SHARD SPIDER", "THE GEODE GOLEM", "THE PRISM WARDEN", "THE CRYSTAL QUEEN"],
		"kinds": ["grunt", "listener", "shield", "scout", "brute", "flyer"],
		"roster": {"grunt": ["crab", 0], "archer": ["crab", 0], "brute": ["golem", 3], "flyer": ["bat", 3], "shield": ["crab", 0], "blinder": ["wraith", 3],
			"hound": ["hound", 0], "listener": ["golem", 3], "scout": ["scorpion", 0], "boss": ["golem", 3]},
		"summon": "flyer", "favor": ["dark", "maze", "vault"], "bias": [0.10, 0.35, 0.15],
	},
	{
		"title": "CLOCKWORK CITADEL",
		"banner": Color(0.95, 0.75, 0.35), "ambient": Color(0.5, 0.45, 0.4), "floor": Color(0.2, 0.17, 0.14),
		"boss_floor": Color(0.28, 0.2, 0.1), "wall_dark": Color(0.06, 0.05, 0.04), "wall_trim": Color(0.9, 0.7, 0.3, 0.4),
		"torch": Color(1.0, 0.75, 0.35), "torch_boss": Color(1.0, 0.6, 0.2), "rune": Color(0.9, 0.7, 0.3, 0.25), "boss_rune": Color(1.0, 0.7, 0.2),
		"skin": "clock", "decor": "sparks", "tex": "stone", "weather": "sparks",
		"hazard": "both", "spike_color": Color(0.95, 0.75, 0.35), "pool_color": Color(0.95, 0.55, 0.15), "pool_kind": "pool",
		"rooms": ["Cog Gate", "Gear Barracks", "Blueprint Archive", "Piston Armory", "Brass Vault", "Clockwork Throne"],
		"names": ["COG GATE", "STEAM TUNNELS", "THE GREAT FORGE", "PENDULUM HALL", "THE CLOCK TOWER"],
		"descs": ["A city of gears. Armoured sentries march on a schedule.", "Hot pipes and hissing steam. Spike plates click in the floor.",
			"The forge never sleeps. Brutes hammer, scouts watch.", "Giant pendulums swing over the halls. Time your moves.", "The clock tower. When it strikes midnight, the Emperor wakes."],
		"bosses": ["THE TINKERER", "THE COG KNIGHT", "THE STEAM BARON", "THE GREAT PENDULUM", "THE CLOCKWORK EMPEROR"],
		"kinds": ["grunt", "scout", "archer", "shield", "brute", "blinder"],
		"roster": {"grunt": ["knight", 2], "archer": ["knight", 2], "brute": ["golem", 1], "flyer": ["wasp", 1], "shield": ["knight", 2], "blinder": ["wraith", 1],
			"hound": ["hound", 0], "listener": ["skeleton", 1], "scout": ["knight", 2], "boss": ["knight", 2]},
		"summon": "scout", "favor": ["gallery", "zigzag", "corridor"], "bias": [0.20, 0.10, 0.20],
	},
	{
		"title": "CORAL ABYSS",
		"banner": Color(0.4, 0.9, 0.95), "ambient": Color(0.32, 0.5, 0.6), "floor": Color(0.1, 0.2, 0.26),
		"boss_floor": Color(0.08, 0.16, 0.24), "wall_dark": Color(0.02, 0.05, 0.08), "wall_trim": Color(0.4, 0.9, 0.95, 0.35),
		"torch": Color(0.5, 0.9, 1.0), "torch_boss": Color(0.3, 0.8, 1.0), "rune": Color(0.4, 0.9, 1.0, 0.22), "boss_rune": Color(0.3, 0.9, 1.0),
		"skin": "coral", "decor": "bubbles", "tex": "stone", "weather": "bubbles",
		"hazard": "pools", "spike_color": Color(0.5, 0.9, 1.0), "pool_color": Color(0.2, 0.6, 0.9), "pool_kind": "pool",
		"rooms": ["Reef Gate", "Sailor Barracks", "Sea Archive", "Anchor Armory", "Pearl Treasury", "Leviathan's Hall"],
		"names": ["SHIPWRECK SHALLOWS", "PEARL GARDENS", "DROWNED GALLEON", "THE KRAKEN'S DEN", "LEVIATHAN'S HEART"],
		"descs": ["A wrecked fleet on the sea floor. Bubbles rise from the dark.", "Coral gardens and pearl-eyed crabs. Ambushes in every cove.",
			"A drowned ship full of the dead. Blinders throw glowing orbs.", "Tentacles and teeth. Listeners guard the den.", "The great beast's lair. The tide pulls at your feet."],
		"bosses": ["THE TIDE CALLER", "THE PEARL DIVER", "THE KRAKEN'S HAND", "THE DROWNED ADMIRAL", "THE LEVIATHAN"],
		"kinds": ["grunt", "flyer", "hound", "blinder", "listener", "brute"],
		"roster": {"grunt": ["crab", 1], "archer": ["slime", 2], "brute": ["crab", 1], "flyer": ["vulture", 0], "shield": ["crab", 1], "blinder": ["ghost", 2],
			"hound": ["hound", 0], "listener": ["slime", 2], "scout": ["scorpion", 0], "boss": ["crab", 1]},
		"summon": "flyer", "favor": ["moat", "lava", "arena"], "bias": [0.35, 0.10, 0.10],
	},
	{
		"title": "FROSTPEAK",
		"banner": Color(0.7, 0.9, 1.0), "ambient": Color(0.5, 0.58, 0.7), "floor": Color(0.2, 0.26, 0.34),
		"boss_floor": Color(0.15, 0.2, 0.3), "wall_dark": Color(0.04, 0.06, 0.1), "wall_trim": Color(0.8, 0.95, 1.0, 0.35),
		"torch": Color(0.7, 0.85, 1.0), "torch_boss": Color(0.5, 0.8, 1.0), "rune": Color(0.7, 0.9, 1.0, 0.25), "boss_rune": Color(0.6, 0.9, 1.0),
		"skin": "ice", "decor": "frost", "tex": "ice", "weather": "snow",
		"hazard": "both", "spike_color": Color(0.8, 0.95, 1.0), "pool_color": Color(0.4, 0.7, 1.0), "pool_kind": "pool",
		"rooms": ["Snow Gate", "Trapper Barracks", "Frost Archive", "Icicle Armory", "Glacier Vault", "Winter Hall"],
		"names": ["BLIZZARD PASS", "YETI CAVES", "THE FROZEN LAKE", "AVALANCHE RIDGE", "THE WINTER THRONE"],
		"descs": ["A howling mountain pass. Hounds track you by scent.", "Caves full of shaggy yetis. They are huge but slow.",
			"The ice cracks under the lake. Archers watch from the shore.", "One loud noise could bring the mountain down. Scouts patrol the ridge.", "The Winter Queen's palace of ice."],
		"bosses": ["THE SNOW STALKER", "THE ICE HERMIT", "THE AVALANCHE", "THE FROST WYRM", "THE WINTER QUEEN"],
		"kinds": ["grunt", "hound", "brute", "archer", "scout", "blinder"],
		"roster": {"grunt": ["yeti", 0], "archer": ["skeleton", 2], "brute": ["yeti", 0], "flyer": ["bat", 2], "shield": ["yeti", 0], "blinder": ["wraith", 2],
			"hound": ["hound", 0], "listener": ["yeti", 0], "scout": ["hound", 0], "boss": ["yeti", 0]},
		"summon": "hound", "favor": ["hall", "arena", "cross"], "bias": [0.20, 0.20, 0.15],
	},
	{
		"title": "GILDED PALACE",
		"banner": Color(1.0, 0.85, 0.45), "ambient": Color(0.55, 0.48, 0.5), "floor": Color(0.28, 0.22, 0.22),
		"boss_floor": Color(0.32, 0.18, 0.12), "wall_dark": Color(0.08, 0.05, 0.05), "wall_trim": Color(1.0, 0.85, 0.4, 0.45),
		"torch": Color(1.0, 0.8, 0.45), "torch_boss": Color(1.0, 0.6, 0.3), "rune": Color(1.0, 0.85, 0.4, 0.25), "boss_rune": Color(1.0, 0.75, 0.3),
		"skin": "palace", "decor": "petals", "tex": "stone", "weather": "petals",
		"hazard": "spikes", "spike_color": Color(1.0, 0.85, 0.4), "pool_color": Color(0.9, 0.3, 0.3), "pool_kind": "pool",
		"rooms": ["Golden Gate", "Guard Barracks", "Royal Library", "Royal Armory", "Crown Treasury", "Gilded Throne Room"],
		"names": ["GOLDEN GATES", "MASQUERADE HALL", "THE ROYAL LIBRARY", "THE THRONE GALLERY", "THE GILDED THRONE"],
		"descs": ["A palace of gold, ruled by a tyrant. Shieldbearers line the gates.", "A masked ball of guards. Archers watch from the balconies.",
			"Marble shelves and silent halls. Blinders flash in the dark corners.", "Portraits with moving eyes. Scouts see everything.", "The tyrant's throne room. The Princess is close."],
		"bosses": ["THE COURT JESTER", "THE GILDED GUARD", "THE CROWN MINISTER", "THE MASKED DUKE", "THE GOLDEN TYRANT"],
		"kinds": ["grunt", "shield", "archer", "blinder", "scout", "listener"],
		"roster": {"grunt": ["knight", 3], "archer": ["skeleton", 1], "brute": ["golem", 1], "flyer": ["vulture", 0], "shield": ["knight", 3], "blinder": ["ghost", 1],
			"hound": ["hound", 0], "listener": ["skeleton", 1], "scout": ["knight", 3], "boss": ["skeleton", 1]},
		"summon": "shield", "favor": ["shrine", "vault", "gallery"], "bias": [0.15, 0.15, 0.30],
	},
	{
		"title": "NIGHT CITADEL",
		"banner": Color(0.6, 0.65, 1.0), "ambient": Color(0.24, 0.24, 0.38), "floor": Color(0.09, 0.09, 0.15),
		"boss_floor": Color(0.14, 0.08, 0.22), "wall_dark": Color(0.02, 0.02, 0.05), "wall_trim": Color(0.7, 0.75, 1.0, 0.4),
		"torch": Color(0.6, 0.65, 1.0), "torch_boss": Color(0.8, 0.4, 1.0), "rune": Color(0.6, 0.65, 1.0, 0.25), "boss_rune": Color(0.8, 0.4, 1.0),
		"skin": "obelisk", "decor": "void", "tex": "stone", "weather": "motes",
		"hazard": "both", "spike_color": Color(0.7, 0.75, 1.0), "pool_color": Color(0.6, 0.3, 1.0), "pool_kind": "pool",
		"rooms": ["Dusk Gate", "Shadow Barracks", "Star Archive", "Eclipse Armory", "Moon Treasury", "Night Throne Room"],
		"names": ["THE DUSK BRIDGE", "MOONLESS COURT", "THE STAR VAULT", "THE SHADOW STAIRS", "THE NIGHT THRONE"],
		"descs": ["The final fortress. A bridge of shadow over the void.", "No moon, no stars. Blinders and scouts own the court.",
			"The stolen stars are kept here. Listeners hear a heartbeat.", "A staircase with no end. Everything awake wants you.", "The Night King waits. This is the last fight."],
		"bosses": ["THE DUSK HERALD", "THE MOON EATER", "THE SHADOW TWIN", "THE NIGHT KNIGHT", "THE NIGHT KING"],
		"kinds": ["grunt", "blinder", "scout", "listener", "brute", "flyer"],
		"roster": {"grunt": ["imp", 3], "archer": ["skeleton", 3], "brute": ["golem", 3], "flyer": ["wraith", 3], "shield": ["knight", 3], "blinder": ["wraith", 3],
			"hound": ["hound", 0], "listener": ["ghost", 3], "scout": ["imp", 3], "boss": ["wraith", 3]},
		"summon": "blinder", "favor": ["dark", "shrine", "zigzag"], "bias": [0.25, 0.25, 0.20],
	},
]

const EVERY_KEYS: Dictionary = {
	"archer": "archer_every", "brute": "brute_every", "flyer": "flyer_every", "shield": "shield_every",
	"hound": "hound_every", "blinder": "blinder_every", "listener": "listener_every", "scout": "scout_every",
}
const EXTRA_LAYOUTS: Array[String] = ["B", "C", "D", "E", "F", "A", "B"]


static func world_count() -> int:
	return WORLDS.size()


## The 40 level dictionaries, easiest first.
static func build() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w in WORLDS.size():
		var wd: Dictionary = WORLDS[w]
		for s in 5:
			out.append(_level(w, s, wd))
	return out


static func _scale(c: Color, f: float) -> Color:
	return Color(c.r * f, c.g * f, c.b * f, c.a)


static func _level(w: int, s: int, wd: Dictionary) -> Dictionary:
	var d: int = w * 5 + s
	var t: float = float(d) / 39.0
	var kinds: Array = wd["kinds"]
	var avail: int = mini(kinds.size(), 2 + s)
	var shade: float = 1.0 - 0.03 * float(s)
	var lv: Dictionary = {}
	lv["name"] = String(wd["names"][s])
	lv["desc"] = String(wd["descs"][s])
	lv["world"] = w
	lv["world_name"] = String(wd["title"])
	lv["stage"] = s
	for k in ["banner", "boss_floor", "wall_dark", "wall_trim", "torch", "torch_boss", "rune", "boss_rune", "skin", "decor", "tex", "weather",
			"spike_color", "pool_color", "pool_kind", "rooms", "roster"]:
		lv[k] = wd[k]
	lv["ambient"] = _scale(wd["ambient"], shade)
	lv["floor"] = _scale(wd["floor"], shade)
	lv["wall_fill"] = _scale(wd["floor"], 0.9)
	lv["mirror"] = d % 4
	lv["hp"] = snappedf(1.0 + 3.2 * t, 0.01)
	lv["dmg"] = snappedf(1.0 + 2.4 * t, 0.01)
	lv["view"] = snappedf(1.0 + 0.55 * t, 0.01)
	lv["spd"] = snappedf(1.0 + 0.30 * t, 0.01)
	lv["coin"] = 5 + int(52.0 * t)
	lv["heart"] = 30 - int(10.0 * t)
	lv["hazard"] = "none" if d < 3 else String(wd["hazard"])
	lv["hazard_dmg"] = 8 + int(20.0 * t)
	for kk in EVERY_KEYS:
		lv[EVERY_KEYS[kk]] = 0
	for i in avail:
		var kn: String = kinds[i]
		if EVERY_KEYS.has(kn):
			lv[EVERY_KEYS[kn]] = 3
	lv["signature"] = String(kinds[s % avail])
	lv["room_bonus"] = d / 10
	lv["favor"] = wd["favor"]
	lv["bias"] = wd["bias"]
	# extra guards from patrol routes of layouts A-F
	var extras: Array = []
	var n_ex: int = clampi(s / 2 + w / 2 + (1 if d >= 5 else 0), 0, 6)
	for i in n_ex:
		extras.append([EXTRA_LAYOUTS[i % EXTRA_LAYOUTS.size()], String(kinds[(i + s) % avail])])
	lv["extras"] = extras
	# twists: bells every 4th level, a timer every 7th
	if d % 4 == 3:
		lv["bells"] = 2 + w / 3
	if d >= 6 and d % 7 == 6:
		lv["time_limit"] = 520 - (d / 7) * 20
	# boss
	var burst: int = 0 if d < 4 else 6 + int(18.0 * t)
	var summon: String = String(wd["summon"]) if s >= 3 else ""
	lv["boss"] = {"name": String(wd["bosses"][s]), "hp": 240 + int(2100.0 * t), "dmg": 18 + int(38.0 * t),
			"speed": 150.0 + 65.0 * t, "burst": burst, "summon": summon}
	return lv
