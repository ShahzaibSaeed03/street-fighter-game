extends RefCounted
## Save.gd — progress that survives restarts: coins, unlocked levels, owned/equipped items.
## Stored in user://dungeon_sneak.cfg. Everything is static, so any script can use Save.coins etc.

const PATH := "user://dungeon_sneak.cfg"

static var coins: int = 0
static var unlocked: int = 0                    # highest level index you may play (0 = only level 1)
static var best: Dictionary = {}                # "0" -> {"stars": 3, "time": 120.0}
static var owned: Array = ["sword:skull", "suit:tunic", "bow:short", "hero:ayaan"]
static var equipped: Dictionary = {"sword": "skull", "suit": "tunic", "bow": "short", "hero": "ayaan"}
static var mstats: Dictionary = {}
static var claimed: Array = []
static var vitality: int = 0
static var _loaded: bool = false
static var xp: int = 0
static var level: int = 1
static var pending_perks: int = 0
static var perks: Array = []
static var challenges_done: Array = []
static var bosses: int = 0
static var speed_pref: int = 1                  # 0 slow, 1 normal, 2 fast (see Tuning.gd)


static func ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	coins = int(cfg.get_value("save", "coins", 0))
	unlocked = int(cfg.get_value("save", "unlocked", 0))
	speed_pref = clampi(int(cfg.get_value("save", "speed_pref", 1)), 0, 2)
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
	xp = int(cfg.get_value("save", "xp", 0))
	level = int(cfg.get_value("save", "level", 1))
	pending_perks = int(cfg.get_value("save", "pending_perks", 0))
	if not owned.has("sword:skull"):
		owned.append("sword:skull")
	if String(equipped.get("sword", "")) == "rusty" or not equipped.has("sword"):
		equipped["sword"] = "skull"
	if not equipped.has("hero"):
		equipped["hero"] = "ayaan"
	if not owned.has("hero:ayaan"):
		owned.append("hero:ayaan")
	var ms: Variant = cfg.get_value("save", "mstats", {})
	if ms is Dictionary:
		mstats = ms
	var cl: Variant = cfg.get_value("save", "claimed", [])
	if cl is Array:
		claimed = cl
	var pk: Variant = cfg.get_value("save", "perks", [])
	if pk is Array:
		perks = pk
	var cd: Variant = cfg.get_value("save", "challenges_done", [])
	if cd is Array:
		challenges_done = cd
	bosses = int(cfg.get_value("save", "bosses", 0))


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("save", "coins", coins)
	cfg.set_value("save", "unlocked", unlocked)
	cfg.set_value("save", "speed_pref", speed_pref)
	cfg.set_value("save", "vitality", vitality)
	cfg.set_value("save", "best", best)
	cfg.set_value("save", "mstats", mstats)
	cfg.set_value("save", "claimed", claimed)
	cfg.set_value("save", "owned", owned)
	cfg.set_value("save", "equipped", equipped)
	cfg.set_value("save", "xp", xp)
	cfg.set_value("save", "level", level)
	cfg.set_value("save", "pending_perks", pending_perks)
	cfg.set_value("save", "perks", perks)
	cfg.set_value("save", "challenges_done", challenges_done)
	cfg.set_value("save", "bosses", bosses)
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
