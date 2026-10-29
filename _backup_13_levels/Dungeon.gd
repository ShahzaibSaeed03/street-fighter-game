extends Node2D
## Dungeon.gd — builds a random dungeon each run (from a seed): 5 to 9 rooms, walls, doors, props,
## guards, hearts and keys, all from code.
## Rooms sit on a grid, one screen (1152 x 648) each. Every room is an instance ("R0", "R1", ...)
## that uses one of the six layout templates (A-F) from ROOMS. The start room always uses layout A,
## the boss room layout F, and the others B-E.
## Group "arena" (blood splats). The camera in Game.gd snaps to the room the player is in.

signal guard_died(guard: Node2D, stealth: bool)

const Fx := preload("res://Fx.gd")
const GuardScript := preload("res://Guard.gd")
const DoorScript := preload("res://Door.gd")
const KeyScript := preload("res://KeyPickup.gd")
const PickupScript := preload("res://Pickup.gd")
const HazardScript := preload("res://Hazard.gd")
const LevelsScript := preload("res://Levels.gd")
const LayoutsScript := preload("res://Layouts.gd")
const PowerUpScript := preload("res://PowerUp.gd")
const BellScript := preload("res://Bell.gd")
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
	"ruin": {"crate": "rubble", "pillar": "brokenpillar", "shelf": "rubble", "rack": "rubble"},
	"mire": {"crate": "mushroom", "pillar": "mushroom", "shelf": "logs", "rack": "logs"},
	"crystal": {"crate": "crystal", "pillar": "crystal", "shelf": "crystal", "rack": "crystal"},
	"clock": {"crate": "gear", "pillar": "gear", "shelf": "pipes", "rack": "pipes"},
	"coral": {"crate": "coral", "pillar": "coral", "shelf": "coral", "rack": "coral"},
	"palace": {"crate": "marble", "pillar": "marble", "shelf": "marble", "rack": "marble"},
}

## Room shapes: wall blocks (room-local, top-left corner version) that carve the room so it is not a plain
## box. "sym" = "4": mirrored into all four corners, "h": top-left + top-right, "1": as written. Every
## room also gets a random flip, so each shape appears in several orientations. All of them leave the
## door lanes (top/bottom middle x 480-672, left/right middle y 230-420) and the middle cross open.
const SHAPES: Dictionary = {
	"box": {"rects": [], "sym": "1"},
	"chamfer": {"rects": [Rect2(36, 36, 240, 90), Rect2(36, 36, 120, 190)], "sym": "4"},
	"cross": {"rects": [Rect2(36, 36, 380, 170)], "sym": "4"},
	"L": {"rects": [Rect2(700, 36, 416, 184)], "sym": "1"},
	"T": {"rects": [Rect2(36, 430, 420, 182), Rect2(696, 430, 420, 182)], "sym": "1"},
	"notched": {"rects": [Rect2(36, 36, 130, 170)], "sym": "4"},
	"zig": {"rects": [Rect2(36, 36, 300, 150), Rect2(816, 462, 300, 150)], "sym": "1"},
	"bite": {"rects": [Rect2(36, 36, 420, 130)], "sym": "h"},
	"stair": {"rects": [Rect2(36, 36, 180, 150), Rect2(36, 36, 300, 90)], "sym": "1"},
}

## Signature enemy per level (index = level): most guards on that level are this kind.
const SIGNATURE: Array[String] = [
	"grunt",    # 1 The Dungeon: swordsmen
	"hound",    # 2 Jungle Ruins: hounds
	"archer",   # 3 Desert Tomb: archers
	"brute",    # 4 Lava Forge: brutes
	"flyer",    # 5 Frozen Keep: flying bats
	"blinder",  # 6 Shadow Citadel: blinders
	"shield",   # 7 Bone Crypt: shieldbearers
	"archer",   # 8 Haunted Manor: archers
	"hound",    # 9 Sunken Temple: hounds
	"brute",    # 10 Crimson Cathedral: brutes
	"shield",   # 11 Storm Fortress: shieldbearers
	"flyer",    # 12 Abyss Throne: flyers
	"blinder",  # 13 Bell Tower: blinders
]

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
# ---- this run's dungeon graph (set by _generate_graph)
var _ids: Array[String] = []          # instance ids in build order
var _lay_of: Dictionary = {}          # instance id -> layout template letter (A-F)
var _doors: Array[Dictionary] = []    # {"a": id, "b": id, "key": "" | "bronze" | "gold"}
var _start: String = ""
var _boss_id: String = ""
var _bronze_key_room: String = ""
var _gold_key_room: String = ""
var _revive_room: String = ""
var _bronze_pair: Array = []          # the two rooms the bronze door joins
var _gold_door_from: String = ""      # room the gold door (to the boss) opens from
var _seed: int = 0
var _curtains: Array[Rect2] = []      # walk-through cover, world coordinates
var _room_mode: Dictionary = {}       # id -> "patrol" | "ambush" | "sleep" | "mini" | "boss"
var _room_guards: Dictionary = {}     # id -> Array of guards spawned in that room
var _ambushed: Dictionary = {}        # id -> true once its ambush has been sprung
var _cur_mode: String = "patrol"      # mode of the room being populated
var _cloth: Node2D                    # draws curtains, lava glow, cobwebs and the vault chest (redrawn every frame)
var _secret_rects: Array[Rect2] = []  # the curtains that lead to the hidden room
var _lava: Array[Rect2] = []          # pool rects (world), for the glow
var _secret_id: String = ""           # id of the hidden room, if any
var _shape_rects: Array[Rect2] = []   # extra wall blocks (world) that carve each room into its own shape


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


## Bounding box of every room - the follow camera never scrolls past it.
func world_bounds() -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for id in _cells:
		var o: Vector2 = origin_of(id)
		lo = lo.min(o)
		hi = hi.max(o + Vector2(RW, RH))
	return Rect2(lo, hi - lo)


func level_data() -> Dictionary:
	return _lv


## Room ids in build order (R0, R1, ...).
func room_ids() -> Array[String]:
	return _ids


## Layout template letter (A-F) of a room.
func _lay(id: String) -> String:
	return String(_lay_of.get(id, "B"))


func doors() -> Array[Dictionary]:
	return _doors


func seed_value() -> int:
	return _seed


func start_id() -> String:
	return _start


func boss_id() -> String:
	return _boss_id


func bronze_key_room() -> String:
	return _bronze_key_room


func gold_key_room() -> String:
	return _gold_key_room


func revive_room() -> String:
	return _revive_room


func bronze_door_rooms() -> Array:
	return _bronze_pair


func gold_door_from() -> String:
	return _gold_door_from


## Smallest and largest grid cells in use, and the grid size (for the minimap).
func cell_min() -> Vector2i:
	var lo := Vector2i(999999, 999999)
	for id in _cells:
		var c: Vector2i = _cells[id]
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
	return lo


