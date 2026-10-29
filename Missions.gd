class_name Missions
extends RefCounted
## Missions.gd: missions that pay coins (normal) or a sword gift (hard). Progress lives in Save.gd (mstats).

const SaveScript := preload("res://Save.gd")
const ItemsScript := preload("res://Items.gd")

const LIST: Array[Dictionary] = [
	{"id": "k20", "name": "Guard Hunter", "desc": "Defeat 20 guards.", "kind": "coins", "stat": "kills", "goal": 20, "reward": 150},
	{"id": "s10", "name": "Shadow Walker", "desc": "Make 10 silent kills.", "kind": "coins", "stat": "silent", "goal": 10, "reward": 150},
	{"id": "l3", "name": "Explorer", "desc": "Clear 3 levels.", "kind": "coins", "stat": "levels", "goal": 3, "reward": 200},
	{"id": "b1", "name": "Boss Breaker", "desc": "Defeat 1 boss.", "kind": "coins", "stat": "bosses", "goal": 1, "reward": 250},
	{"id": "bell5", "name": "Bell Ringer", "desc": "Ring 5 bells to lure guards away.", "kind": "coins", "stat": "bells", "goal": 5, "reward": 200},
	{"id": "sl10", "name": "Dream Thief", "desc": "Stab 10 sleeping guards.", "kind": "coins", "stat": "sleepers", "goal": 10, "reward": 250},
	{"id": "pu8", "name": "Orb Collector", "desc": "Collect 8 power-up orbs.", "kind": "coins", "stat": "powerups", "goal": 8, "reward": 200},
	{"id": "sec5", "name": "Treasure Hunter", "desc": "Find 5 hidden rooms behind curtains.", "kind": "coins", "stat": "secrets", "goal": 5, "reward": 300},
	{"id": "el5", "name": "Elite Hunter", "desc": "Defeat 5 ELITE guards.", "kind": "coins", "stat": "elites", "goal": 5, "reward": 350},
	{"id": "k100", "name": "Guard Slayer", "desc": "Defeat 100 guards.", "kind": "coins", "stat": "kills", "goal": 100, "reward": 400},
	{"id": "s30", "name": "Silent Storm", "desc": "Make 30 silent kills.", "kind": "coins", "stat": "silent", "goal": 30, "reward": 300},
	{"id": "l10", "name": "Traveler", "desc": "Clear 10 levels.", "kind": "coins", "stat": "levels", "goal": 10, "reward": 400},
	{"id": "w1", "name": "World Walker", "desc": "Clear every level of one world.", "kind": "coins", "stat": "worlds", "goal": 1, "reward": 400},
	{"id": "b10", "name": "Boss Hunter", "desc": "Defeat 10 bosses.", "kind": "coins", "stat": "bosses", "goal": 10, "reward": 500},
	{"id": "st30", "name": "Star Collector", "desc": "Earn 30 stars in total.", "kind": "coins", "stat": "stars", "goal": 30, "reward": 500},
	{"id": "l25", "name": "Wanderer", "desc": "Clear 25 levels.", "kind": "coins", "stat": "levels", "goal": 25, "reward": 700},
	{"id": "h_bosses", "name": "Warden's Bane", "desc": "Defeat 3 bosses.", "kind": "hard", "stat": "bosses", "goal": 3, "gift": "halberd"},
	{"id": "h_silent", "name": "Ghost Blade", "desc": "Make 40 silent kills.", "kind": "hard", "stat": "silent", "goal": 40, "gift": "emerald"},
	{"id": "h_perfect", "name": "Perfectionist", "desc": "Clear 6 levels with 3 stars each.", "kind": "hard", "stat": "perfect", "goal": 6, "gift": "greatblade"},
	{"id": "h_worlds", "name": "World Breaker", "desc": "Clear every level of 4 worlds.", "kind": "hard", "stat": "worlds", "goal": 4, "gift": "frostlong"},
	{"id": "h_giant", "name": "Giant Slayer", "desc": "Defeat 25 bosses.", "kind": "hard", "stat": "bosses", "goal": 25, "gift": "claw"},
	{"id": "h_stars", "name": "Star Master", "desc": "Earn 90 stars in total.", "kind": "hard", "stat": "stars", "goal": 90, "gift": "jade"},
	{"id": "h_final", "name": "Night's End", "desc": "Clear all 40 levels.", "kind": "hard", "stat": "levels", "goal": 40, "gift": "arcane"},
]


## Current value of the stat a mission tracks.
static func progress(stat: String) -> int:
	SaveScript.ensure()
	match stat:
		"kills", "silent", "levels", "bells", "sleepers", "powerups", "secrets", "elites":
			return int(SaveScript.mstats.get(stat, 0))
		"stars":
			var total := 0
			for k2 in SaveScript.best:
				total += int(SaveScript.best[k2].get("stars", 0))
			return total
		"worlds":
			var done := 0
			for w in 8:
				var all_ok := true
				for i in 5:
					if int(SaveScript.best.get(str(w * 5 + i), {}).get("stars", 0)) <= 0:
						all_ok = false
						break
				if all_ok:
					done += 1
			return done
		"bosses":
			return SaveScript.bosses
		"perfect":
			var n := 0
			for k in SaveScript.best:
				if int(SaveScript.best[k].get("stars", 0)) >= 3:
					n += 1
			return n
	return 0


## Adds to a tracked stat. Saved together with the level result (Save.save).
static func add(stat: String, n: int = 1) -> void:
	SaveScript.ensure()
	SaveScript.mstats[stat] = int(SaveScript.mstats.get(stat, 0)) + n


static func is_claimed(id: String) -> bool:
	SaveScript.ensure()
	return SaveScript.claimed.has(id)


static func is_ready(m: Dictionary) -> bool:
	return not is_claimed(String(m["id"])) and progress(String(m["stat"])) >= int(m["goal"])


## Pays out a finished mission. Returns the message to show, or "" if nothing was paid.
static func claim(id: String) -> String:
	SaveScript.ensure()
	for m in LIST:
		if m["id"] != id or not is_ready(m):
			continue
		SaveScript.claimed.append(id)
		if m["kind"] == "coins":
			SaveScript.coins += int(m["reward"])
			SaveScript.save()
			return "Mission complete!  +%d coins" % int(m["reward"])
		var key := "sword:%s" % String(m["gift"])
		if not SaveScript.owned.has(key):
			SaveScript.owned.append(key)
		SaveScript.save()
		return "Hard mission complete!  New sword: %s" % String(ItemsScript.find("sword", String(m["gift"]))["name"])
	return ""
