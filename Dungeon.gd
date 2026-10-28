extends Node2D
## Dungeon.gd — builds the six rooms, walls, doors, props, guards, hearts and keys from code.
## Rooms are laid out on a grid, one screen (1152 x 648) each:
##
##        [C Archive]   [E Treasury]
##  [A Hall]-[B Barracks]-[D Armory]-[F Boss]
##
## Group "arena" (blood splats). The camera in Game.gd snaps to the room the player is in.

signal guard_died(guard: Node2D, stealth: bool)

const Fx := preload("res://Fx.gd")
const GuardScript := preload("res://Guard.gd")
const DoorScript := preload("res://Door.gd")
const KeyScript := preload("res://KeyPickup.gd")
const PickupScript := preload("res://Pickup.gd")
const HazardScript := preload("res://Hazard.gd")
const LevelsScript := preload("res://Levels.gd")
const LootScript := preload("res://Loot.gd")
const TexturesScript := preload("res://Textures.gd")

const RW := 1152.0
const RH := 648.0
const WALL := 36.0
const GAP := 150.0
const TILE := 64

## Prop look per level theme: base kind -> drawn kind.
const SKINS: Dictionary = {
	"stone": {},
	"tomb": {"crate": "tomb", "rack": "tomb", "shelf": "bones"},
	"ice": {"crate": "ice", "pillar": "ice", "shelf": "ice", "rack": "ice"},
	"forge": {"crate": "forge", "shelf": "forge", "rack": "forge", "pillar": "hotpillar"},
	"obelisk": {"crate": "obelisk", "pillar": "obelisk", "shelf": "obelisk", "rack": "obelisk"},
	"jungle": {"crate": "bush", "pillar": "tree", "shelf": "hedge", "rack": "hedge"},
	"desert": {"crate": "cactus", "pillar": "sandpillar", "shelf": "sandrock", "rack": "sandrock"},
}

## Where coins (4 per room) and an arrow bundle lie (room-local coordinates).
const COIN_SPOTS: Array = [Vector2(150, 130), Vector2(1000, 130), Vector2(150, 520), Vector2(1000, 520)]
const ARROW_SPOT := Vector2(576, 596)

## Floor traps (room id, x, y, w, h in room-local coordinates).
const SPIKES: Array = [
	["A", 840.0, 294.0, 64.0, 60.0],
	["B", 480.0, 150.0, 60.0, 60.0], ["B", 612.0, 150.0, 60.0, 60.0],
	["B", 480.0, 438.0, 60.0, 60.0], ["B", 612.0, 438.0, 60.0, 60.0],
	["C", 250.0, 250.0, 60.0, 60.0], ["C", 470.0, 300.0, 60.0, 60.0],
	["C", 680.0, 250.0, 60.0, 60.0], ["C", 900.0, 300.0, 60.0, 60.0],
	["D", 540.0, 180.0, 70.0, 60.0], ["D", 540.0, 408.0, 70.0, 60.0],
	["E", 480.0, 160.0, 60.0, 60.0], ["E", 612.0, 160.0, 60.0, 60.0],
	["F", 200.0, 150.0, 60.0, 60.0], ["F", 200.0, 440.0, 60.0, 60.0],
]
## Lava / void pools.
const POOLS: Array = [
	["A", 820.0, 150.0, 120.0, 70.0], ["A", 820.0, 430.0, 120.0, 70.0],
	["B", 470.0, 448.0, 210.0, 80.0],
	["C", 250.0, 330.0, 80.0, 70.0],
	["D", 500.0, 196.0, 150.0, 70.0], ["D", 500.0, 382.0, 150.0, 70.0],
	["E", 330.0, 190.0, 150.0, 60.0], ["E", 672.0, 190.0, 150.0, 60.0],
	["F", 250.0, 270.0, 120.0, 110.0],
]

const ROOMS: Array[Dictionary] = [
	{"id": "A", "cell": Vector2i(0, 1), "name": "Entrance Hall", "tint": Color(0.19, 0.20, 0.25)},
	{"id": "B", "cell": Vector2i(1, 1), "name": "Barracks", "tint": Color(0.22, 0.19, 0.20)},
	{"id": "C", "cell": Vector2i(1, 0), "name": "Archive", "tint": Color(0.17, 0.20, 0.24)},
	{"id": "D", "cell": Vector2i(2, 1), "name": "Armory", "tint": Color(0.23, 0.20, 0.17)},
	{"id": "E", "cell": Vector2i(2, 0), "name": "Treasury", "tint": Color(0.20, 0.18, 0.25)},
	{"id": "F", "cell": Vector2i(3, 1), "name": "Boss Chamber", "tint": Color(0.26, 0.15, 0.16)},
]
const DOORS: Array[Dictionary] = [
	{"a": "A", "b": "B", "key": ""},
	{"a": "B", "b": "C", "key": ""},
	{"a": "B", "b": "D", "key": "bronze"},
	{"a": "D", "b": "E", "key": ""},
	{"a": "D", "b": "F", "key": "gold"},
]

var _cells: Dictionary = {}          # id -> Vector2i
var _names: Dictionary = {}          # id -> String
var _tints: Dictionary = {}          # id -> Color
var _by_cell: Dictionary = {}        # Vector2i -> id
var _sides: Dictionary = {}          # id -> {"N": true, ...} door openings
var _obstacles: Array[Dictionary] = []   # {"r": Rect2 (world), "k": String}
var _shades: Dictionary = {}         # id -> Array[float]
var _cracks: Array[PackedVector2Array] = []
var _splats: Array[Dictionary] = []
var _torches: Array[Vector2] = []
var _lights: Array[PointLight2D] = []
var _flames: Node2D
var _time: float = 0.0
var level_idx: int = 0
var _lv: Dictionary = {}
var _mx: bool = false
var _my: bool = false
var _decor: Array[Dictionary] = []
var _floor_tex: CanvasTexture
var _wall_tex: Texture2D
var _gi: int = 0