func cell_span() -> Vector2i:
	var lo := Vector2i(999999, 999999)
	var hi := Vector2i(-999999, -999999)
	for id in _cells:
		var c: Vector2i = _cells[id]
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return hi - lo + Vector2i.ONE


## Room-local mirroring (gives each level a different layout). Layouts A and F keep their X so the
## start and the boss never swap sides.
func _mxr(id: String) -> bool:
	return _mx and _lay(id) != "A" and _lay(id) != "F"


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
	return origin_of(_start) + Vector2(170.0, 324.0)


# ------------------------------------------------------------------ graph
## Builds this run's room graph from the seed: 5 to 9 rooms on a grid, joined as a tree (one door per link).
## The boss sits at the far end of the deepest path. The bronze door and the gold door are the last two
## links of that path: the bronze key lies before the bronze door, the gold key between the two doors.
func _generate_graph(level: int) -> void:
	var n: int = clampi(5 + level / 3 + randi() % 2, 5, 9)
	var cells: Array[Vector2i] = []
	var edges: Array = []
	var tree: Dictionary = {}
	for _i in 200:
		_random_tree(n, cells, edges)
		tree = _tree_info(cells, edges)
		if _deepest(tree["depth"]) >= 3:
			break
	if _deepest(tree["depth"]) < 3:
		# Safety net: a straight corridor always has enough depth for both locked doors.
		cells.clear()
		edges.clear()
		for i in n:
			cells.append(Vector2i(i, 0))
			if i > 0:
				edges.append([Vector2i(i - 1, 0), Vector2i(i, 0)])
		tree = _tree_info(cells, edges)
	var adj: Dictionary = tree["adj"]
	var parent: Dictionary = tree["parent"]
	var depth: Dictionary = tree["depth"]
	var deepest: int = _deepest(depth)
	var far: Array = []
	for c in depth:
		if depth[c] == deepest:
			far.append(c)
	var boss_cell: Vector2i = far[randi() % far.size()]
	var path: Array[Vector2i] = []
	var cur: Vector2i = boss_cell
	while cur != Vector2i.ZERO:
		path.push_front(cur)
		cur = parent[cur]
	path.push_front(Vector2i.ZERO)
	var m: int = path.size()   # path[0] = start, path[m - 1] = boss, m >= 4
	var j: int = 1 + randi() % (m - 3)   # bronze link = path[j] -> path[j + 1]; j >= 1 keeps a room before it
	var bronze_cut: Dictionary = _cut_pair(path[j], path[j + 1])
	var gold_cut: Dictionary = _cut_pair(path[m - 2], path[m - 1])
	var both_cut: Dictionary = bronze_cut.duplicate()
	both_cut.merge(gold_cut)
	var start_side: Dictionary = _component(adj, Vector2i.ZERO, bronze_cut)
	var far_side: Dictionary = _component(adj, path[j + 1], both_cut)

	# ids, layouts and cell lookups
	_ids.clear()
	_lay_of.clear()
	_cells.clear()
	_by_cell.clear()
	var ids: Dictionary = {}   # cell -> id
	for i in cells.size():
		var rid: String = "R%d" % i
		ids[cells[i]] = rid
		_ids.append(rid)
		_cells[rid] = cells[i]
		_by_cell[cells[i]] = rid
	for c in cells:
		var lid: String = ids[c]
		if c == Vector2i.ZERO:
			_lay_of[lid] = "A"
		elif c == boss_cell:
			_lay_of[lid] = "F"
		else:
			_lay_of[lid] = LayoutsScript.POOL[randi() % LayoutsScript.POOL.size()]

	# doors (one per tree link), with the two locked ones
	_doors.clear()
	for e in edges:
		var key: String = ""
		if _same_link(e, path[j], path[j + 1]):
			key = "bronze"
		elif _same_link(e, path[m - 2], path[m - 1]):
			key = "gold"
		_doors.append({"a": ids[e[0]], "b": ids[e[1]], "key": key})

	_start = ids[Vector2i.ZERO]
	_boss_id = ids[boss_cell]
	_bronze_pair = [ids[path[j]], ids[path[j + 1]]]
	_gold_door_from = ids[path[m - 2]]
	_bronze_key_room = ids[_pick(start_side, Vector2i.ZERO)]
	_gold_key_room = ids[_pick(far_side, boss_cell)]
	var rest: Array = []
	for c in cells:
		if c != Vector2i.ZERO and c != boss_cell:
			rest.append(c)
	_revive_room = ids[rest[randi() % rest.size()]]

	# hidden room behind a curtain (60% of levels)
	if randf() < 0.6:
		_add_secret_room(cells, ids)


## Adds a dead-end room next to an ordinary room (not the start or the boss). The link is a curtain,
## so the room is not in the normal door graph and stays off the minimap until the player walks in.
func _add_secret_room(cells: Array[Vector2i], ids: Dictionary) -> void:
	var taken: Dictionary = {}
	for c in cells:
		taken[c] = true
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var options: Array = []   # [room cell, direction]
	for c in cells:
		if c == Vector2i.ZERO or ids[c] == _boss_id:
			continue
		for d in dirs:
			if not taken.has(c + d):
				options.append([c, d])
	if options.is_empty():
		return
	var pick: Array = options[randi() % options.size()]
	var room_cell: Vector2i = pick[0]
	var sc: Vector2i = room_cell + pick[1]
	var sid: String = "R%d" % cells.size()
	cells.append(sc)
	ids[sc] = sid
	_ids.append(sid)
	_cells[sid] = sc
	_by_cell[sc] = sid
	_lay_of[sid] = "secret"
	_secret_id = sid
	_doors.append({"a": ids[room_cell], "b": sid, "key": "secret"})


func _random_tree(n: int, cells: Array[Vector2i], edges: Array) -> void:
	cells.clear()
	edges.clear()
	cells.append(Vector2i.ZERO)
	var has: Dictionary = {Vector2i.ZERO: true}
	while cells.size() < n:
		var base: Vector2i = cells[randi() % cells.size()]
		var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		dirs.shuffle()
		for d in dirs:
			var nc: Vector2i = base + d
			if not has.has(nc):
				has[nc] = true
				cells.append(nc)
				edges.append([base, nc])
				break


## Adjacency, parent and depth (in links) of every cell, measured from the start cell.
func _tree_info(cells: Array[Vector2i], edges: Array) -> Dictionary:
	var adj: Dictionary = {}
	for c in cells:
		adj[c] = []
	for e in edges:
		adj[e[0]].append(e[1])
		adj[e[1]].append(e[0])
	var parent: Dictionary = {Vector2i.ZERO: Vector2i.ZERO}
	var depth: Dictionary = {Vector2i.ZERO: 0}
	var queue: Array = [Vector2i.ZERO]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for nb in adj[c]:
			if not depth.has(nb):
				depth[nb] = depth[c] + 1
				parent[nb] = c
				queue.append(nb)
	return {"adj": adj, "parent": parent, "depth": depth}


func _deepest(depth: Dictionary) -> int:
	var best: int = 0
	for c in depth:
		best = maxi(best, int(depth[c]))
	return best


