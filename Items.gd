extends RefCounted
## Items.gd — shop catalogue: swords, suits (armor), bows and upgrades.

const SWORDS: Array[Dictionary] = [
	{"id": "rusty", "name": "Rusty Sword", "price": 0, "dmg": 16, "cd": 0.35, "range": 60.0,
		"blade": Color(0.82, 0.87, 0.95), "desc": "A plain starter blade."},
	{"id": "steel", "name": "Steel Sword", "price": 150, "dmg": 22, "cd": 0.33, "range": 62.0,
		"blade": Color(0.92, 0.95, 1.0), "desc": "Well balanced. Hits harder."},
	{"id": "flame", "name": "Flame Blade", "price": 450, "dmg": 30, "cd": 0.31, "range": 66.0,
		"blade": Color(1.9, 0.8, 0.25), "desc": "Burning edge, longer reach."},
	{"id": "frost", "name": "Frostbrand", "price": 900, "dmg": 38, "cd": 0.30, "range": 68.0,
		"blade": Color(0.7, 1.6, 2.1), "desc": "Cold steel, fast and deadly."},
	{"id": "shadow", "name": "Shadow Reaper", "price": 1800, "dmg": 50, "cd": 0.27, "range": 74.0,
		"blade": Color(1.5, 0.5, 2.0), "desc": "Cuts through almost anything."},
]

## armor: dmg = damage taken multiplier, spd = move speed multiplier, noise = footstep noise multiplier
const SUITS: Array[Dictionary] = [
	{"id": "tunic", "name": "Traveler's Tunic", "price": 0, "dmg": 1.0, "spd": 1.0, "noise": 1.0,
		"steel": Color(0.60, 0.65, 0.74), "steel_dark": Color(0.26, 0.29, 0.37), "gold": Color(0.93, 0.74, 0.30),
		"cape": Color(0.66, 0.10, 0.15), "desc": "Basic gear. No bonuses."},
	{"id": "leather", "name": "Leather Armor", "price": 200, "dmg": 0.9, "spd": 1.0, "noise": 1.0,
		"steel": Color(0.55, 0.38, 0.22), "steel_dark": Color(0.28, 0.18, 0.10), "gold": Color(0.75, 0.6, 0.3),
		"cape": Color(0.35, 0.22, 0.12), "desc": "10% less damage taken."},
	{"id": "chain", "name": "Chainmail", "price": 500, "dmg": 0.8, "spd": 1.0, "noise": 1.0,
		"steel": Color(0.72, 0.75, 0.80), "steel_dark": Color(0.30, 0.33, 0.38), "gold": Color(0.8, 0.8, 0.85),
		"cape": Color(0.15, 0.25, 0.5), "desc": "20% less damage taken."},
	{"id": "assassin", "name": "Assassin Cloak", "price": 900, "dmg": 0.85, "spd": 1.05, "noise": 0.55,
		"steel": Color(0.22, 0.22, 0.28), "steel_dark": Color(0.08, 0.08, 0.12), "gold": Color(0.55, 0.3, 0.8),
		"cape": Color(0.12, 0.08, 0.2), "desc": "Quieter steps, faster, 15% less damage."},
	{"id": "knight", "name": "Knight Plate", "price": 1000, "dmg": 0.7, "spd": 0.96, "noise": 1.0,
		"steel": Color(0.85, 0.88, 0.95), "steel_dark": Color(0.35, 0.38, 0.46), "gold": Color(1.0, 0.82, 0.35),
		"cape": Color(0.1, 0.2, 0.6), "desc": "30% less damage taken (a bit heavy)."},
	{"id": "dragon", "name": "Dragon Armor", "price": 2200, "dmg": 0.6, "spd": 1.04, "noise": 1.0,
		"steel": Color(0.75, 0.2, 0.15), "steel_dark": Color(0.3, 0.07, 0.06), "gold": Color(1.0, 0.7, 0.2),
		"cape": Color(0.2, 0.04, 0.04), "desc": "40% less damage taken and faster."},
]

const BOWS: Array[Dictionary] = [
	{"id": "short", "name": "Short Bow", "price": 0, "dmg": 14, "cd": 0.50, "ammo": 12, "speed": 600.0, "pierce": 0,
		"color": Color(1.4, 1.3, 1.0), "desc": "Starter bow. 12 arrows."},
	{"id": "long", "name": "Long Bow", "price": 300, "dmg": 22, "cd": 0.45, "ammo": 18, "speed": 700.0, "pierce": 0,
		"color": Color(1.5, 1.5, 1.1), "desc": "More damage, 18 arrows."},
	{"id": "fire", "name": "Fire Bow", "price": 800, "dmg": 30, "cd": 0.42, "ammo": 24, "speed": 760.0, "pierce": 0,
		"color": Color(2.0, 0.8, 0.2), "desc": "Flaming arrows, 24 arrows."},
	{"id": "shadow", "name": "Shadow Bow", "price": 1600, "dmg": 40, "cd": 0.38, "ammo": 30, "speed": 820.0, "pierce": 1,
		"color": Color(1.6, 0.5, 2.0), "desc": "Arrows pierce one enemy. 30 arrows."},
]

const VITALITY_PRICES: Array[int] = [150, 300, 500, 800, 1200]
const VITALITY_HP := 20


static func list_for(slot: String) -> Array[Dictionary]:
	if slot == "sword":
		return SWORDS
	if slot == "suit":
		return SUITS
	return BOWS


static func find(slot: String, id: String) -> Dictionary:
	for it in list_for(slot):
		if it["id"] == id:
			return it
	return list_for(slot)[0]