# ------------------------------------------------------------------ lookups
func cell_of(id: String) -> Vector2i:
	return _cells[id]


func room_name(id: String) -> String:
	return _names.get(id, "")


func origin_of(id: String) -> Vector2:
	var c: Vector2i = _cells[id]
	return Vector2(float(c.x) * RW, float(c.y) * RH)


func room_center(id: String) -> Vector2:
	return origin_of(id) + Vector2(RW, RH) * 0.5


func room_at(pos: Vector2) -> String:
	var c := Vector2i(int(floorf(pos.x / RW)), int(floorf(pos.y / RH)))
	return _by_cell.get(c, "")


func level_data() -> Dictionary:
	return _lv


## Room-local mirroring (gives each level a different layout). Rooms A and F keep their X so the
## start and the boss never swap sides.
func _mxr(id: String) -> bool:
	return _mx and id != "A" and id != "F"


func _mp(id: String, v: Vector2) -> Vector2:
	var out: Vector2 = v
	if _mxr(id):
		out.x = RW - out.x
	if _my:
		out.y = RH - out.y
	return out


func _mr(id: String, r: Rect2) -> Rect2:
	var x: float = r.position.x
	var y: float = r.position.y
	if _mxr(id):
		x = RW - x - r.size.x
	if _my:
		y = RH - y - r.size.y
	return Rect2(x, y, r.size.x, r.size.y)


func start_position() -> Vector2:
	return origin_of("A") + Vector2(170.0, 324.0)


# ------------------------------------------------------------------ build
## Floor: mostly the main stone tile, with a few lighter tiles scattered in (no visible repeat pattern).
func _bake_floor(size: Vector2i) -> Texture2D:
	var src: Image = (load("res://assets/cave_tiles.png") as Texture2D).get_image()
	var main: Image = src.get_region(Rect2i(17 * 17, 11 * 17, 16, 16))
	var alt: Image = src.get_region(Rect2i(18 * 17, 2 * 17, 16, 16))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for x in range(0, size.x, 16):
		for y in range(0, size.y, 16):
			img.blit_rect(alt if rng.randf() < 0.15 else main, Rect2i(0, 0, 16, 16), Vector2i(x, y))
	return ImageTexture.create_from_image(img)


## Builds a texture by repeating one 16 px tile from the Roguelike Cave sheet (CC0, Kenney).
## Tiles sit on a 17 px grid (16 px art + 1 px margin).
func _bake_tile(cell: Vector2i, size: Vector2i) -> Texture2D:
	var src: Image = (load("res://assets/cave_tiles.png") as Texture2D).get_image()
	var tile: Image = src.get_region(Rect2i(cell.x * 17, cell.y * 17, 16, 16))
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for x in range(0, size.x, 16):
		for y in range(0, size.y, 16):
			img.blit_rect(tile, Rect2i(0, 0, 16, 16), Vector2i(x, y))
	return ImageTexture.create_from_image(img)


func build(level: int = 0) -> void:
	add_to_group("arena")
	z_index = -10
	level_idx = clampi(level, 0, LevelsScript.LAST)
	_lv = LevelsScript.LEVELS[level_idx]
	var mirror: int = int(_lv["mirror"])
	_my = (mirror & 1) != 0
	_mx = (mirror & 2) != 0
	var lv_rooms: Array = _lv["rooms"]
	for i in ROOMS.size():
		var r: Dictionary = ROOMS[i]
		var id: String = r["id"]
		_cells[id] = r["cell"]
		_names[id] = String(lv_rooms[i])
		var base: Color = _lv["floor"]
		var k: float = float(i % 3) * 0.012 - 0.012
		var t := Color(base.r + k, base.g + k * 0.6, base.b - k * 0.5)
		if id == "F":
			t = _lv["boss_floor"]
		_tints[id] = t
		_by_cell[r["cell"]] = id
		_sides[id] = {}
	for d in DOORS:
		var ca: Vector2i = _cells[d["a"]]
		var cb: Vector2i = _cells[d["b"]]
		var delta: Vector2i = cb - ca
		if delta == Vector2i(1, 0):
			_sides[d["a"]]["E"] = true
			_sides[d["b"]]["W"] = true
		elif delta == Vector2i(-1, 0):
			_sides[d["a"]]["W"] = true
			_sides[d["b"]]["E"] = true
		elif delta == Vector2i(0, 1):
			_sides[d["a"]]["S"] = true
			_sides[d["b"]]["N"] = true
		elif delta == Vector2i(0, -1):
			_sides[d["a"]]["N"] = true
			_sides[d["b"]]["S"] = true

	_floor_tex = TexturesScript.make(String(_lv["tex"]), _lv["floor"], 11 + level_idx * 7, true)
	_wall_tex = _bake_tile(Vector2i(23, 2), Vector2i(64, 64))

	var ambient := CanvasModulate.new()
	ambient.color = _lv["ambient"]
	add_child(ambient)

	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + level_idx * 77
	var decor_kind: String = _lv["decor"]
	for r in ROOMS:
		var id: String = r["id"]
		var shades: Array[float] = []
		for i in 18 * 11:
			shades.append(rng.randf_range(-0.035, 0.035))
		_shades[id] = shades
		var o: Vector2 = origin_of(id)
		for i in 7:
			var p := o + Vector2(rng.randf_range(90.0, 1060.0), rng.randf_range(90.0, 560.0))
			var pts := PackedVector2Array([p])
			for k in 3:
				p += Vector2(rng.randf_range(-34.0, 34.0), rng.randf_range(-34.0, 34.0))
				pts.append(p)
			_cracks.append(pts)
		if decor_kind != "none":
			for n in 14:
				_decor.append({"pos": o + Vector2(rng.randf_range(70.0, 1080.0), rng.randf_range(70.0, 580.0)),
						"k": decor_kind, "s": rng.randf() * TAU, "len": rng.randf_range(10.0, 26.0)})
		_build_walls(id)
		_add_torches(id)

	_define_props()
	for ob in _obstacles:
		_add_solid(ob["r"], 8)

	for d in DOORS:
		if String(d["key"]) != "":
			_add_door(d)
	_spawn_hazards()

	_flames = Node2D.new()
	_flames.material = Fx.glow_material()
	_flames.z_index = 1
	add_child(_flames)
	_flames.draw.connect(_draw_flames)