## The cells reachable from `from` without crossing a cut link.
func _component(adj: Dictionary, from: Vector2i, cut: Dictionary) -> Dictionary:
	var seen: Dictionary = {from: true}
	var queue: Array = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for nb in adj[c]:
			if seen.has(nb) or cut.has(_ek(c, nb)):
				continue
			seen[nb] = true
			queue.append(nb)
	return seen


func _pick(cell_set: Dictionary, skip: Vector2i) -> Vector2i:
	var opts: Array = []
	for c in cell_set:
		if c != skip:
			opts.append(c)
	return opts[randi() % opts.size()]


func _ek(a: Vector2i, b: Vector2i) -> String:
	return "%d,%d>%d,%d" % [a.x, a.y, b.x, b.y]


func _cut_pair(a: Vector2i, b: Vector2i) -> Dictionary:
	return {_ek(a, b): true, _ek(b, a): true}


func _same_link(e: Array, a: Vector2i, b: Vector2i) -> bool:
	return (e[0] == a and e[1] == b) or (e[0] == b and e[1] == a)


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
	# One seed per run (Engine meta "dungeon_seed" if set, else random). It drives the room graph and
	# the random details below, and it is shown on the level card so a run can be replayed.
	_seed = int(Engine.get_meta("dungeon_seed", -1))
	if _seed < 0:
		_seed = randi() % 1000000
	seed(_seed)
	_generate_graph(level_idx)
	for idx in _ids.size():
		var id: String = _ids[idx]
		var lay: String = _lay(id)
		var li: int = "ABCDEF".find(lay)
		_names[id] = String(lv_rooms[li]) if li >= 0 else LayoutsScript.room_name(lay)
		var base: Color = _lv["floor"]
		var k: float = float(idx % 3) * 0.012 - 0.012
		var t := Color(base.r + k, base.g + k * 0.6, base.b - k * 0.5)
		t = t * LayoutsScript.tint_of(lay)
		if lay == "F":
			t = _lv["boss_floor"]
		if LayoutsScript.is_dark(lay):
			t = Color(t.r * 0.55, t.g * 0.55, t.b * 0.55)
		_tints[id] = t
		_sides[id] = {}
	for d in _doors:
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
	for id in _ids:
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
		_build_shape(id)

	_define_props()
	for ob in _obstacles:
		_add_solid(ob["r"], 8)

	for d in _doors:
		if String(d["key"]) != "" and String(d["key"]) != "secret":
			_add_door(d)
		elif String(d["key"]) == "secret":
			_add_secret_curtain(d)
	_spawn_hazards()

	_flames = Node2D.new()
	_flames.material = Fx.glow_material()
	_flames.z_index = 1
	add_child(_flames)
	_flames.draw.connect(_draw_flames)

	_cloth = Node2D.new()
	add_child(_cloth)
	_cloth.draw.connect(_draw_cloth)


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
	if LayoutsScript.is_dark(_lay(id)):
		# dark room: one dim lantern on the north wall instead of torches
		var lamp := PointLight2D.new()
		lamp.texture = Fx.light_texture()
		lamp.texture_scale = 1.4
		lamp.color = Color(1.0, 0.8, 0.5)
		lamp.energy = 0.8
		lamp.height = 30.0
		lamp.position = origin_of(id) + Vector2(576.0, 110.0)
		add_child(lamp)
		_lights.append(lamp)
		return
	var o: Vector2 = origin_of(id)
	for p in [Vector2(62, 62), Vector2(RW - 62.0, 62), Vector2(62, RH - 62.0), Vector2(RW - 62.0, RH - 62.0)]:
		var pos: Vector2 = o + p
		_torches.append(pos)
		var light := PointLight2D.new()
		light.texture = Fx.light_texture()
		light.texture_scale = 1.9
		light.color = _lv["torch"] if _lay(id) != "F" else _lv["torch_boss"]
		light.energy = 1.0
		light.height = 45.0
		light.position = pos
		add_child(light)
		_lights.append(light)


## The hidden room's entrance: a curtain over the gap in the shared wall (no door, no lock).
func _add_secret_curtain(d: Dictionary) -> void:
	var ca: Vector2i = _cells[d["a"]]
	var cb: Vector2i = _cells[d["b"]]
	var delta: Vector2i = cb - ca
	var r := Rect2()
	if delta.x != 0:
		var bx: float = float(maxi(ca.x, cb.x)) * RW
		var cy: float = float(ca.y) * RH + RH * 0.5
		r = Rect2(bx - WALL, cy - GAP * 0.5, 2.0 * WALL, GAP)
	else:
		var by: float = float(maxi(ca.y, cb.y)) * RH
		var cx: float = float(ca.x) * RW + RW * 0.5
		r = Rect2(cx - GAP * 0.5, by - WALL, GAP, 2.0 * WALL)
	_curtains.append(r)
	_secret_rects.append(r)


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
	var wr := Rect2(o + r.position, r.size)
	if _in_shape(wr.get_center()):
		return   # this prop would sit inside a carved wall block
	_obstacles.append({"r": wr, "k": drawn})


func _spawn_hazards() -> void:
	var mode: String = _lv["hazard"]
	if mode == "none":
		return
	var i: int = 0
	for id in _ids:
		var lay: String = _lay(id)
		if LayoutsScript.has_template(lay):
			_template_hazards(id, lay, mode)
			continue
		if mode == "spikes" or mode == "both":
			for h in SPIKES:
				if h[0] == lay:
					_add_hazard(id, "spikes", h, i)
				i += 1
		if mode == "pools" or mode == "both":
			for h in POOLS:
				if h[0] == lay:
					_add_hazard(id, "pool", h, i)
				i += 1


func _add_hazard(id: String, kind: String, h: Array, idx: int) -> void:
	var r: Rect2 = _mr(id, Rect2(float(h[1]), float(h[2]), float(h[3]), float(h[4])))
	if _in_shape(origin_of(id) + r.position + r.size * 0.5):
		return   # inside a carved wall block
	if kind == "pool":
		_lava.append(Rect2(origin_of(id) + r.position, r.size))
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


## Extra templates (Layouts.gd): their props and curtains.
func _props_template(id: String, lay: String) -> void:
	var t: Dictionary = LayoutsScript.TEMPLATES[lay]
	for p in t["props"]:
		_ob(id, float(p[0]), float(p[1]), float(p[2]), float(p[3]), String(p[4]))
	for c in t["curtains"]:
		var r: Rect2 = _mr(id, Rect2(float(c[0]), float(c[1]), float(c[2]), float(c[3])))
		_curtains.append(Rect2(origin_of(id) + r.position, r.size))


## Extra templates: guards and hearts.
func _template_population(id: String, lay: String) -> void:
	var t: Dictionary = LayoutsScript.TEMPLATES[lay]
	for g in t["guards"]:
		_spawn_guard(id, g[0], int(g[1]))
	for h in t["hearts"]:
		_spawn_heart(id, float(h[0]), float(h[1]))
	for l in t.get("loot", []):
		_spawn_loot(id, Vector2(float(l[0]), float(l[1])), String(l[2]), int(l[3]))


