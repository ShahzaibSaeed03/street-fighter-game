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
	{"id": "h_bosses", "name": "Warden's Bane", "desc": "Defeat 3 bosses.", "kind": "hard", "stat": "bosses", "goal": 3, "gift": "halberd"},
	{"id": "h_silent", "name": "Ghost Blade", "desc": "Make 40 silent kills.", "kind": "hard", "stat": "silent", "goal": 40, "gift": "emerald"},
	{"id": "h_perfect", "name": "Perfectionist", "desc": "Clear 6 levels with 3 stars each.", "kind": "hard", "stat": "perfect", "goal": 6, "gift": "greatblade"},
]


## Current value of the stat a mission tracks.
static func progress(stat: String) -> int:
	SaveScript.ensure()
	match stat:
		"kills", "silent", "levels":
			return int(SaveScript.mstats.get(stat, 0))
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