func _add_solid(r: Rect2, layer: int = 4) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = r.position + r.size * 0.5
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	cs.shape = rect
	body.add_child(cs)
	add_child(body)


func _wall_rects(id: String) -> Array[Rect2]:
	var o: Vector2 = origin_of(id)
	var sd: Dictionary = _sides[id]
	var out: Array[Rect2] = []
	var half_gap: float = GAP * 0.5
	# horizontal walls (N / S)
	for side in ["N", "S"]:
		var y: float = o.y if side == "N" else o.y + RH - WALL
		if sd.has(side):
			var cx: float = o.x + RW * 0.5
			out.append(Rect2(o.x, y, cx - half_gap - o.x, WALL))
			out.append(Rect2(cx + half_gap, y, o.x + RW - (cx + half_gap), WALL))
		else:
			out.append(Rect2(o.x, y, RW, WALL))
	# vertical walls (W / E)
	for side in ["W", "E"]:
		var x: float = o.x if side == "W" else o.x + RW - WALL
		if sd.has(side):
			var cy: float = o.y + RH * 0.5
			out.append(Rect2(x, o.y, WALL, cy - half_gap - o.y))
			out.append(Rect2(x, cy + half_gap, WALL, o.y + RH - (cy + half_gap)))
		else:
			out.append(Rect2(x, o.y, WALL, RH))
	return out


var _wall_draw: Array[Rect2] = []


func _build_walls(id: String) -> void:
	for r in _wall_rects(id):
		_wall_draw.append(r)
		_add_solid(r)


func _add_torches(id: String) -> void:
	var o: Vector2 = origin_of(id)
	for p in [Vector2(62, 62), Vector2(RW - 62.0, 62), Vector2(62, RH - 62.0), Vector2(RW - 62.0, RH - 62.0)]:
		var pos: Vector2 = o + p
		_torches.append(pos)
		var light := PointLight2D.new()
		light.texture = Fx.light_texture()
		light.texture_scale = 1.9
		light.color = _lv["torch"] if id != "F" else _lv["torch_boss"]
		light.energy = 1.0
		light.height = 45.0
		light.position = pos
		add_child(light)
		_lights.append(light)


func _add_door(d: Dictionary) -> void:
	var ca: Vector2i = _cells[d["a"]]
	var cb: Vector2i = _cells[d["b"]]
	var door := StaticBody2D.new()
	door.set_script(DoorScript)
	door.set("key_id", String(d["key"]))
	var delta: Vector2i = cb - ca
	if delta.x != 0:
		var bx: float = float(maxi(ca.x, cb.x)) * RW
		var cy: float = float(ca.y) * RH + RH * 0.5
		door.position = Vector2(bx, cy)
		door.set("door_size", Vector2(2.0 * WALL, GAP))
	else:
		var by: float = float(maxi(ca.y, cb.y)) * RH
		var cx: float = float(ca.x) * RW + RW * 0.5
		door.position = Vector2(cx, by)
		door.set("door_size", Vector2(GAP, 2.0 * WALL))
	add_child(door)


# ------------------------------------------------------------------ props (room-local coordinates)
func _ob(id: String, x: float, y: float, w: float, h: float, kind: String) -> void:
	var o: Vector2 = origin_of(id)
	var r: Rect2 = _mr(id, Rect2(x, y, w, h))
	var skins: Dictionary = SKINS[String(_lv["skin"])]
	var drawn: String = String(skins.get(kind, kind))
	_obstacles.append({"r": Rect2(o + r.position, r.size), "k": drawn})


func _spawn_hazards() -> void:
	var mode: String = _lv["hazard"]
	if mode == "none":
		return
	var i: int = 0
	if mode == "spikes" or mode == "both":
		for h in SPIKES:
			_add_hazard("spikes", h, i)
			i += 1
	if mode == "pools" or mode == "both":
		for h in POOLS:
			_add_hazard("pool", h, i)
			i += 1