## Extra templates: floor traps and lava pools.
func _template_hazards(id: String, lay: String, mode: String) -> void:
	var t: Dictionary = LayoutsScript.TEMPLATES[lay]
	if mode == "spikes" or mode == "both":
		for s in t["spikes"]:
			_add_hazard(id, "spikes", [lay, s[0], s[1], s[2], s[3]], 0)
	if mode == "pools" or mode == "both":
		for p in t["pools"]:
			_add_hazard(id, "pool", [lay, p[0], p[1], p[2], p[3]], 0)


## True when a world point is inside a curtain. Guards only see you there from very close.
func in_curtain(pos: Vector2) -> bool:
	for cu in _curtains:
		if cu.has_point(pos):
			return true
	return false


## Curtain cloth: folds sway slowly. Hidden-room curtains also sparkle faintly.
func _draw_curtain(r: Rect2, secret: bool) -> void:
	_cloth.draw_rect(r, Color(0.32, 0.06, 0.08, 0.92))
	var n: int = maxi(2, int(r.size.x / 14.0))
	for k in n:
		var x: float = r.position.x + (float(k) + 0.5) * r.size.x / float(n)
		var sway: float = sin(_time * 1.6 + float(k) * 0.9 + r.position.y * 0.01) * 3.0
		_cloth.draw_line(Vector2(x + sway, r.position.y + 4.0), Vector2(x - sway, r.end.y - 4.0), Color(0.18, 0.02, 0.04, 0.8), 3.0)
		_cloth.draw_line(Vector2(x + sway + 4.0, r.position.y + 6.0), Vector2(x - sway + 4.0, r.end.y - 6.0), Color(0.5, 0.1, 0.12, 0.35), 1.5)
	_cloth.draw_line(r.position + Vector2(-4.0, 0.0), Vector2(r.end.x + 4.0, r.position.y), Color(0.6, 0.5, 0.3), 3.0)
	if secret:
		var a: float = 0.35 + 0.35 * sin(_time * 3.0)
		var sp: Vector2 = r.position + r.size * 0.5
		_cloth.draw_circle(sp, 5.0, Color(1.0, 0.9, 0.5, a * 0.5))
		_cloth.draw_circle(sp, 2.0, Color(1.0, 0.95, 0.7, a))


## Everything drawn on the _cloth layer: curtains, lava glow, and the hidden room's decor.
func _draw_cloth() -> void:
	for cu in _curtains:
		_draw_curtain(cu, _secret_rects.has(cu))
	for r in _lava:
		var pulse: float = 0.5 + 0.5 * sin(_time * 2.4 + r.position.x * 0.02)
		_cloth.draw_rect(r.grow(-4.0), Color(1.0, 0.45, 0.1, 0.10 + 0.12 * pulse))
		for k in 2:
			var by: float = fposmod(_time * 0.6 + float(k) * 0.5 + r.position.x * 0.01, 1.0)
			var bx: float = r.position.x + r.size.x * (0.3 + 0.4 * float(k))
			_cloth.draw_circle(Vector2(bx, r.end.y - by * r.size.y), 3.0 - by * 1.5, Color(1.0, 0.8, 0.4, 0.6 * (1.0 - by)))
	if _secret_id != "":
		var o: Vector2 = origin_of(_secret_id)
		_draw_cobwebs(o)
		_draw_chest(o + _mp(_secret_id, Vector2(576.0, 300.0)))


## A treasure chest with a pulsing gold glow.
func _draw_chest(c: Vector2) -> void:
	var glow: float = 0.5 + 0.5 * sin(_time * 2.0)
	_cloth.draw_circle(c, 36.0, Color(1.0, 0.8, 0.3, 0.08 + 0.06 * glow))
	var body := Rect2(c + Vector2(-24.0, -10.0), Vector2(48.0, 28.0))
	_cloth.draw_rect(body, Color(0.36, 0.2, 0.1))
	_cloth.draw_rect(body.grow(-3.0), Color(0.5, 0.3, 0.14))
	_cloth.draw_rect(Rect2(c + Vector2(-24.0, -12.0), Vector2(48.0, 10.0)), Color(0.42, 0.24, 0.12))
	_cloth.draw_rect(Rect2(c + Vector2(-24.0, -10.0), Vector2(48.0, 3.0)), Color(0.95, 0.75, 0.2))
	_cloth.draw_rect(Rect2(c + Vector2(-4.0, -8.0), Vector2(8.0, 12.0)), Color(1.0, 0.82, 0.25))


## Cobwebs in the four corners of the hidden room.
func _draw_cobwebs(o: Vector2) -> void:
	var web := Color(0.85, 0.85, 0.9, 0.22)
	var corners: Array[Vector2] = [Vector2(40.0, 40.0), Vector2(RW - 40.0, 40.0), Vector2(40.0, RH - 40.0), Vector2(RW - 40.0, RH - 40.0)]
	for c in corners:
		var p: Vector2 = o + c
		var ix: float = 1.0 if c.x < RW * 0.5 else -1.0
		var iy: float = 1.0 if c.y < RH * 0.5 else -1.0
		for k in 3:
			var tip: Vector2 = p + Vector2(ix * (34.0 - float(k) * 8.0), iy * (10.0 + float(k) * 12.0))
			_cloth.draw_line(p, tip, web, 1.0)
		var base: float = atan2(iy, ix)
		_cloth.draw_arc(p, 20.0, base - PI * 0.25, base + PI * 0.25, 8, web, 1.0)


## Props for every room, from its layout template (room-local coordinates).
func _define_props() -> void:
	for id in _ids:
		match _lay(id):
			"A":   # Entrance Hall
				_ob(id, 300, 120, 70, 70, "crate")
				_ob(id, 300, 458, 70, 70, "crate")
				_ob(id, 560, 170, 62, 62, "pillar")
				_ob(id, 560, 416, 62, 62, "pillar")
			"B":   # Barracks
				_ob(id, 250, 150, 64, 64, "crate")
				_ob(id, 250, 434, 64, 64, "crate")
				_ob(id, 838, 150, 64, 64, "crate")
				_ob(id, 838, 434, 64, 64, "crate")
				_ob(id, 400, 296, 56, 56, "pillar")
				_ob(id, 696, 296, 56, 56, "pillar")
			"C":   # Archive (bookshelves)
				_ob(id, 190, 90, 56, 330, "shelf")
				_ob(id, 400, 200, 56, 330, "shelf")
				_ob(id, 610, 90, 56, 330, "shelf")
				_ob(id, 820, 200, 56, 330, "shelf")
			"D":   # Armory (weapon racks + crates)
				_ob(id, 300, 100, 200, 40, "rack")
				_ob(id, 300, 508, 200, 40, "rack")
				_ob(id, 652, 100, 200, 40, "rack")
				_ob(id, 652, 508, 200, 40, "rack")
				_ob(id, 420, 290, 64, 64, "crate")
				_ob(id, 668, 290, 64, 64, "crate")
			"E":   # Treasury
				_ob(id, 250, 150, 56, 56, "pillar")
				_ob(id, 846, 150, 56, 56, "pillar")
				_ob(id, 250, 420, 56, 56, "pillar")
				_ob(id, 846, 420, 56, 56, "pillar")
			"F":   # Boss Chamber
				_ob(id, 330, 150, 60, 60, "pillar")
				_ob(id, 330, 438, 60, 60, "pillar")
				_ob(id, 700, 100, 60, 60, "pillar")
				_ob(id, 700, 488, 60, 60, "pillar")
			_:
				_props_template(id, _lay(id))


