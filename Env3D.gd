extends CanvasLayer
## Env3D.gd — 3D Emberfall backdrop in a SubViewport under the 2D game.
## 2D physics/Camera2D unchanged. Maps 2D (x,y) → 3D (x,0,y).

const Levels3DScript := preload("res://Levels3D.gd")

const PX_TO_M := 2.0 / 64.0
const TILE_M := 2.0

var _preset: Dictionary = {}
var _dungeon: Node2D
var _player: Node2D
var _svpc: SubViewportContainer
var _svp: SubViewport
var _root3: Node3D
var _cam: Camera3D
var _pivot: Node3D
var _prop_root: Node3D
var _lights: Array[SpotLight3D] = []
var _weather: GPUParticles3D
var _active: bool = false
var _meshes: Dictionary = {}
var _flicker_t: float = 0.0
var _buckets: Dictionary = {}
var _room_lights: Dictionary = {}
var _focus_room: String = ""
var _hero_light: OmniLight3D
var _room_tris: Dictionary = {}
var _room_draws: Dictionary = {}
var _room_origin: Dictionary = {}
var _tri_cache: Dictionary = {}
var _floor_mat: ShaderMaterial
var _wall_mat: ShaderMaterial
var _water_mat: ShaderMaterial
var _prop_mats: Dictionary = {}
var _room_props: Dictionary = {}
const LavaShader := preload("res://shaders/lava_crust.gdshader")
const SurfaceShader := preload("res://shaders/env_surface.gdshader")
const WaterShader := preload("res://shaders/water_gloss.gdshader")
const HazeShader := preload("res://shaders/heat_haze.gdshader")
const _KEEP_MAT := {
	"lava_plane": true, "lava_haze": true, "water": true, "contact": true,
	"floor_a": true, "wall_straight": true,
	"glow_mushroom": true, "crystal_cluster": true, "crystal_cyan": true, "crystal_pink": true,
	"geode": true, "stalactite": true, "shards": true, "torch": true, "brazier": true, "cauldron": true,
}
const _PROP_TINT := {
	"crate": Color(0.78, 0.5, 0.26),
	"barrel": Color(0.7, 0.42, 0.2),
	"skull": Color(0.82, 0.76, 0.64),
	"bone_pile": Color(0.78, 0.72, 0.58),
	"pillar": Color(0.55, 0.5, 0.46),
	"statue": Color(0.5, 0.46, 0.42),
	"banner": Color(0.85, 0.28, 0.14),
	"grave": Color(0.72, 0.74, 0.66),
	"gravestone": Color(0.78, 0.8, 0.72),
	"log": Color(0.62, 0.4, 0.22),
	"roots": Color(0.5, 0.32, 0.16),
	"swamp_tree": Color(0.4, 0.5, 0.28),
	"cave_rock": Color(0.45, 0.4, 0.55),
	"rubble": Color(0.4, 0.32, 0.26),
	"buttress": Color(0.35, 0.28, 0.24),
	"alcove": Color(0.22, 0.16, 0.14),
	"weapon_rack": Color(0.4, 0.24, 0.12),
	"cage": Color(0.35, 0.28, 0.18),
	"reeds": Color(0.55, 0.75, 0.32),
	"chains": Color(0.25, 0.24, 0.26),
	"cobweb": Color(0.7, 0.7, 0.65),
}
const _HANG := {
	"chains": 2.35,
	"cobweb": 2.5,
	"hanging_moss": 3.15,
	"stalactite": 3.35,
	"banner": 0.0,
}


func setup(dungeon: Node2D, player: Node2D, level_idx: int) -> void:
	layer = -1
	_dungeon = dungeon
	_player = player
	_preset = Levels3DScript.for_level(level_idx)
	if _preset.is_empty():
		_active = false
		visible = false
		return
	if not _load_kit(String(_preset["kit"])):
		push_warning("Env3D: kit GLBs missing — 2D fallback")
		_active = false
		visible = false
		return
	_ensure_viewport()
	_build_environment()
	_build_from_dungeon()
	_setup_camera()
	_setup_weather()
	_active = true
	visible = true
	if _dungeon.has_method("set_env3d_overlay"):
		_dungeon.set_env3d_overlay(true)