func _add_hazard(kind: String, h: Array, idx: int) -> void:
	var id: String = h[0]
	var r: Rect2 = _mr(id, Rect2(float(h[1]), float(h[2]), float(h[3]), float(h[4])))
	var node := Node2D.new()
	node.set_script(HazardScript)
	var dmg: int = int(_lv["hazard_dmg"])
	var col: Color = _lv["spike_color"]
	var kd: String = kind
	if kind == "pool":
		dmg = maxi(5, int(float(dmg) * 0.5))
		col = _lv["pool_color"]
		kd = String(_lv["pool_kind"])
	node.set("kind", kd)
	node.set("size", r.size)
	node.set("color", col)
	node.set("damage", dmg)
	node.set("phase", float(idx) * 0.55)
	node.position = origin_of(id) + r.position + r.size * 0.5
	add_child(node)


func _define_props() -> void:
	# A: Entrance Hall
	_ob("A", 300, 120, 70, 70, "crate")
	_ob("A", 300, 458, 70, 70, "crate")
	_ob("A", 560, 170, 62, 62, "pillar")
	_ob("A", 560, 416, 62, 62, "pillar")
	# B: Barracks
	_ob("B", 250, 150, 64, 64, "crate")
	_ob("B", 250, 434, 64, 64, "crate")
	_ob("B", 838, 150, 64, 64, "crate")
	_ob("B", 838, 434, 64, 64, "crate")
	_ob("B", 400, 296, 56, 56, "pillar")
	_ob("B", 696, 296, 56, 56, "pillar")
	# C: Archive (bookshelves)
	_ob("C", 190, 90, 56, 330, "shelf")
	_ob("C", 400, 200, 56, 330, "shelf")
	_ob("C", 610, 90, 56, 330, "shelf")
	_ob("C", 820, 200, 56, 330, "shelf")
	# D: Armory (weapon racks + crates)
	_ob("D", 300, 100, 200, 40, "rack")
	_ob("D", 300, 508, 200, 40, "rack")
	_ob("D", 652, 100, 200, 40, "rack")
	_ob("D", 652, 508, 200, 40, "rack")
	_ob("D", 420, 290, 64, 64, "crate")
	_ob("D", 668, 290, 64, 64, "crate")
	# E: Treasury
	_ob("E", 250, 150, 56, 56, "pillar")
	_ob("E", 846, 150, 56, 56, "pillar")
	_ob("E", 250, 420, 56, 56, "pillar")
	_ob("E", 846, 420, 56, 56, "pillar")
	# F: Boss Chamber
	_ob("F", 330, 150, 60, 60, "pillar")
	_ob("F", 330, 438, 60, 60, "pillar")
	_ob("F", 700, 100, 60, 60, "pillar")
	_ob("F", 700, 488, 60, 60, "pillar")


# ------------------------------------------------------------------ population
func _local(id: String, x: float, y: float) -> Vector2:
	return origin_of(id) + Vector2(x, y)


func _mods() -> Dictionary:
	return {"hp": _lv["hp"], "dmg": _lv["dmg"], "view": _lv["view"], "spd": _lv["spd"], "boss": _lv["boss"],
			"coin": _lv["coin"], "roster": _lv["roster"]}


func _kind_for(id: String) -> String:
	var idx: int = _gi
	_gi += 1
	if id == "A":
		return "grunt"
	var be: int = int(_lv["brute_every"])
	var ae: int = int(_lv["archer_every"])
	var fe: int = int(_lv["flyer_every"])
	if be > 0 and idx % be == be - 1:
		return "brute"
	if fe > 0 and idx % fe == 1:
		return "flyer"
	if ae > 0 and idx % ae == ae - 1:
		return "archer"
	var se: int = int(_lv.get("shield_every", 0))
	var he: int = int(_lv.get("hound_every", 0))
	if se > 0 and idx % se == se - 2:
		return "shield"
	if he > 0 and idx % he == 2:
		return "hound"
	var bl: int = int(_lv.get("blinder_every", 0))
	if bl > 0 and idx % bl == bl - 1:
		return "blinder"
	return "grunt"


func _spawn_guard(id: String, route: Array, tier: int, facing: float = 0.0, boss: bool = false, kind: String = "") -> void:
	var gk: String = kind
	if boss:
		gk = "boss"
	elif gk == "":
		gk = _kind_for(id)
	var pts: Array[Vector2] = []
	for p in route:
		# Shift each waypoint a little every run so the patrols never repeat exactly.
		var jp: Vector2 = p + Vector2(randf_range(-45.0, 45.0), randf_range(-45.0, 45.0))
		jp = Vector2(clampf(jp.x, 40.0, RW - 40.0), clampf(jp.y, 40.0, RH - 40.0))
		var v: Vector2 = _mp(id, jp)
		pts.append(_local(id, v.x, v.y))
	var f: float = facing
	if _mxr(id):
		f = PI - f
	if _my:
		f = -f
	if pts.size() >= 2:
		f = (pts[1] - pts[0]).angle()
	var g = GuardScript.new()
	var start: Vector2 = pts[0]
	g.configure(pts, tier, boss, f)
	g.apply_kind(gk, _mods())
	g.position = start
	add_child(g)
	g.died.connect(func(guard: Node2D, stealth: bool) -> void: guard_died.emit(guard, stealth))


func _spawn_heart(id: String, x: float, y: float, amount: int = 0) -> void:
	var h := Node2D.new()
	h.set_script(PickupScript)
	h.set("persistent", true)
	h.set("heal_amount", amount if amount > 0 else int(_lv["heart"]))
	var v: Vector2 = _mp(id, Vector2(x, y))
	h.position = _local(id, v.x, v.y)
	add_child(h)


func _spawn_key(id: String, x: float, y: float, kind: String) -> void:
	var k := Node2D.new()
	k.set_script(KeyScript)
	k.set("kind", kind)
	var v: Vector2 = _mp(id, Vector2(x, y))
	k.position = _local(id, v.x, v.y)
	add_child(k)