# ------------------------------------------------------------------ population
func _local(id: String, x: float, y: float) -> Vector2:
	return origin_of(id) + Vector2(x, y)


func _mods() -> Dictionary:
	return {"hp": _lv["hp"], "dmg": _lv["dmg"], "view": _lv["view"], "spd": _lv["spd"], "boss": _lv["boss"],
			"coin": _lv["coin"], "roster": _lv["roster"]}


## Enemy kind for a guard: the start room is always grunts; elsewhere the mix is drawn from the
## level's roster (only the kinds this level uses), so every run and every room differs.
func _kind_for(id: String) -> String:
	_gi += 1
	if _lay(id) == "A":
		return _roll_start_kind()
	return _roll_kind()


## Start room: only gentle enemy kinds (no brutes or shieldbearers), but still varied per level.
## The level's signature enemy is favoured when it is gentle enough.
func _roll_start_kind() -> String:
	var pool: Array = ["grunt"]
	if int(_lv["archer_every"]) > 0:
		pool.append("archer")
	if int(_lv["flyer_every"]) > 0:
		pool.append("flyer")
	if int(_lv.get("hound_every", 0)) > 0:
		pool.append("hound")
	if int(_lv.get("blinder_every", 0)) > 0:
		pool.append("blinder")
	var sig: String = SIGNATURE[clampi(level_idx, 0, SIGNATURE.size() - 1)]
	if sig in ["grunt", "archer", "flyer", "hound", "blinder"]:
		for _i in 3:
			pool.append(sig)
	return String(pool[randi() % pool.size()])


func _roll_kind() -> String:
	var pool: Array = [["grunt", 3.0]]
	if int(_lv["archer_every"]) > 0:
		pool.append(["archer", 1.6])
	if int(_lv["brute_every"]) > 0:
		pool.append(["brute", 1.2])
	if int(_lv["flyer_every"]) > 0:
		pool.append(["flyer", 1.2])
	if int(_lv.get("shield_every", 0)) > 0:
		pool.append(["shield", 1.0])
	if int(_lv.get("hound_every", 0)) > 0:
		pool.append(["hound", 1.0])
	if int(_lv.get("blinder_every", 0)) > 0:
		pool.append(["blinder", 1.0])
	# the level's signature enemy gets a much bigger share
	var sig: String = SIGNATURE[clampi(level_idx, 0, SIGNATURE.size() - 1)]
	var found: bool = false
	for p in pool:
		if String(p[0]) == sig:
			p[1] = float(p[1]) * 4.0
			found = true
	if not found:
		pool.append([sig, 4.0])
	var total: float = 0.0
	for p in pool:
		total += float(p[1])
	var r: float = randf() * total
	for p in pool:
		r -= float(p[1])
		if r <= 0.0:
			return String(p[0])
	return "grunt"


## Room mode: patrol (default), ambush (guards stand still and jump you when you walk in),
## sleep (guards asleep: sneak-kill them), mini (one elite guard). Start and boss rooms are always patrol.
func _mode_for(id: String) -> String:
	if id == _start or id == _boss_id or _lay(id) == "secret":
		return "patrol"
	var r: float = randf()
	if r < 0.2:
		return "ambush"
	if r < 0.4:
		return "sleep"
	if r < 0.5:
		return "mini"
	return "patrol"


## Called by Game when the player enters a room: wakes the ambush of that room once.
func on_room_entered(id: String) -> void:
	if _room_mode.get(id, "") != "ambush" or _ambushed.has(id):
		return
	_ambushed[id] = true
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	for g in _room_guards.get(id, []):
		if is_instance_valid(g) and g.has_method("hear_alert"):
			g.hear_alert(player.global_position)


## Carves this room into a random shape with wall blocks (see SHAPES). The hidden room stays a plain box.
func _build_shape(id: String) -> void:
	if _lay(id) == "secret":
		return
	var names: Array = SHAPES.keys()
	var spec: Dictionary = SHAPES[String(names[randi() % names.size()])]
	var flip_x: bool = randf() < 0.5
	var flip_y: bool = randf() < 0.5
	var sym: String = String(spec["sym"])
	var o: Vector2 = origin_of(id)
	for r in spec["rects"]:
		var base: Rect2 = r
		var variants: Array[Rect2] = [base]
		if sym == "4" or sym == "h":
			variants.append(_flip_rect(base, true, false))
		if sym == "4":
			variants.append(_flip_rect(base, false, true))
			variants.append(_flip_rect(base, true, true))
		for v in variants:
			var f: Rect2 = _flip_rect(v, flip_x, flip_y)
			var wr := Rect2(o + f.position, f.size)
			_shape_rects.append(wr)
			_wall_draw.append(wr)
			_add_solid(wr)


func _flip_rect(r: Rect2, fx: bool, fy: bool) -> Rect2:
	var x: float = RW - r.position.x - r.size.x if fx else r.position.x
	var y: float = RH - r.position.y - r.size.y if fy else r.position.y
	return Rect2(x, y, r.size.x, r.size.y)


## True when a world point is inside (or within `margin` of) one of the carved wall blocks.
func _in_shape(pos: Vector2, margin: float = 0.0) -> bool:
	for r in _shape_rects:
		if r.grow(margin).has_point(pos):
			return true
	return false


## True when the straight line a-b passes through a carved wall block.
func _seg_hits_shape(a: Vector2, b: Vector2) -> bool:
	var steps: int = maxi(2, int(a.distance_to(b) / 24.0))
	for i in steps + 1:
		if _in_shape(a.lerp(b, float(i) / float(steps)), 18.0):
			return true
	return false


## A world position, moved to a free spot of the room if it fell inside a carved wall block.
func _clear_world(id: String, wpos: Vector2) -> Vector2:
	if _in_shape(wpos, 24.0):
		return origin_of(id) + _free_spot(id)
	return wpos


## A power-up orb lying in a room (room-local position).
func _spawn_powerup(id: String, p: Vector2) -> void:
	var pu := Node2D.new()
	pu.set_script(PowerUpScript)
	pu.set("kind", "haste" if randf() < 0.5 else "quiet")
	pu.position = _local(id, p.x, p.y)
	add_child(pu)


