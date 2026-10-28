class_name Progression
extends RefCounted
## Progression.gd: XP, player levels, perks and challenges.
## The saved values live in Save.gd (XP, level, perks, challenges done, boss count).

const SaveScript := preload("res://Save.gd")
const ItemsScript := preload("res://Items.gd")

const PERKS: Array[Dictionary] = [
	{"id": "light_feet", "name": "Light Feet", "desc": "Guards hear you 25% less when you move."},
	{"id": "quick_roll", "name": "Quick Roll", "desc": "Roll cooldown is 40% shorter."},
	{"id": "eagle_eye", "name": "Eagle Eye", "desc": "Arrows fly 25% faster."},
	{"id": "second_wind", "name": "Second Wind", "desc": "Each guard you kill heals you 8 HP."},
	{"id": "shield_breaker", "name": "Shield Breaker", "desc": "Shieldbearers take half damage from the front."},
	{"id": "iron_skin", "name": "Iron Skin", "desc": "+25 max HP."},
]

const CHALLENGES: Array[Dictionary] = [
	{"id": "ghost", "name": "Ghost", "desc": "Clear a level without being spotted.", "xp": 80, "coins": 150},
	{"id": "shadow_hand", "name": "Shadow Hand", "desc": "Make 5 silent kills in one level.", "xp": 60, "coins": 100},
	{"id": "untouched", "name": "Untouchable", "desc": "Clear a level without taking damage.", "xp": 100, "coins": 200},
	{"id": "swift", "name": "Swift", "desc": "Clear a level in under 4 minutes.", "xp": 60, "coins": 120},
	{"id": "boss_slayer", "name": "Boss Slayer", "desc": "Defeat 5 bosses in total.", "xp": 120, "coins": 250},
]

const KILL_XP := 10
const SILENT_BONUS_XP := 5
const BOSS_XP := 150
const CLEAR_XP := 100


static func xp_needed(lvl: int) -> int:
	return 100 + (lvl - 1) * 40


static func has_perk(id: String) -> bool:
	SaveScript.ensure()
	return SaveScript.perks.has(id)


## Adds XP and returns how many player levels were gained.
static func add_xp(amount: int) -> int:
	SaveScript.ensure()
	SaveScript.xp += amount
	var gained := 0
	while SaveScript.xp >= xp_needed(SaveScript.level):
		SaveScript.xp -= xp_needed(SaveScript.level)
		SaveScript.level += 1
		SaveScript.pending_perks += 1
		gained += 1
	return gained


## Three perks the player does not own yet (fewer if the pool is nearly empty).
static func perk_choices() -> Array[Dictionary]:
	SaveScript.ensure()
	var pool: Array[Dictionary] = []
	for p in PERKS:
		if not SaveScript.perks.has(p["id"]):
			pool.append(p)
	pool.shuffle()
	var out: Array[Dictionary] = []
	for i in mini(3, pool.size()):
		out.append(pool[i])
	return out


static func choose_perk(id: String) -> void:
	SaveScript.ensure()
	if SaveScript.perks.has(id):
		return
	SaveScript.perks.append(id)
	SaveScript.pending_perks = maxi(0, SaveScript.pending_perks - 1)
	SaveScript.save()


## Checks every not-yet-finished challenge against the level stats.
## Rewards are paid here; returns the challenges completed by this call.
## stats: alerts, shadow_kills, damage_taken, time, bosses
static func evaluate(stats: Dictionary) -> Array[Dictionary]:
	SaveScript.ensure()
	var done: Array[Dictionary] = []
	for c in CHALLENGES:
		var id: String = c["id"]
		if SaveScript.challenges_done.has(id):
			continue
		var ok := false
		match id:
			"ghost":
				ok = int(stats["alerts"]) == 0
			"shadow_hand":
				ok = int(stats["shadow_kills"]) >= 5
			"untouched":
				ok = int(stats["damage_taken"]) == 0
			"swift":
				ok = float(stats["time"]) < 240.0
			"boss_slayer":
				ok = int(stats["bosses"]) >= 5
		if ok:
			SaveScript.challenges_done.append(id)
			SaveScript.coins += int(c["coins"])
			add_xp(int(c["xp"]))
			for g in gear_for(id):
				var key := "%s:%s" % [g["slot"], g["id"]]
				if not SaveScript.owned.has(key):
					SaveScript.owned.append(key)
			done.append(c)
	SaveScript.save()
	return done


## The gear item unlocked by a challenge, or {} if it unlocks none.
static func gear_for(challenge_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot in ["sword", "suit", "bow"]:
		for it in ItemsScript.list_for(slot):
			if String(it.get("unlock", "")) == challenge_id:
				out.append({"slot": slot, "id": it["id"], "name": it["name"]})
	return out


static func challenge_name(challenge_id: String) -> String:
	for c in CHALLENGES:
		if c["id"] == challenge_id:
			return String(c["name"])
	return challenge_id