func _spawn_loot(id: String, v: Vector2, kind: String, value: int) -> void:
	var l = LootScript.new()
	l.kind = kind
	l.value = value
	l.persistent = true
	var p: Vector2 = _mp(id, v)
	l.position = _local(id, p.x, p.y)
	add_child(l)


## Boss summons: called through the "arena" group.
func spawn_minions(pos: Vector2, kind: String, n: int) -> void:
	var alive: int = 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if bool(e.get("is_minion")):
			alive += 1
	if alive >= 4:
		return
	for i in n:
		var g = GuardScript.new()
		var p: Vector2 = pos + Vector2.from_angle(randf() * TAU) * 60.0
		var pts: Array[Vector2] = [p]
		g.configure(pts, 0, false, 0.0)
		g.apply_kind(kind, _mods())
		g.is_minion = true
		g.position = p
		add_child(g)
		g.died.connect(func(guard: Node2D, stealth: bool) -> void: guard_died.emit(guard, stealth))
		g.force_chase()


## Call AFTER the player is in the tree (guards look for the "player" group in _ready).
func populate() -> void:
	_gi = 0
	# A
	_spawn_guard("A", [Vector2(660, 140), Vector2(660, 510)], 0)
	_spawn_heart("A", 110, 560)
	# B
	_spawn_guard("B", [Vector2(180, 100), Vector2(950, 100)], 0)
	_spawn_guard("B", [Vector2(950, 548), Vector2(180, 548)], 0)
	_spawn_heart("B", 1070, 90)
	# C
	_spawn_guard("C", [Vector2(533, 130), Vector2(533, 560)], 2)
	_spawn_guard("C", [Vector2(743, 560), Vector2(743, 130)], 2)
	_spawn_guard("C", [Vector2(990, 330)], 2, PI)
	_spawn_heart("C", 100, 560)
	_spawn_key("C", 1030, 110, "bronze")
	# D
	_spawn_guard("D", [Vector2(200, 200), Vector2(200, 450)], 1)
	_spawn_guard("D", [Vector2(576, 200), Vector2(576, 450)], 1)
	_spawn_guard("D", [Vector2(950, 150), Vector2(950, 500)], 1)
	_spawn_heart("D", 1070, 570)
	# E
	_spawn_guard("E", [Vector2(200, 330), Vector2(950, 330)], 3)
	_spawn_guard("E", [Vector2(576, 230)], 3, PI * 0.5)
	_spawn_heart("E", 110, 570)
	_spawn_heart("E", 1040, 570)
	_spawn_key("E", 576, 105, "gold")
	# F
	_spawn_guard("F", [Vector2(520, 200), Vector2(520, 450)], 1)
	_spawn_guard("F", [Vector2(880, 140)], 1, PI * 0.5)
	_spawn_guard("F", [Vector2(880, 324)], 1, PI, true)
	_spawn_heart("F", 110, 90)
	_spawn_heart("F", 110, 560)
	_spawn_heart("F", 1050, 560, int(_lv["heart"]) + 10)
	# loot: coins everywhere, a bundle of arrows in every room except the first
	for rid in ["A", "B", "C", "D", "E", "F"]:
		for cs in COIN_SPOTS:
			_spawn_loot(rid, cs, "coin", int(_lv["coin"]))
		if rid != "A":
			_spawn_loot(rid, ARROW_SPOT, "arrows", 6)
	# extra (level) guards
	var extras: Array = _lv["extras"]
	for e in extras:
		var rid: String = e[0]
		var route: Array = LevelsScript.EXTRA_ROUTES[rid]
		_spawn_guard(rid, route, 1, 0.0, false, String(e[1]))


# ------------------------------------------------------------------ effects
func _process(delta: float) -> void:
	_time += delta
	for i in _lights.size():
		var flick: float = sin(_time * 9.0 + float(i) * 1.7) * 0.10 + sin(_time * 23.0 + float(i) * 3.1) * 0.06
		_lights[i].energy = 1.0 + flick
	if _flames:
		_flames.queue_redraw()


func add_splat(pos: Vector2, color: Color, size: float = 1.0) -> void:
	var blobs: Array = []
	for i in 6:
		blobs.append([Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0)) * size,
				randf_range(2.0, 7.0) * size])
	_splats.append({"pos": pos, "col": color.darkened(0.4), "blobs": blobs})
	if _splats.size() > 200:
		_splats.pop_front()
	queue_redraw()