## A random open spot in a room (room-local), clear of props so a guard can stand there.
func _free_spot(id: String) -> Vector2:
	var o: Vector2 = origin_of(id)
	var p: Vector2 = Vector2(576.0, 324.0)
	for _i in 60:
		p = Vector2(randf_range(150.0, 1000.0), randf_range(130.0, 520.0))
		var clear: bool = true
		for ob in _obstacles:
			if (ob["r"] as Rect2).grow(90.0).has_point(o + p):
				clear = false
				break
		if clear and not _in_shape(o + p, 70.0):
			return p
	return p


## Extra guards per room: more on later levels, and one more in rooms with few props (open rooms).
func _extra_guard_count(id: String) -> int:
	var n: int = clampi(int(level_idx / 3), 0, 3)
	var props: int = 0
	for ob in _obstacles:
		if room_at((ob["r"] as Rect2).get_center()) == id:
			props += 1
	if props <= 4:
		n += 1
	return n


func _spawn_guard(id: String, route: Array, tier: int, facing: float = 0.0, boss: bool = false, kind: String = "", elite: bool = false) -> void:
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
	# keep waypoints out of the carved wall blocks; a route that would cut through one becomes a stationary guard
	if not boss:
		for pi in pts.size():
			if _in_shape(pts[pi], 30.0):
				pts[pi] = origin_of(id) + _free_spot(id)
		for pi in range(pts.size() - 1):
			if _seg_hits_shape(pts[pi], pts[pi + 1]):
				pts.resize(1)
				break
	# ambush rooms: guards stand and scan until you walk in
	if _cur_mode == "ambush" and not boss and pts.size() > 1:
		pts.resize(1)
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
	g.asleep = _cur_mode == "sleep" and not boss
	add_child(g)
	if elite:
		g.make_elite()
	if not _room_guards.has(id):
		_room_guards[id] = []
	_room_guards[id].append(g)
	g.died.connect(func(guard: Node2D, stealth: bool) -> void: guard_died.emit(guard, stealth))


func _spawn_heart(id: String, x: float, y: float, amount: int = 0) -> void:
	var h := Node2D.new()
	h.set_script(PickupScript)
	h.set("persistent", true)
	h.set("heal_amount", amount if amount > 0 else int(_lv["heart"]))
	var v: Vector2 = _mp(id, Vector2(x, y))
	h.position = _clear_world(id, _local(id, v.x, v.y))
	add_child(h)


func _spawn_key(id: String, x: float, y: float, kind: String) -> void:
	var k := Node2D.new()
	k.set_script(KeyScript)
	k.set("kind", kind)
	var v: Vector2 = _mp(id, Vector2(x, y))
	k.position = _clear_world(id, _local(id, v.x, v.y))
	add_child(k)


func _spawn_loot(id: String, v: Vector2, kind: String, value: int) -> void:
	var l = LootScript.new()
	l.kind = kind
	l.value = value
	l.persistent = true
	var p: Vector2 = _mp(id, v)
	l.position = _clear_world(id, _local(id, p.x, p.y))
	add_child(l)


## Boss summons: called through the "arena" group.
func spawn_minions(_pos: Vector2, kind: String, n: int) -> void:
	var alive: int = 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if bool(e.get("is_minion")):
			alive += 1
	if alive >= 4:
		return
	for i in n:
		var g = GuardScript.new()
		# minions appear at random open spots across the boss room, not on top of the boss
		var p: Vector2 = origin_of(_boss_id) + _free_spot(_boss_id)
		var pts: Array[Vector2] = [p]
		g.configure(pts, 0, false, 0.0)
		g.apply_kind(kind, _mods())
		g.is_minion = true
		g.position = p
		add_child(g)
		g.died.connect(func(guard: Node2D, stealth: bool) -> void: guard_died.emit(guard, stealth))
		g.force_chase()


## Call AFTER the player is in the tree (guards look for the "player" group in _ready).
## Guards, hearts, keys, loot and extra guards for every room. The content of each room comes from its
## layout template; the keys and the revive kit go to the rooms chosen for this run.
func populate() -> void:
	_gi = 0
	var extras: Array = _lv["extras"]
	for id in _ids:
		var lay: String = _lay(id)
		_cur_mode = _mode_for(id)
		_room_mode[id] = "boss" if id == _boss_id else _cur_mode
		match lay:
			"A":
				_spawn_guard(id, [Vector2(660, 140), Vector2(660, 510)], 0)
				_spawn_heart(id, 110, 560)
			"B":
				_spawn_guard(id, [Vector2(180, 100), Vector2(950, 100)], 0)
				_spawn_guard(id, [Vector2(950, 548), Vector2(180, 548)], 0)
				_spawn_heart(id, 1070, 90)
			"C":
				_spawn_guard(id, [Vector2(533, 130), Vector2(533, 560)], 2)
				_spawn_guard(id, [Vector2(743, 560), Vector2(743, 130)], 2)
				_spawn_guard(id, [Vector2(990, 330)], 2, PI)
				_spawn_heart(id, 100, 560)
			"D":
				_spawn_guard(id, [Vector2(200, 200), Vector2(200, 450)], 1)
				_spawn_guard(id, [Vector2(576, 200), Vector2(576, 450)], 1)
				_spawn_guard(id, [Vector2(950, 150), Vector2(950, 500)], 1)
				_spawn_heart(id, 1070, 570)
			"E":
				_spawn_guard(id, [Vector2(200, 330), Vector2(950, 330)], 3)
				_spawn_guard(id, [Vector2(576, 230)], 3, PI * 0.5)
				_spawn_heart(id, 110, 570)
				_spawn_heart(id, 1040, 570)
			"F":
				_spawn_guard(id, [Vector2(520, 200), Vector2(520, 450)], 1)
				_spawn_guard(id, [Vector2(880, 140)], 1, PI * 0.5)
				_spawn_guard(id, [Vector2(880, 324)], 1, PI, true)
				_spawn_heart(id, 110, 90)
				_spawn_heart(id, 110, 560)
				_spawn_heart(id, 1050, 560, int(_lv["heart"]) + 10)
			_:
				_template_population(id, lay)
		# loot: coins everywhere, a bundle of arrows in every room except the start
		for cs in COIN_SPOTS:
			_spawn_loot(id, cs, "coin", int(_lv["coin"]))
		if id != _start:
			_spawn_loot(id, ARROW_SPOT, "arrows", 6)
		# extra (level) guards, from the layout's patrol route
		for e in extras:
			if String(e[0]) == lay:
				_spawn_guard(id, LevelsScript.EXTRA_ROUTES[lay], 1, 0.0, false, String(e[1]))
		# open-room extras (stationary guards on free spots), and the mini-boss elite of a "mini" room
		if id != _start and id != _boss_id and lay != "secret":
			for _i in _extra_guard_count(id):
				_spawn_guard(id, [_free_spot(id)], 1)
			if _room_mode[id] == "mini":
				_spawn_guard(id, [_free_spot(id)], 2, 0.0, false, "", true)
		# bonus: a power-up in some rooms, and from level 3 a curtain to hide behind
		if id != _start and id != _boss_id and lay != "secret":
			if randf() < 0.3:
				_spawn_powerup(id, _free_spot(id))
			if level_idx >= 2 and randf() < 0.5:
				var cp: Vector2 = _free_spot(id)
				_curtains.append(Rect2(origin_of(id) + cp - Vector2(40.0, 50.0), Vector2(80.0, 100.0)))
	# the two keys: the spot inside each room depends on its layout
	_spawn_key(_bronze_key_room, _key_spot(_bronze_key_room).x, _key_spot(_bronze_key_room).y, "bronze")
	_spawn_key(_gold_key_room, _key_spot(_gold_key_room).x, _key_spot(_gold_key_room).y, "gold")
	_spawn_bells()