func is_active() -> bool:
	return _active


func _ensure_viewport() -> void:
	if _svpc and is_instance_valid(_svpc):
		return
	_svpc = SubViewportContainer.new()
	_svpc.stretch = true
	_svpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_svpc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_svpc)

	_svp = SubViewport.new()
	_svp.transparent_bg = false
	_svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_svp.world_3d = World3D.new()
	_svp.size = Vector2i(1280, 720)
	_svpc.add_child(_svp)

	_root3 = Node3D.new()
	_root3.name = "EnvRoot"
	_svp.add_child(_root3)


func _load_one(path: String, name: String) -> void:
	# load() imports the GLB even when ResourceLoader.exists is still false.
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return
	var inst := packed.instantiate()
	var mesh := _find_mesh(inst)
	if mesh:
		_meshes[name] = mesh
	inst.free()


func _load_kit(kit_dir: String) -> bool:
	_meshes.clear()
	var names: Array = [
		"floor_a", "wall_straight", "pillar", "crate", "lava_plane",
		"ceiling_beam", "stairs", "pit",
	]
	for key in ["dressing", "accent_piece", "boss_piece", "outdoor_piece", "ceiling_piece"]:
		var v = _preset.get(key, [])
		if v is String and String(v) != "":
			names.append(v)
		elif v is Array:
			for n in v:
				names.append(n)
	for name in names:
		var path := kit_dir + String(name) + ".glb"
		if FileAccess.file_exists(path):
			_load_one(path, String(name))
	return _meshes.has("floor_a") and _meshes.has("wall_straight")


func _find_mesh(n: Node) -> Mesh:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		return (n as MeshInstance3D).mesh
	for c in n.get_children():
		var m := _find_mesh(c)
		if m:
			return m
	return null