# ------------------------------------------------------------------ drawing
func _draw() -> void:
	for r in ROOMS:
		var id: String = r["id"]
		var o: Vector2 = origin_of(id)
		var tint: Color = _tints[id]
		var base: Color = _lv["floor"]
		var mod := Color(clampf(tint.r / base.r, 0.4, 2.0), clampf(tint.g / base.g, 0.4, 2.0), clampf(tint.b / base.b, 0.4, 2.0), 1.0)
		draw_texture_rect(_floor_tex, Rect2(o, Vector2(RW, RH)), true, mod)
		# rug / rune circle for flavour
		var c: Vector2 = o + Vector2(RW, RH) * 0.5
		if id == "F":
			var br: Color = _lv["boss_rune"]
			draw_arc(c + Vector2(260, 0), 150.0, 0.0, TAU, 64, Color(br, 0.30), 4.0)
			draw_arc(c + Vector2(260, 0), 120.0, 0.0, TAU, 64, Color(br, 0.2), 2.0)
		elif id == "A" or id == "E":
			draw_arc(c, 120.0, 0.0, TAU, 64, _lv["rune"], 3.0)
		if id == "C":
			pass
	for dc in _decor:
		var dp: Vector2 = dc["pos"]
		var dl: float = float(dc["len"])
		var ds: float = float(dc["s"])
		if dc["k"] == "bones":
			var bc := Color(0.82, 0.8, 0.7, 0.55)
			var dv: Vector2 = Vector2.from_angle(ds) * dl
			draw_line(dp - dv, dp + dv, bc, 3.0)
			draw_circle(dp - dv, 3.5, bc)
			draw_circle(dp + dv, 3.5, bc)
			draw_line(dp + dv.orthogonal() * 0.4, dp - dv.orthogonal() * 0.4, bc, 2.0)
		elif dc["k"] == "grass":
			var gc := Color(0.35, 0.62, 0.22, 0.7)
			for k in 3:
				var ga: float = -PI * 0.5 + (float(k) - 1.0) * 0.45
				draw_line(dp, dp + Vector2.from_angle(ga) * (dl * 0.7), gc, 2.0)
			if dl > 20.0:
				draw_circle(dp + Vector2(0, -dl * 0.75), 2.4, Color(1.0, 0.9, 0.3, 0.9) if ds < 3.0 else Color(0.95, 0.4, 0.5, 0.9))
		elif dc["k"] == "sand":
			draw_arc(dp, dl, ds, ds + 1.3, 8, Color(0.45, 0.34, 0.2, 0.3), 2.0)
			draw_circle(dp + Vector2(dl * 0.4, 3.0), 2.6, Color(0.42, 0.34, 0.24, 0.7))
			draw_circle(dp + Vector2(-dl * 0.3, -2.0), 1.8, Color(0.5, 0.42, 0.3, 0.7))
		elif dc["k"] == "frost":
			for a in 3:
				var fv: Vector2 = Vector2.from_angle(ds + float(a) * PI / 3.0) * dl
				draw_line(dp - fv, dp + fv, Color(0.8, 0.93, 1.0, 0.35), 2.0)
	for cr in _cracks:
		draw_polyline(cr, Color(0.04, 0.04, 0.06, 0.65), 1.6)
	for sp in _splats:
		var col: Color = sp["col"]
		col.a = 0.78
		for b in sp["blobs"]:
			draw_circle(sp["pos"] + b[0], b[1], col)
	# walls
	for w in _wall_draw:
		draw_rect(w, _lv["wall_dark"])
		draw_texture_rect(_wall_tex, w.grow(-4.0), true)
		draw_rect(w.grow(-4.0), Color(0, 0, 0, 0.3), false, 3.0)
		draw_line(w.position + Vector2(4, 4), Vector2(w.end.x - 4.0, w.position.y + 4.0), Color(1, 1, 1, 0.12), 2.0)
		draw_rect(w, _lv["wall_trim"], false, 1.0)
	# props
	for ob in _obstacles:
		_draw_prop(ob["r"], ob["k"])
	# torch bases
	for pos in _torches:
		draw_circle(pos, 15.0, Color(0.06, 0.06, 0.08))
		draw_circle(pos, 12.0, Color(0.24, 0.23, 0.27))
		draw_circle(pos, 8.5, Color(0.07, 0.05, 0.05))


func _draw_prop(r: Rect2, kind: String) -> void:
	draw_rect(Rect2(r.position + Vector2(4, 6), r.size), Color(0, 0, 0, 0.3))   # shadow
	if kind in ["tomb", "bones", "ice", "forge", "hotpillar", "obelisk", "bush", "tree", "hedge", "cactus", "sandpillar", "sandrock"]:
		_draw_prop_extra(r, kind)
		return
	match kind:
		"crate":
			draw_rect(r, Color(0.25, 0.17, 0.09))
			draw_rect(r.grow(-4.0), Color(0.42, 0.29, 0.15))
			draw_line(r.position + Vector2(4, 4), r.end - Vector2(4, 4), Color(0.2, 0.13, 0.07), 3.0)
			draw_line(Vector2(r.end.x - 4.0, r.position.y + 4.0), Vector2(r.position.x + 4.0, r.end.y - 4.0), Color(0.2, 0.13, 0.07), 3.0)
		"pillar":
			draw_rect(r, Color(0.10, 0.10, 0.13))
			draw_rect(r.grow(-4.0), Color(0.36, 0.37, 0.43))
			draw_rect(r.grow(-12.0), Color(0.44, 0.45, 0.52))
			draw_rect(Rect2(r.position + Vector2(8, 8), Vector2(10, 10)), Color(1, 1, 1, 0.12))
		"shelf":
			draw_rect(r, Color(0.16, 0.10, 0.06))
			draw_rect(r.grow(-4.0), Color(0.30, 0.19, 0.10))
			var books: Array[Color] = [Color(0.6, 0.15, 0.15), Color(0.15, 0.3, 0.55), Color(0.25, 0.5, 0.25), Color(0.7, 0.55, 0.2)]
			var y: float = r.position.y + 8.0
			var i: int = 0
			while y < r.end.y - 14.0:
				draw_rect(Rect2(Vector2(r.position.x + 8.0, y), Vector2(r.size.x - 16.0, 9.0)), books[i % books.size()])
				y += 14.0
				i += 1
		"rack":
			draw_rect(r, Color(0.09, 0.09, 0.11))
			draw_rect(r.grow(-3.0), Color(0.27, 0.28, 0.33))
			var x: float = r.position.x + 12.0
			while x < r.end.x - 8.0:
				draw_line(Vector2(x, r.position.y + 6.0), Vector2(x, r.end.y - 6.0), Color(0.7, 0.72, 0.8), 3.0)
				x += 18.0