## Bells (levels that have "bells" in Levels.gd): one bell in each of that many random rooms.
func _spawn_bells() -> void:
	var n: int = int(_lv.get("bells", 0))
	var rooms: Array = []
	for id in _ids:
		if id != _start and id != _boss_id and _lay(id) != "secret":
			rooms.append(id)
	rooms.shuffle()
	for i in mini(n, rooms.size()):
		var id: String = rooms[i]
		var b := Node2D.new()
		b.set_script(BellScript)
		b.position = origin_of(id) + _free_spot(id)
		add_child(b)


## Where a key lies in its room (room-local). Layouts B, C and D keep the north-east corner clear.
func _key_spot(id: String) -> Vector2:
	var lay: String = _lay(id)
	if LayoutsScript.has_template(lay) and LayoutsScript.TEMPLATES[lay].has("key"):
		var k: Array = LayoutsScript.TEMPLATES[lay]["key"]
		return Vector2(float(k[0]), float(k[1]))
	if lay in ["B", "C", "D"]:
		return Vector2(1030, 110)
	return Vector2(576, 105)


# ------------------------------------------------------------------ effects
func _process(delta: float) -> void:
	_time += delta
	for i in _lights.size():
		var flick: float = sin(_time * 9.0 + float(i) * 1.7) * 0.10 + sin(_time * 23.0 + float(i) * 3.1) * 0.06
		_lights[i].energy = 1.0 + flick
	if _flames:
		_flames.queue_redraw()
	if _cloth:
		_cloth.queue_redraw()


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
	for id in _ids:
		var o: Vector2 = origin_of(id)
		var tint: Color = _tints[id]
		var base: Color = _lv["floor"]
		var mod := Color(clampf(tint.r / base.r, 0.4, 2.0), clampf(tint.g / base.g, 0.4, 2.0), clampf(tint.b / base.b, 0.4, 2.0), 1.0)
		draw_texture_rect(_floor_tex, Rect2(o, Vector2(RW, RH)), true, mod)
		# rug / rune circle for flavour
		var c: Vector2 = o + Vector2(RW, RH) * 0.5
		if _lay(id) == "F":
			var br: Color = _lv["boss_rune"]
			draw_arc(c + Vector2(260, 0), 150.0, 0.0, TAU, 64, Color(br, 0.30), 4.0)
			draw_arc(c + Vector2(260, 0), 120.0, 0.0, TAU, 64, Color(br, 0.2), 2.0)
		elif _lay(id) == "A" or _lay(id) == "E":
			draw_arc(c, 120.0, 0.0, TAU, 64, _lv["rune"], 3.0)
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
		elif dc["k"] == "ash":
			draw_line(dp, dp + Vector2.from_angle(ds) * dl * 0.5, Color(0.12, 0.11, 0.11, 0.55), 3.0)
			draw_circle(dp + Vector2(dl * 0.3, 2.0), 2.0, Color(0.5, 0.48, 0.45, 0.4))
		elif dc["k"] == "spores":
			draw_circle(dp, dl * 0.32, Color(0.5, 0.85, 0.35, 0.12))
			draw_circle(dp, 2.2, Color(0.75, 1.0, 0.5, 0.45))
		elif dc["k"] == "petals":
			draw_circle(dp, 3.0, Color(1.0, 0.7, 0.75, 0.5))
			draw_circle(dp + Vector2(4.0, 2.0), 2.4, Color(1.0, 0.85, 0.85, 0.45))
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
	if kind in ["tomb", "bones", "ice", "forge", "hotpillar", "obelisk", "bush", "tree", "hedge", "cactus", "sandpillar", "sandrock", "rubble", "brokenpillar", "mushroom", "logs", "crystal", "gear", "pipes", "coral", "marble"]:
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


## Diamond-shaped gems along the long side of a rect (crystal clusters).
func _gems(r: Rect2, base: Color, hi: Color) -> void:
	draw_rect(r, base.darkened(0.6))
	var cell: float = minf(r.size.x, r.size.y)
	var n: int = maxi(1, int(maxf(r.size.x, r.size.y) / cell))
	for k in n:
		var cc: Vector2
		if r.size.x >= r.size.y:
			cc = Vector2(r.position.x + (float(k) + 0.5) * r.size.x / float(n), r.get_center().y)
		else:
			cc = Vector2(r.get_center().x, r.position.y + (float(k) + 0.5) * r.size.y / float(n))
		var hw: float = cell * 0.5 - 3.0
		draw_colored_polygon(PackedVector2Array([cc + Vector2(0, -hw * 1.15), cc + Vector2(hw, 0), cc + Vector2(0, hw * 1.15), cc + Vector2(-hw, 0)]), base)
		draw_colored_polygon(PackedVector2Array([cc + Vector2(0, -hw * 0.8), cc + Vector2(hw * 0.5, 0), cc + Vector2(0, hw * 0.2), cc + Vector2(-hw * 0.3, -hw * 0.1)]), hi)