func _to3(p: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(p.x * PX_TO_M, y, p.y * PX_TO_M)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(_preset["fog_color"].r * 0.45, _preset["fog_color"].g * 0.4, _preset["fog_color"].b * 0.35)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _preset["ambient"]
	env.ambient_light_energy = float(_preset["ambient_energy"]) * float(_preset.get("lighting_boost", 1.0))
	env.fog_enabled = true
	env.fog_light_color = _preset["fog_color"]
	env.fog_density = float(_preset["fog_density"])
	env.glow_enabled = true
	env.glow_intensity = 0.28
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	_root3.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = _preset["sun_color"]
	sun.light_energy = float(_preset["sun_energy"])
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 28.0
	sun.shadow_bias = 0.08
	sun.rotation_degrees = Vector3(float(_preset["sun_pitch_deg"]), 35.0, 0.0)
	_root3.add_child(sun)

	# Unshadowed rim so walls and props separate from the dark without a second shadow map.
	var rim := DirectionalLight3D.new()
	rim.light_color = _preset["fog_color"].lightened(0.35)
	rim.light_energy = 0.45
	rim.shadow_enabled = false
	rim.rotation_degrees = Vector3(-28.0, -150.0, 0.0)
	_root3.add_child(rim)

	_hero_light = OmniLight3D.new()
	_hero_light.light_color = Color(1.0, 0.92, 0.8)
	_hero_light.light_energy = 0.9
	_hero_light.omni_range = 5.0
	_hero_light.shadow_enabled = false
	_root3.add_child(_hero_light)

	_pivot = Node3D.new()
	_root3.add_child(_pivot)
	_prop_root = Node3D.new()
	_pivot.add_child(_prop_root)


func _mesh_tris(mesh: Mesh) -> int:
	var key := mesh.get_instance_id()
	if _tri_cache.has(key):
		return int(_tri_cache[key])
	var n := 0
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var idx = arrays[Mesh.ARRAY_INDEX]
		if idx != null and idx.size() > 0:
			n += int(idx.size() / 3)
		else:
			var verts = arrays[Mesh.ARRAY_VERTEX]
			if verts != null:
				n += int(verts.size() / 3)
	_tri_cache[key] = n
	return n


func _room_of(p: Vector2) -> String:
	if _dungeon.has_method("room_at"):
		var id := String(_dungeon.room_at(p))
		if id != "":
			return id
	var best := "world"
	var best_d := 1.0e12
	for id in _dungeon.room_ids():
		var o: Vector2 = _dungeon.origin_of(id)
		var d := (o + Vector2(576.0, 324.0)).distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = String(id)
	return best


func _origin3(room_id: String) -> Vector3:
	if _room_origin.has(room_id):
		return _room_origin[room_id]
	var c := Vector3.ZERO
	if _dungeon.room_ids().has(room_id):
		var o: Vector2 = _dungeon.origin_of(room_id)
		c = _to3(o + Vector2(576.0, 324.0), 0.0)
	_room_origin[room_id] = c
	return c


func _queue(piece: String, pos: Vector2, yaw: float, scale: Vector3, height: float) -> void:
	if not _meshes.has(piece):
		return
	var room := _room_of(pos)
	if not _buckets.has(room):
		_buckets[room] = {}
	var bag: Dictionary = _buckets[room]
	if not bag.has(piece):
		bag[piece] = []
	var basis := Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(scale)
	var local := _to3(pos, height) - _origin3(room)
	(bag[piece] as Array).append(Transform3D(basis, local))


func _emit(holder: Node3D, room: String, piece: String, xforms: Array, shadow: bool) -> void:
	if xforms.is_empty() or not _meshes.has(piece):
		return
	var mesh: Mesh = _meshes[piece]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.visibility_range_end = 40.0
	mi.visibility_range_end_margin = 6.0
	mi.lod_bias = 1.35
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if piece == "lava_plane":
		var mat := ShaderMaterial.new()
		mat.shader = LavaShader
		mi.material_override = mat
	elif piece == "lava_haze":
		var haze := ShaderMaterial.new()
		haze.shader = HazeShader
		mi.material_override = haze
	elif piece == "water":
		mi.material_override = _water_mat
	elif piece == "contact":
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color(0.012, 0.008, 0.008)
		dark.roughness = 1.0
		dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = dark
	elif piece == "floor_a" and _floor_mat != null:
		mi.material_override = _floor_mat
	elif piece == "wall_straight" and _wall_mat != null:
		mi.material_override = _wall_mat
	elif not _KEEP_MAT.has(piece):
		mi.material_override = _prop_material(piece)
	holder.add_child(mi)
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	_room_tris[room] = int(_room_tris.get(room, 0)) + _mesh_tris(mesh) * xforms.size()
	if piece != "floor_a" and piece != "wall_straight" and piece != "contact" and piece != "lava_haze":
		_room_props[room] = int(_room_props.get(room, 0)) + xforms.size()
	# One draw per surface (a mesh with stalk/cap/spots is more than one call).
	_room_draws[room] = int(_room_draws.get(room, 0)) + maxi(mesh.get_surface_count(), 1)


func _make_surface(prefix: String, scale: float, wet: float, mix_amt: float, value: float, rim: float, veins: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SurfaceShader
	mat.set_shader_parameter("albedo", load(String(_preset.get(prefix + "_albedo", ""))))
	mat.set_shader_parameter("detail", load(String(_preset.get(prefix + "_detail", ""))))
	mat.set_shader_parameter("rough_tex", load(String(_preset.get(prefix + "_rough", ""))))
	mat.set_shader_parameter("normal_tex", load(String(_preset.get(prefix + "_normal", ""))))
	var tint: Color = _preset.get(prefix + "_tint", _preset.get("surface_tint", Color(1, 1, 1)))
	mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	mat.set_shader_parameter("uv_scale", scale)
	mat.set_shader_parameter("detail_mix", mix_amt)
	mat.set_shader_parameter("wet_strength", wet)
	mat.set_shader_parameter("value", value)
	mat.set_shader_parameter("top_rim", rim)
	mat.set_shader_parameter("vein", veins)
	var world := String(_preset.get("id", ""))
	if world == "whispering_mire":
		mat.set_shader_parameter("rim_color", Vector3(0.78, 0.95, 0.62))
		mat.set_shader_parameter("vein_color", Vector3(0.25, 0.7, 0.35))
	elif world == "crystal_deep":
		mat.set_shader_parameter("rim_color", Vector3(0.72, 0.7, 0.95))
		mat.set_shader_parameter("vein_color", Vector3(0.45, 0.75, 1.0))
	return mat


func _prop_material(piece: String) -> ShaderMaterial:
	if _prop_mats.has(piece):
		return _prop_mats[piece]
	var mat := _make_surface("floor", 0.55, 0.05, 0.25, 1.0, 0.0, 0.0)
	var tint: Color = _PROP_TINT.get(piece, Color(0.55, 0.5, 0.45))
	mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	_prop_mats[piece] = mat
	return mat


func _flush() -> void:
	if _floor_mat == null and _preset.has("floor_albedo"):
		var wet := float(_preset.get("wet_strength", 0.15))
		var world_id := String(_preset.get("id", ""))
		var veins := 0.9 if world_id == "crystal_deep" else 0.0
		var floor_value := 1.5 if world_id == "whispering_mire" else 1.2
		_floor_mat = _make_surface("floor", 0.16, wet, 0.4, floor_value, 0.0, 0.0)
		_wall_mat = _make_surface("wall", 0.2, wet * 0.25, 0.55, 0.5, 1.0, veins)
		_water_mat = ShaderMaterial.new()
		_water_mat.shader = WaterShader
		if String(_preset.get("id", "")) == "crystal_deep":
			_water_mat.set_shader_parameter("deep", Vector3(0.16, 0.22, 0.4))
			_water_mat.set_shader_parameter("glaze", Vector3(0.78, 0.88, 1.0))
	for room in _buckets.keys():
		var bag: Dictionary = _buckets[room]
		var holder := Node3D.new()
		holder.position = _origin3(String(room))
		_prop_root.add_child(holder)
		for piece in bag.keys():
			var piece_name := String(piece)
			var shadow: bool = piece_name == "floor_a" or piece_name == "wall_straight"
			_emit(holder, String(room), piece_name, bag[piece], shadow)
	_buckets.clear()


func _build_from_dungeon() -> void:
	var contact := PlaneMesh.new()
	contact.size = Vector2(2.05, 0.7)
	_meshes["contact"] = contact
	var water := PlaneMesh.new()
	water.size = Vector2(2.4, 2.4)
	_meshes["water"] = water
	if _meshes.has("lava_plane"):
		_meshes["lava_haze"] = _meshes["lava_plane"]
	for id in _dungeon.room_ids():
		var o: Vector2 = _dungeon.origin_of(id)
		var cols := int(ceil(1152.0 / 64.0))
		var rows := int(ceil(648.0 / 64.0))
		for cy in rows:
			for cx in cols:
				var px := o + Vector2((cx + 0.5) * 64.0, (cy + 0.5) * 64.0)
				_queue("floor_a", px, 0.0, Vector3.ONE, 0.0)
		var ceil_piece := String(_preset.get("ceiling_piece", ""))
		if _meshes.has(ceil_piece):
			var along_wall := ceil_piece == "ceiling_beam"
			var ch := 3.55 if along_wall else 3.4
			var ceil_spots: Array[Vector2] = [
				Vector2(280, 70), Vector2(860, 70), Vector2(300, 575), Vector2(880, 580),
			]
			for i in ceil_spots.size():
				var cp: Vector2 = o + ceil_spots[i]
				_queue(ceil_piece, cp, 0.0 if i < 2 else PI, Vector3(1.6, 1.0, 1.0) if along_wall else Vector3.ONE, ch)

	var walls: Array = _dungeon.wall_rects_world() if _dungeon.has_method("wall_rects_world") else []
	for r in walls:
		var rect: Rect2 = r
		if rect.size.x >= rect.size.y:
			var n: int = maxi(1, int(ceil(rect.size.x / 64.0)))
			for i in n:
				var px := Vector2(rect.position.x + (i + 0.5) * (rect.size.x / float(n)), rect.position.y + rect.size.y * 0.5)
				_queue("wall_straight", px, 0.0, Vector3(1.0, 1.65, 2.1), 0.0)
				_queue("contact", px, 0.0, Vector3(1.05, 1.0, 1.0), 0.03)
		else:
			var n2: int = maxi(1, int(ceil(rect.size.y / 64.0)))
			for i in n2:
				var px2 := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + (i + 0.5) * (rect.size.y / float(n2)))
				_queue("wall_straight", px2, PI * 0.5, Vector3(1.0, 1.65, 2.1), 0.0)
				_queue("contact", px2, PI * 0.5, Vector3(1.05, 1.0, 1.0), 0.03)

	_place_props()
	_place_lava()
	_place_torches()
	_place_outdoor()
	_place_boss_arena()
	_flush()


func _place_props() -> void:
	var dressing: Array = _preset.get("dressing", ["rubble", "torch", "skull"])
	var accent: String = String(_preset.get("accent_piece", ""))
	# Visible floor from the 3/4 camera: north and center of the room, off the player.
	# Level camera looks at x=170. Boss camera looks at the room center (x=576).
	# Both bands stay on the open floor (y 230-450).
	var spots := [
		Vector2(190, 240), Vector2(290, 250), Vector2(390, 230), Vector2(490, 250),
		Vector2(180, 330), Vector2(280, 340), Vector2(380, 320), Vector2(480, 340),
		Vector2(200, 420), Vector2(300, 430), Vector2(400, 410), Vector2(500, 430),
		Vector2(600, 250), Vector2(700, 240), Vector2(800, 260),
		Vector2(610, 340), Vector2(710, 330), Vector2(820, 350),
		Vector2(590, 430), Vector2(700, 420), Vector2(810, 440), Vector2(450, 280),
	]
	for id in _dungeon.room_ids():
		var o: Vector2 = _dungeon.origin_of(id)
		var n := 0
		for s in spots:
			var piece: String = String(dressing[n % dressing.size()])
			if n % 5 == 0 and accent != "" and _meshes.has(accent):
				piece = accent
			var hang := float(_HANG.get(piece, 0.0))
			var scl := randf_range(1.55, 2.05)
			if piece == "banner" or piece == "buttress" or piece == "pillar" or piece == "statue":
				scl = randf_range(1.15, 1.4)
			elif piece.begins_with("crystal"):
				scl = randf_range(2.0, 2.4)
			elif piece == "glow_mushroom":
				scl = randf_range(2.6, 3.2)
			if piece == "stalactite" and n % 2 == 1:
				_queue(piece, o + s, randf() * TAU, Vector3(scl, -scl, scl), 0.0)
			else:
				_queue(piece, o + s, randf() * TAU, Vector3.ONE * scl, hang)
			n += 1
		if _meshes.has("crate"):
			_queue("crate", o + Vector2(280, 340), 0.2, Vector3.ONE * 2.1, 1.35)
			_queue("crate", o + Vector2(300, 325), 0.8, Vector3.ONE * 1.7, 2.5)
		if _meshes.has("swamp_tree") and String(_preset.get("id", "")) == "whispering_mire":
			_queue("swamp_tree", o + Vector2(160, 200), 0.4, Vector3.ONE * 1.15, 0.0)
			_queue("swamp_tree", o + Vector2(990, 210), 1.2, Vector3.ONE * 1.2, 0.0)
	var obstacles: Array = _dungeon.obstacles_world() if _dungeon.has_method("obstacles_world") else []
	for ob in obstacles:
		var rr: Rect2 = ob["r"]
		var kind: String = String(ob.get("k", "crate"))
		var piece := "pillar" if kind.find("pillar") >= 0 or kind.find("obelisk") >= 0 else "crate"
		if not _meshes.has(piece):
			piece = "rubble" if _meshes.has("rubble") else piece
		var sc := clampf(rr.size.x / 64.0, 0.7, 1.35)
		_queue(piece, rr.get_center(), randf() * TAU, Vector3.ONE * sc, 0.0)


func _place_outdoor() -> void:
	if not bool(_preset.get("outdoor", false)):
		return
	var piece: String = String(_preset.get("outdoor_piece", ""))
	if piece == "" or not _meshes.has(piece):
		return
	if not _dungeon.has_method("world_bounds"):
		return
	var wb: Rect2 = _dungeon.world_bounds()
	# Open fringe outside the dungeon rooms (swamp trees or cave crystals).
	var step := 220.0
	var x := wb.position.x - 180.0
	while x < wb.end.x + 180.0:
		_queue(piece, Vector2(x, wb.position.y - 160.0), randf() * TAU, Vector3.ONE * randf_range(0.8, 1.3), 0.0)
		_queue(piece, Vector2(x, wb.end.y + 80.0), randf() * TAU, Vector3.ONE * randf_range(0.8, 1.3), 0.0)
		x += step
	var y := wb.position.y
	while y < wb.end.y:
		_queue(piece, Vector2(wb.position.x - 140.0, y), randf() * TAU, Vector3.ONE * randf_range(0.8, 1.2), 0.0)
		_queue(piece, Vector2(wb.end.x + 60.0, y), randf() * TAU, Vector3.ONE * randf_range(0.8, 1.2), 0.0)
		y += step
	if _meshes.has("puddle"):
		_queue("puddle", wb.position + Vector2(-90, wb.size.y * 0.5), 0.0, Vector3(2.2, 1, 1.6), 0.0)
		_queue("puddle", Vector2(wb.end.x + 40.0, wb.position.y + wb.size.y * 0.4), 0.0, Vector3(1.8, 1, 1.4), 0.0)


func _place_boss_arena() -> void:
	if not bool(_preset.get("boss_arena", false)):
		return
	var piece: String = String(_preset.get("boss_piece", ""))
	if piece == "" or not _meshes.has(piece) or not _dungeon.has_method("boss_id"):
		return
	var bid: String = String(_dungeon.boss_id())
	if bid == "":
		return
	var c: Vector2 = _dungeon.room_center(bid)
	_queue(piece, c + Vector2(180, 0), 0.0, Vector3.ONE * 1.4, 0.0)
	_queue(piece, c + Vector2(-160, 80), 0.4, Vector3.ONE * 1.1, 0.0)
	if _meshes.has("stairs"):
		_queue("stairs", c + Vector2(-280, 170), 0.2, Vector3.ONE, 0.0)
	var accent: String = String(_preset.get("accent_piece", ""))
	if accent != "" and _meshes.has(accent):
		for i in 4:
			var ang := TAU * float(i) / 4.0
			_queue(accent, c + Vector2(cos(ang), sin(ang)) * 220.0, ang, Vector3.ONE * 1.2, 0.0)


func _place_lava() -> void:
	var world := String(_preset.get("id", ""))
	if world == "emberfall" and _meshes.has("lava_plane"):
		for id in _dungeon.room_ids():
			var o: Vector2 = _dungeon.origin_of(id)
			_queue("lava_plane", o + Vector2(300, 200), 0.0, Vector3(3.4, 1.0, 1.2), 0.06)
			_queue("lava_haze", o + Vector2(300, 200), 0.0, Vector3(2.9, 1.0, 0.95), 0.2)
			_queue("lava_plane", o + Vector2(220, 400), 0.4, Vector3(1.55, 1.0, 1.35), 0.06)
			_queue("lava_haze", o + Vector2(220, 400), 0.4, Vector3(1.25, 1.0, 1.05), 0.2)
			_queue("lava_plane", o + Vector2(640, 300), 0.0, Vector3(3.2, 1.0, 1.15), 0.06)
			_queue("lava_haze", o + Vector2(640, 300), 0.0, Vector3(2.7, 1.0, 0.9), 0.2)
	if world == "whispering_mire" or world == "crystal_deep":
		for id in _dungeon.room_ids():
			var o: Vector2 = _dungeon.origin_of(id)
			_queue("water", o + Vector2(260, 280), 0.2, Vector3(1.7, 1.0, 1.3), 0.03)
			_queue("water", o + Vector2(360, 400), 0.0, Vector3(1.15, 1.0, 0.95), 0.03)
			_queue("water", o + Vector2(640, 360), 0.3, Vector3(1.6, 1.0, 1.25), 0.03)
	if not _meshes.has("lava_plane"):
		return
	var lavas: Array = _dungeon.lava_rects_world() if _dungeon.has_method("lava_rects_world") else []
	for r in lavas:
		var rect: Rect2 = r
		var sx := maxf(rect.size.x * PX_TO_M / TILE_M, 0.55)
		var sz := maxf(rect.size.y * PX_TO_M / TILE_M, 0.55)
		_queue("lava_plane", rect.get_center(), 0.0, Vector3(sx, 1.0, sz), 0.04)
		_queue("lava_haze", rect.get_center(), 0.0, Vector3(sx * 0.85, 1.0, sz * 0.85), 0.16)


func _place_torches() -> void:
	var torches: Array = _dungeon.torch_positions() if _dungeon.has_method("torch_positions") else []
	var by_room: Dictionary = {}
	for pos in torches:
		var piece := "torch" if _meshes.has("torch") else "brazier"
		_queue(piece, pos, 0.0, Vector3.ONE * 1.6, 0.0)
		var rid := _room_of(pos)
		if not by_room.has(rid):
			by_room[rid] = []
		if (by_room[rid] as Array).size() < 4:
			(by_room[rid] as Array).append(pos)
	for id in _dungeon.room_ids():
		var pts: Array = by_room.get(String(id), [])
		var o: Vector2 = _dungeon.origin_of(id)
		var corners: Array[Vector2] = [
			o + Vector2(180, 150), o + Vector2(960, 160),
			o + Vector2(200, 500), o + Vector2(940, 480),
		]
		var k := 0
		while pts.size() < 4 and k < corners.size():
			pts.append(corners[k])
			k += 1
		_room_lights[String(id)] = pts
	# Four reused lights. Only the player's room is lit (hard cap 4 + 1 sun).
	for i in 4:
		var light := SpotLight3D.new()
		light.light_color = _preset["torch_color"]
		light.light_energy = float(_preset["torch_energy"]) * 2.2
		light.spot_range = float(_preset["torch_range"]) * 1.4
		light.spot_angle = 36.0
		light.shadow_enabled = false
		light.visible = false
		_pivot.add_child(light)
		_lights.append(light)


func _setup_camera() -> void:
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_cam.current = true
	_root3.add_child(_cam)
	_update_camera(true)


func _setup_weather() -> void:
	_weather = GPUParticles3D.new()
	var world := String(_preset.get("id", ""))
	_weather.amount = 80 if world == "emberfall" else 70
	_weather.lifetime = 3.4
	var mat := ParticleProcessMaterial.new()
	mat.spread = 30.0
	mat.initial_velocity_min = 0.2
	mat.initial_velocity_max = 0.9
	if world == "emberfall":
		mat.direction = Vector3(0.05, 1.0, 0.0)
		mat.gravity = Vector3(0, 0.45, 0)
		mat.scale_min = 0.05
		mat.scale_max = 0.12
		mat.color = Color(1.0, 0.42, 0.08, 0.9)
	elif world == "whispering_mire":
		mat.direction = Vector3(0.3, 0.35, 0.1)
		mat.gravity = Vector3(0, 0.04, 0)
		mat.scale_min = 0.06
		mat.scale_max = 0.16
		mat.color = Color(0.9, 1.0, 0.35, 0.92)
	else:
		mat.direction = Vector3(0.1, -0.15, 0.05)
		mat.gravity = Vector3(0, -0.04, 0)
		mat.scale_min = 0.04
		mat.scale_max = 0.1
		mat.color = Color(0.75, 0.65, 1.0, 0.75)
	_weather.process_material = mat
	var draw := SphereMesh.new()
	draw.radius = 0.05
	draw.height = 0.1
	_weather.draw_pass_1 = draw
	_pivot.add_child(_weather)


func _update_camera(force: bool = false) -> void:
	if _cam == null or _player == null or not is_instance_valid(_player):
		return
	var target := _to3(_player.global_position, 0.85)
	var desired := target + Vector3(0.0, 11.0, 13.5)
	if force:
		_cam.global_position = desired
	else:
		_cam.global_position = _cam.global_position.lerp(desired, 0.14)
	_cam.look_at(target, Vector3.UP)
	if _weather:
		_weather.global_position = target + Vector3(0, 2.2, 0)
	if _hero_light:
		_hero_light.global_position = target + Vector3(0.4, 1.5, 0.2)
	# Match SubViewport to window
	if _svp and get_viewport():
		var sz: Vector2i = get_viewport().get_visible_rect().size
		if sz.x > 0 and sz.y > 0:
			_svp.size = sz


func grade_tint() -> Color:
	return _preset.get("fog_color", Color(0, 0, 0))


func _focus_room_lights() -> void:
	if _player == null or not _dungeon.has_method("room_at"):
		return
	var rid: String = String(_dungeon.room_at(_player.global_position))
	if rid == _focus_room:
		return
	_focus_room = rid
	var pts: Array = _room_lights.get(rid, [])
	for i in _lights.size():
		var L: SpotLight3D = _lights[i]
		if i < pts.size():
			L.visible = true
			L.position = _to3(pts[i], 2.6)
			L.rotation_degrees = Vector3(-58.0, float(i) * 80.0, 0.0)
		else:
			L.visible = false


func _process(delta: float) -> void:
	if not _active:
		return
	_update_camera(false)
	_focus_room_lights()
	_flicker_t += delta
	var base_e: float = float(_preset["torch_energy"]) * float(_preset.get("lighting_boost", 1.0))
	for i in _lights.size():
		var L: SpotLight3D = _lights[i]
		if is_instance_valid(L) and L.visible:
			L.light_energy = base_e * (0.82 + 0.18 * sin(_flicker_t * 6.0 + float(i)))


func debug_stats() -> String:
	var worst_tris := 0
	var worst_draws := 0
	var worst_id := ""
	for id in _room_tris.keys():
		if int(_room_tris[id]) > worst_tris:
			worst_tris = int(_room_tris[id])
			worst_draws = int(_room_draws.get(id, 0))
			worst_id = String(id)
	var min_props := 9999
	for id in _room_props.keys():
		min_props = mini(min_props, int(_room_props[id]))
	if min_props == 9999:
		min_props = 0
	return "worst_room=%s tris=%d draws=%d rooms=%d min_props=%d" % [worst_id, worst_tris, worst_draws, _room_tris.size(), min_props]


func grab_frame() -> Image:
	if _svp == null or _svp.get_texture() == null:
		return null
	return _svp.get_texture().get_image()