func _blobs(r: Rect2, dark: Color, mid: Color, light: Color) -> void:
	var cell: float = minf(r.size.x, r.size.y)
	var n: int = maxi(1, int(round(maxf(r.size.x, r.size.y) / cell)))
	for k in n:
		var cc: Vector2
		if r.size.x >= r.size.y:
			cc = Vector2(r.position.x + (float(k) + 0.5) * r.size.x / float(n), r.get_center().y)
		else:
			cc = Vector2(r.get_center().x, r.position.y + (float(k) + 0.5) * r.size.y / float(n))
		var rad: float = cell * 0.56
		draw_circle(cc, rad, dark)
		draw_circle(cc + Vector2(-2, -2), rad * 0.82, mid)
		draw_circle(cc + Vector2(-rad * 0.25, -rad * 0.3), rad * 0.5, light)
		for j in 5:
			var a: float = float(j) * 1.26 + float(k)
			draw_circle(cc + Vector2.from_angle(a) * rad * 0.55, 3.0, light)


func _draw_prop_extra(r: Rect2, kind: String) -> void:
	match kind:
		"bush":
			_blobs(r, Color(0.05, 0.12, 0.05), Color(0.14, 0.32, 0.12), Color(0.28, 0.5, 0.2))
		"hedge":
			_blobs(r, Color(0.04, 0.10, 0.05), Color(0.11, 0.26, 0.10), Color(0.22, 0.42, 0.16))
		"tree":
			var tc: Vector2 = r.get_center()
			draw_circle(tc, r.size.x * 0.34, Color(0.18, 0.11, 0.06))
			draw_circle(tc, r.size.x * 0.78, Color(0.04, 0.11, 0.05))
			draw_circle(tc + Vector2(-3, -3), r.size.x * 0.68, Color(0.09, 0.24, 0.09))
			draw_circle(tc + Vector2(-8, -9), r.size.x * 0.42, Color(0.19, 0.4, 0.15))
			for j in 7:
				draw_circle(tc + Vector2.from_angle(float(j) * 0.9) * r.size.x * 0.48, 4.0, Color(0.25, 0.5, 0.2))
		"cactus":
			var cc2: Vector2 = r.get_center()
			var rad2: float = r.size.x * 0.46
			draw_circle(cc2, rad2, Color(0.06, 0.16, 0.08))
			draw_circle(cc2, rad2 * 0.86, Color(0.17, 0.4, 0.2))
			for j in 8:
				var ang: float = TAU * float(j) / 8.0
				draw_line(cc2 + Vector2.from_angle(ang) * rad2 * 0.2, cc2 + Vector2.from_angle(ang) * rad2 * 0.85, Color(0.1, 0.27, 0.13), 2.0)
				draw_circle(cc2 + Vector2.from_angle(ang + 0.2) * rad2 * 0.95, 1.6, Color(0.95, 0.9, 0.7))
			draw_circle(cc2, 5.0, Color(0.95, 0.45, 0.55))
		"sandpillar":
			draw_rect(r, Color(0.16, 0.12, 0.07))
			draw_rect(r.grow(-4.0), Color(0.62, 0.5, 0.32))
			draw_rect(r.grow(-11.0), Color(0.72, 0.6, 0.4))
			for j in 3:
				var hy: float = r.position.y + 16.0 + float(j) * 14.0
				draw_line(Vector2(r.position.x + 15.0, hy), Vector2(r.end.x - 15.0, hy), Color(0.35, 0.26, 0.15), 2.0)
		"sandrock":
			var rc: Vector2 = r.get_center()
			var pts := PackedVector2Array()
			var inner := PackedVector2Array()
			for j in 14:
				var an: float = TAU * float(j) / 14.0
				var jit: float = 0.86 + 0.14 * sin(float(j) * 2.7 + r.position.x)
				var rp := Vector2(cos(an) * r.size.x * 0.58 * jit, sin(an) * r.size.y * 0.58 * jit)
				pts.append(rc + rp)
				inner.append(rc + rp * 0.78 + Vector2(-2, -2))
			draw_colored_polygon(pts, Color(0.2, 0.15, 0.09))
			draw_colored_polygon(inner, Color(0.55, 0.43, 0.27))
			draw_line(rc + Vector2(-r.size.x * 0.3, -r.size.y * 0.1), rc + Vector2(r.size.x * 0.25, -r.size.y * 0.25), Color(0.75, 0.62, 0.42, 0.7), 2.0)
		"tomb":
			draw_rect(r, Color(0.07, 0.09, 0.08))
			draw_rect(r.grow(-4.0), Color(0.34, 0.38, 0.35))
			draw_rect(r.grow(-11.0), Color(0.27, 0.31, 0.28))
			var c: Vector2 = r.get_center()
			draw_line(c + Vector2(0, -r.size.y * 0.25), c + Vector2(0, r.size.y * 0.25), Color(0.5, 0.56, 0.5), 4.0)
			draw_line(c + Vector2(-r.size.x * 0.2, -r.size.y * 0.08), c + Vector2(r.size.x * 0.2, -r.size.y * 0.08), Color(0.5, 0.56, 0.5), 4.0)
		"bones":
			draw_rect(r, Color(0.06, 0.07, 0.06))
			draw_rect(r.grow(-4.0), Color(0.17, 0.19, 0.17))
			var y: float = r.position.y + 12.0
			var i: int = 0
			while y < r.end.y - 10.0:
				var bc := Color(0.85, 0.83, 0.72)
				draw_line(Vector2(r.position.x + 8.0, y), Vector2(r.end.x - 8.0, y), bc, 3.0)
				draw_circle(Vector2(r.position.x + 9.0 + float(i % 2) * 4.0, y), 3.5, bc)
				draw_circle(Vector2(r.end.x - 9.0, y), 3.5, bc)
				y += 15.0
				i += 1
		"ice":
			draw_rect(r, Color(0.08, 0.13, 0.2))
			var cell: float = minf(r.size.x, r.size.y)
			var n: int = maxi(1, int(maxf(r.size.x, r.size.y) / cell))
			for k in n:
				var cc: Vector2
				if r.size.x >= r.size.y:
					cc = Vector2(r.position.x + (float(k) + 0.5) * r.size.x / float(n), r.get_center().y)
				else:
					cc = Vector2(r.get_center().x, r.position.y + (float(k) + 0.5) * r.size.y / float(n))
				var hw: float = cell * 0.5 - 3.0
				var pts := PackedVector2Array([cc + Vector2(0, -hw * 1.15), cc + Vector2(hw, 0), cc + Vector2(0, hw * 1.15), cc + Vector2(-hw, 0)])
				draw_colored_polygon(pts, Color(0.48, 0.74, 0.92))
				draw_colored_polygon(PackedVector2Array([cc + Vector2(0, -hw * 0.8), cc + Vector2(hw * 0.5, 0), cc + Vector2(0, hw * 0.2), cc + Vector2(-hw * 0.3, -hw * 0.1)]), Color(0.85, 0.96, 1.0, 0.85))
		"forge":
			draw_rect(r, Color(0.06, 0.05, 0.05))
			draw_rect(r.grow(-4.0), Color(0.22, 0.2, 0.2))
			var y2: float = r.position.y + 12.0
			while y2 < r.end.y - 8.0:
				draw_line(Vector2(r.position.x + 7.0, y2), Vector2(r.end.x - 7.0, y2), Color(0.95, 0.38, 0.1), 3.0)
				y2 += 20.0
		"hotpillar":
			draw_rect(r, Color(0.07, 0.04, 0.04))
			draw_rect(r.grow(-4.0), Color(0.3, 0.17, 0.14))
			draw_rect(r.grow(-14.0), Color(0.95, 0.4, 0.12))
		"obelisk":
			draw_rect(r, Color(0.04, 0.03, 0.07))
			draw_rect(r.grow(-4.0), Color(0.17, 0.12, 0.26))
			var cc2: Vector2 = r.get_center()
			var q: float = minf(r.size.x, r.size.y) * 0.25
			draw_line(cc2 + Vector2(0, -q), cc2 + Vector2(q, q), Color(0.8, 0.4, 1.0), 2.0)
			draw_line(cc2 + Vector2(q, q), cc2 + Vector2(-q, q), Color(0.8, 0.4, 1.0), 2.0)
			draw_line(cc2 + Vector2(-q, q), cc2 + Vector2(0, -q), Color(0.8, 0.4, 1.0), 2.0)