func _draw_prop_extra(r: Rect2, kind: String) -> void:
	match kind:
		"rubble":
			var rc: Vector2 = r.get_center()
			var pts := PackedVector2Array()
			for j in 12:
				var an: float = TAU * float(j) / 12.0
				var jit: float = 0.82 + 0.18 * sin(float(j) * 3.1 + r.position.y)
				pts.append(rc + Vector2(cos(an) * r.size.x * 0.52 * jit, sin(an) * r.size.y * 0.52 * jit))
			draw_colored_polygon(pts, Color(0.12, 0.10, 0.09))
			var inner := PackedVector2Array()
			for q in pts:
				inner.append(rc + (q - rc) * 0.82)
			draw_colored_polygon(inner, Color(0.36, 0.31, 0.27))
			draw_line(rc + Vector2(-r.size.x * 0.25, -2), rc + Vector2(r.size.x * 0.2, r.size.y * 0.2), Color(0.1, 0.08, 0.07), 2.0)
			draw_circle(rc + Vector2(r.size.x * 0.18, -r.size.y * 0.18), 5.0, Color(0.5, 0.44, 0.38))
		"brokenpillar":
			draw_rect(r, Color(0.09, 0.08, 0.08))
			draw_rect(r.grow(-4.0), Color(0.45, 0.42, 0.38))
			draw_colored_polygon(PackedVector2Array([r.position + Vector2(0, 0), r.position + Vector2(r.size.x * 0.4, 0), r.position + Vector2(r.size.x * 0.2, r.size.y * 0.35), r.position + Vector2(0, r.size.y * 0.2)]), Color(0.06, 0.05, 0.05))
			draw_line(r.position + Vector2(r.size.x * 0.5, 6), r.position + Vector2(r.size.x * 0.4, r.size.y * 0.7), Color(0.2, 0.18, 0.16), 2.0)
		"mushroom":
			var mc: Color = Color(0.45, 0.22, 0.55)
			_blobs(r, Color(0.14, 0.06, 0.18), mc, Color(0.85, 0.65, 0.95))
			var mm: Vector2 = r.get_center()
			for j in 3:
				draw_circle(mm + Vector2.from_angle(float(j) * 2.1 + r.position.x) * minf(r.size.x, r.size.y) * 0.22, 3.2, Color(0.95, 0.92, 0.7))
		"logs":
			draw_rect(r, Color(0.10, 0.06, 0.04))
			draw_rect(r.grow(-4.0), Color(0.36, 0.22, 0.12))
			if r.size.x >= r.size.y:
				var gx: float = r.position.y + 10.0
				while gx < r.end.y - 6.0:
					draw_line(Vector2(r.position.x + 5.0, gx), Vector2(r.end.x - 5.0, gx), Color(0.22, 0.13, 0.07), 2.0)
					gx += 12.0
			else:
				var gy: float = r.position.x + 10.0
				while gy < r.end.x - 6.0:
					draw_line(Vector2(gy, r.position.y + 5.0), Vector2(gy, r.end.y - 5.0), Color(0.22, 0.13, 0.07), 2.0)
					gy += 12.0
		"crystal":
			_gems(r, Color(0.55, 0.35, 0.9), Color(0.92, 0.85, 1.0, 0.85))
		"gear":
			var gc: Vector2 = r.get_center()
			var gr: float = minf(r.size.x, r.size.y) * 0.5
			draw_circle(gc, gr, Color(0.12, 0.09, 0.05))
			for j in 10:
				var ga: float = TAU * float(j) / 10.0 + _time * 0.5
				draw_colored_polygon(PackedVector2Array([gc + Vector2.from_angle(ga - 0.16) * gr, gc + Vector2.from_angle(ga - 0.12) * (gr + 5.0), gc + Vector2.from_angle(ga + 0.12) * (gr + 5.0), gc + Vector2.from_angle(ga + 0.16) * gr]), Color(0.7, 0.5, 0.2))
			draw_circle(gc, gr - 3.0, Color(0.62, 0.45, 0.2))
			draw_circle(gc, gr * 0.45, Color(0.2, 0.14, 0.07))
			draw_circle(gc, gr * 0.2, Color(0.85, 0.7, 0.35))
		"pipes":
			draw_rect(r, Color(0.07, 0.07, 0.08))
			draw_rect(r.grow(-3.0), Color(0.40, 0.33, 0.25))
			var long_x: bool = r.size.x >= r.size.y
			var pp: float = (r.position.x if long_x else r.position.y) + 12.0
			var pe: float = (r.end.x if long_x else r.end.y) - 8.0
			while pp < pe:
				if long_x:
					draw_line(Vector2(pp, r.position.y + 4.0), Vector2(pp, r.end.y - 4.0), Color(0.22, 0.18, 0.13), 3.0)
					draw_circle(Vector2(pp, r.get_center().y), 2.4, Color(0.8, 0.65, 0.3))
				else:
					draw_line(Vector2(r.position.x + 4.0, pp), Vector2(r.end.x - 4.0, pp), Color(0.22, 0.18, 0.13), 3.0)
					draw_circle(Vector2(r.get_center().x, pp), 2.4, Color(0.8, 0.65, 0.3))
				pp += 22.0
		"coral":
			_blobs(r, Color(0.35, 0.08, 0.2), Color(0.95, 0.4, 0.45), Color(1.0, 0.8, 0.7))
			var cm: Vector2 = r.get_center()
			for j in 4:
				var ca: float = float(j) * 1.7 + r.position.y
				draw_line(cm, cm + Vector2.from_angle(ca) * minf(r.size.x, r.size.y) * 0.6, Color(1.0, 0.55, 0.5), 3.0)
		"marble":
			draw_rect(r, Color(0.35, 0.3, 0.2))
			draw_rect(r.grow(-3.0), Color(0.9, 0.88, 0.82))
			draw_rect(r.grow(-9.0), Color(0.96, 0.94, 0.9))
			draw_rect(r.grow(-3.0), Color(0.85, 0.7, 0.3), false, 2.0)
			draw_line(r.position + Vector2(r.size.x * 0.3, 8), r.position + Vector2(r.size.x * 0.5, r.size.y * 0.5), Color(0.7, 0.7, 0.75, 0.6), 1.5)
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
		elif dc["k"] == "sparkle":
			var tw: float = 0.5 + 0.5 * sin(_time * 2.6 + ds * 3.0)
			_flames.draw_line(dp + Vector2(-dl * 0.3, 0), dp + Vector2(dl * 0.3, 0), Color(1.2, 1.0, 2.0, 0.6 * tw), 2.0)
			_flames.draw_line(dp + Vector2(0, -dl * 0.3), dp + Vector2(0, dl * 0.3), Color(1.2, 1.0, 2.0, 0.6 * tw), 2.0)
		elif dc["k"] == "sparks":
			var sp2: float = fposmod(_time * 1.4 + ds, 1.0)
			_flames.draw_circle(dp + Vector2.from_angle(ds) * dl * sp2, 2.2, Color(2.0, 1.3, 0.4, 1.0 - sp2))
		elif dc["k"] == "bubbles":
			var bb: float = fposmod(_time * 0.35 + ds, 1.0)
			_flames.draw_arc(dp + Vector2(sin(ds + bb * 6.0) * 6.0, -bb * 60.0), 3.0 + dl * 0.1, 0.0, TAU, 10, Color(0.6, 1.2, 1.6, 0.7 * (1.0 - bb)), 1.5)
		elif dc["k"] == "void":
			var op: Vector2 = dp + Vector2(sin(_time * 0.8 + ds), cos(_time * 0.6 + ds)) * 10.0
			_flames.draw_circle(op, 3.0, Color(1.2, 0.4, 1.8, 0.45 + 0.3 * sin(_time * 2.0 + ds)))
	for i in _torches.size():
		var pos: Vector2 = _torches[i]
		var f: float = 1.0 + sin(_time * 12.0 + float(i) * 2.0) * 0.12 + sin(_time * 31.0 + float(i)) * 0.06
		_flames.draw_circle(pos, 15.0 * f, Color(1.0, 0.45, 0.1, 0.16))
		_flames.draw_circle(pos, 9.0 * f, Color(1.8, 0.8, 0.25, 0.85))
		_flames.draw_circle(pos + Vector2(0, -2), 5.0 * f, Color(2.2, 1.7, 0.7, 0.95))
