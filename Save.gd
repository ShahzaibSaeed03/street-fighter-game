extends RefCounted
## Save.gd — progress that survives restarts: coins, unlocked levels, owned/equipped items.
## Stored in user://dungeon_sneak.cfg. Everything is static, so any script can use Save.coins etc.

const PATH := "user://dungeon_sneak.cfg"

static var coins: int = 0
static var unlocked: int = 0                    # highest level index you may play (0 = only level 1)
static var best: Dictionary = {}                # "0" -> {"stars": 3, "time": 120.0}
static var owned: Array = ["sword:rusty", "suit:tunic", "bow:short"]
static var equipped: Dictionary = {"sword": "rusty", "suit": "tunic", "bow": "short"}
static var vitality: int = 0
static var _loaded: bool = false


static func ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	coins = int(cfg.get_value("save", "coins", 0))
	unlocked = int(cfg.get_value("save", "unlocked", 0))
	vitality = int(cfg.get_value("save", "vitality", 0))
	var b: Variant = cfg.get_value("save", "best", {})
	if b is Dictionary:
		best = b
	var o: Variant = cfg.get_value("save", "owned", owned)
	if o is Array:
		owned = o
	var e: Variant = cfg.get_value("save", "equipped", equipped)
	if e is Dictionary:
		equipped = e


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("save", "coins", coins)
	cfg.set_value("save", "unlocked", unlocked)
	cfg.set_value("save", "vitality", vitality)
	cfg.set_value("save", "best", best)
	cfg.set_value("save", "owned", owned)
	cfg.set_value("save", "equipped", equipped)
	cfg.save(PATH)


static func owns(slot: String, id: String) -> bool:
	ensure()
	return owned.has("%s:%s" % [slot, id])


static func buy(slot: String, id: String, price: int) -> bool:
	ensure()
	if owns(slot, id) or coins < price:
		return false
	coins -= price
	owned.append("%s:%s" % [slot, id])
	equipped[slot] = id
	save()
	return true


static func equip(slot: String, id: String) -> void:
	ensure()
	if owns(slot, id):
		equipped[slot] = id
		save()


static func buy_vitality(price: int) -> bool:
	ensure()
	if coins < price or vitality >= 5:
		return false
	coins -= price
	vitality += 1
	save()
	return true


static func record_clear(level: int, time: float, stars: int, last_level: int) -> void:
	ensure()
	var key := str(level)
	var old: Dictionary = best.get(key, {})
	var old_stars: int = int(old.get("stars", 0))
	var old_time: float = float(old.get("time", 99999.0))
	best[key] = {"stars": maxi(stars, old_stars), "time": minf(time, old_time)}
	unlocked = clampi(maxi(unlocked, level + 1), 0, last_level)
	save()