func _draw_flames() -> void:
	for ob in _obstacles:
		var pr: Rect2 = ob["r"]
		var pk: String = ob["k"]
		var pulse: float = 0.5 + 0.5 * sin(_time * 2.2 + pr.position.x * 0.01)
		if pk == "forge" or pk == "hotpillar":
			_flames.draw_rect(pr.grow(-10.0), Color(1.6, 0.5, 0.1, 0.10 + 0.12 * pulse))
		elif pk == "obelisk":
			_flames.draw_rect(pr.grow(-10.0), Color(0.9, 0.3, 1.6, 0.10 + 0.12 * pulse))
		elif pk == "ice":
			_flames.draw_rect(pr.grow(-6.0), Color(0.4, 0.8, 1.6, 0.05 + 0.06 * pulse))
	for dc in _decor:
		var dp: Vector2 = dc["pos"]
		var ds: float = float(dc["s"])
		var dl: float = float(dc["len"])
		if dc["k"] == "ember":
			var p1: Vector2 = dp + Vector2.from_angle(ds) * dl
			var p2: Vector2 = p1 + Vector2.from_angle(ds + 0.8) * dl * 0.7
			_flames.draw_polyline(PackedVector2Array([dp, p1, p2]), Color(1.8, 0.5, 0.1, 0.3 + 0.2 * sin(_time * 2.0 + ds)), 2.0)
		elif dc["k"] == "void":
			var op: Vector2 = dp + Vector2(sin(_time * 0.8 + ds), cos(_time * 0.6 + ds)) * 10.0
			_flames.draw_circle(op, 3.0, Color(1.2, 0.4, 1.8, 0.45 + 0.3 * sin(_time * 2.0 + ds)))
	for i in _torches.size():
		var pos: Vector2 = _torches[i]
		var f: float = 1.0 + sin(_time * 12.0 + float(i) * 2.0) * 0.12 + sin(_time * 31.0 + float(i)) * 0.06
		_flames.draw_circle(pos, 15.0 * f, Color(1.0, 0.45, 0.1, 0.16))
		_flames.draw_circle(pos, 9.0 * f, Color(1.8, 0.8, 0.25, 0.85))
		_flames.draw_circle(pos + Vector2(0, -2), 5.0 * f, Color(2.2, 1.7, 0.7, 0.95))
