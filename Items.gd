extends RefCounted
## Items.gd — shop catalogue: swords, suits (armor), bows and upgrades.

const HeroesScript := preload("res://Heroes.gd")

const SWORDS: Array[Dictionary] = [
	{"id": "skull", "name": "Skull Cleaver", "price": 0, "dmg": 40, "cd": 0.34, "range": 66.0, "sprite": "res://assets/weapons/w0.png", "blade": Color(0.5, 0.9, 0.5), "desc": "The starter blade. Heavy skull-tipped cleaver."},
	{"id": "crystal", "name": "Crystal Shard", "price": 600, "dmg": 52, "cd": 0.32, "range": 66.0, "sprite": "res://assets/weapons/w1.png", "blade": Color(0.8, 0.9, 1.0), "desc": "Pale crystal edge. Much harder hits."},
	{"id": "bone", "name": "Bone Crescent", "price": 1000, "dmg": 62, "cd": 0.31, "range": 70.0, "sprite": "res://assets/weapons/w2.png", "blade": Color(0.9, 0.7, 1.0), "desc": "Crescent blade. Fast and strong."},
	{"id": "claw", "name": "Claw Sickle", "price": 1400, "dmg": 74, "cd": 0.30, "range": 68.0, "sprite": "res://assets/weapons/w3.png", "blade": Color(0.7, 0.7, 0.75), "desc": "Hooked blade that tears armour."},
	{"id": "frostlong", "name": "Frost Longsword", "price": 1900, "dmg": 86, "cd": 0.29, "range": 74.0, "sprite": "res://assets/weapons/w4.png", "blade": Color(0.7, 1.4, 2.0), "desc": "Long icy blade with great reach."},
	{"id": "arcane", "name": "Arcane Wand", "price": 0, "unlock": "untouched", "dmg": 66, "cd": 0.30, "range": 70.0, "sprite": "res://assets/weapons/w5.png", "blade": Color(1.3, 0.6, 1.9), "desc": "Unlocked by the Untouchable challenge."},
	{"id": "jade", "name": "Jade Edge", "price": 0, "unlock": "swift", "dmg": 58, "cd": 0.24, "range": 66.0, "sprite": "res://assets/weapons/w6.png", "blade": Color(0.5, 1.2, 0.8), "desc": "Unlocked by the Swift challenge. Very fast."},
	{"id": "halberd", "name": "Royal Halberd", "price": 0, "unlock": "boss_slayer", "dmg": 96, "cd": 0.36, "range": 84.0, "sprite": "res://assets/weapons/w7.png", "blade": Color(0.9, 0.9, 1.1), "desc": "Unlocked by Boss Slayer, or the Warden's Bane mission."},
	{"id": "greatblade", "name": "Shadow Greatblade", "price": 0, "unlock": "ghost", "dmg": 90, "cd": 0.33, "range": 76.0, "sprite": "res://assets/weapons/w8.png", "blade": Color(0.3, 0.2, 0.4), "desc": "Unlocked by the Ghost challenge, or the Perfectionist mission."},
	{"id": "emerald", "name": "Emerald Edge", "price": 0, "unlock": "shadow_hand", "dmg": 80, "cd": 0.28, "range": 72.0, "sprite": "res://assets/weapons/w9.png", "blade": Color(0.4, 1.4, 0.8), "desc": "Unlocked by Shadow Hand, or the Ghost Blade mission."},
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
	{"id": "ghost", "name": "Ghost Cloak", "price": 0, "unlock": "ghost", "dmg": 0.8, "spd": 1.1, "noise": 0.4,
		"steel": Color(0.85, 0.9, 1.0), "steel_dark": Color(0.4, 0.45, 0.55), "gold": Color(0.9, 0.95, 1.0),
		"cape": Color(0.5, 0.55, 0.7), "desc": "Unlocked by the Ghost challenge. Very quiet and fast."},
	{"id": "veil", "name": "Veilwalker Cloak", "price": 1600, "dmg": 0.85, "spd": 1.03, "noise": 0.6, "ability": "veil",
		"steel": Color(0.2, 0.36, 0.32), "steel_dark": Color(0.08, 0.14, 0.13), "gold": Color(0.5, 0.95, 0.85),
		"cape": Color(0.1, 0.26, 0.22), "desc": "VEIL: inside a curtain no guard can see you unless they touch you. Quieter steps, 15% less damage."},
	{"id": "ironvow", "name": "Ironvow Mail", "price": 0, "unlock": "untouched", "dmg": 0.55, "spd": 0.97, "noise": 1.0,
		"steel": Color(0.5, 0.55, 0.6), "steel_dark": Color(0.2, 0.22, 0.26), "gold": Color(0.7, 0.7, 0.6),
		"cape": Color(0.3, 0.3, 0.35), "desc": "Unlocked by the Untouchable challenge. 45% less damage."},
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
	{"id": "silent", "name": "Silent Bow", "price": 0, "unlock": "shadow_hand", "dmg": 26, "cd": 0.40, "ammo": 20, "speed": 760.0, "pierce": 0,
		"color": Color(0.7, 1.0, 1.6), "desc": "Unlocked by the Shadow Hand challenge. 20 arrows."},
]

const VITALITY_PRICES: Array[int] = [150, 300, 500, 800, 1200]
const VITALITY_HP := 20


static func list_for(slot: String) -> Array[Dictionary]:
	if slot == "sword":
		return SWORDS
	if slot == "suit":
		return SUITS
	if slot == "hero":
		return HeroesScript.LIST
	return BOWS


static func find(slot: String, id: String) -> Dictionary:
	for it in list_for(slot):
		if it["id"] == id:
			return it
	return list_for(slot)[0]
