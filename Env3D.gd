extends CanvasLayer
## Env3D.gd — 3D Emberfall backdrop in a SubViewport under the 2D game.
## 2D physics/Camera2D unchanged. Maps 2D (x,y) → 3D (x,0,y).

const Levels3DScript := preload("res://Levels3D.gd")

const PX_TO_M := 2.0 / 64.0
const TILE_M := 2.0
const ROOM_W := 1152.0
const ROOM_H := 648.0
const TILE_PX := 64.0
const WALL_PX := 36.0

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
var _lava_light: OmniLight3D
var _lava_glow_at: Dictionary = {}
var _room_tris: Dictionary = {}
var _room_draws: Dictionary = {}
var _room_origin: Dictionary = {}
var _tri_cache: Dictionary = {}
var _floor_mat: ShaderMaterial
var _wall_mat: ShaderMaterial
var _water_mat: ShaderMaterial
var _lava_mat: ShaderMaterial
var _fog_mat: ShaderMaterial
var _shaft_mat: ShaderMaterial
var _crack_mat: ShaderMaterial
var _shroom_mat: StandardMaterial3D
var _prop_mats: Dictionary = {}
var _room_props: Dictionary = {}
const LavaShader := preload("res://shaders/lava_crust.gdshader")
const SurfaceShader := preload("res://shaders/env_surface.gdshader")
const WaterShader := preload("res://shaders/water_gloss.gdshader")
const HazeShader := preload("res://shaders/heat_haze.gdshader")
const FogShader := preload("res://shaders/fog_sheet.gdshader")
const ShaftShader := preload("res://shaders/light_shaft.gdshader")
const CrackShader := preload("res://shaders/lava_cracks.gdshader")
const LAVA_COLOR := "res://assets/textures/env_cc0/polyhaven_w1_emberfall/lava/Lava001/Lava001_1K-JPG_Color.jpg"
const LAVA_EMIT := "res://assets/textures/env_cc0/polyhaven_w1_emberfall/lava/Lava001/Lava001_1K-JPG_Emission.jpg"
const LAVA_NORMAL := "res://assets/textures/env_cc0/polyhaven_w1_emberfall/lava/Lava001/Lava001_1K-JPG_NormalGL.jpg"
const LAVA_ROUGH := "res://assets/textures/env_cc0/polyhaven_w1_emberfall/lava/Lava001/Lava001_1K-JPG_Roughness.jpg"
const _KEEP_MAT := {
	"lava_plane": true, "lava_haze": true, "water": true, "contact": true,
	"floor_a": true, "wall_straight": true,
	"glow_mushroom": true, "crystal_cluster": true, "crystal_cyan": true, "crystal_pink": true,
	"geode": true, "stalactite": true, "shards": true, "torch": true, "brazier": true, "cauldron": true,
	"lava_river": true, "lava_pool": true, "lava_bank": true, "lava_pool_bank": true, "lava_cracks": true,
	"lava_pool_haze": true, "bank_riser": true,
	"fog_sheet": true, "shaft": true,
}
const _PROP_TINT := {
	"crate": Color(0.32, 0.16, 0.08),
	"barrel": Color(0.38, 0.2, 0.1),
	"skull": Color(0.82, 0.76, 0.64),
	"bone_pile": Color(0.78, 0.72, 0.58),
	"pillar": Color(0.72, 0.68, 0.6),
	"statue": Color(0.78, 0.74, 0.66),
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
	"plants": Color(0.4, 0.62, 0.28),
	"doorway": Color(0.62, 0.5, 0.4),
	"corner_tower": Color(0.55, 0.46, 0.38),
	"arch": Color(0.58, 0.48, 0.4),
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


func _load_tex(path: String) -> Texture2D:
	if path == "" or not FileAccess.file_exists(path):
		return null
	if ResourceLoader.exists(path):
		var cached = load(path)
		if cached is Texture2D:
			return cached
	var img := Image.new()
	if img.load(path) != OK:
		return null
	return ImageTexture.create_from_image(img)


func _load_one(path: String, name: String) -> void:
	# Read the GLB from disk. A stale .import sidecar would keep the old mesh.
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var mesh: Mesh = null
	if gltf.append_from_file(path, state) == OK:
		var inst := gltf.generate_scene(state)
		if inst != null:
			mesh = _find_mesh(inst)
			if mesh != null:
				_meshes[name] = mesh
			inst.free()
	if mesh == null:
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			return
		var inst2 := packed.instantiate()
		mesh = _find_mesh(inst2)
		if mesh != null:
			_meshes[name] = mesh
		inst2.free()
	if mesh != null and (name.begins_with("crystal") or name == "geode" or name == "shards"):
		_glassify(mesh)


func _glassify(mesh: Mesh) -> void:
	if not mesh is ArrayMesh:
		return
	for i in mesh.get_surface_count():
		var src := mesh.surface_get_material(i) as StandardMaterial3D
		if src == null or not src.emission_enabled:
			continue
		var m := src.duplicate() as StandardMaterial3D
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var c := m.albedo_color
		c.a = 0.58
		m.albedo_color = c
		m.emission_energy_multiplier = minf(m.emission_energy_multiplier, 0.95)
		(mesh as ArrayMesh).surface_set_material(i, m)


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
	var hdri_path := String(_preset.get("hdri", ""))
	if hdri_path != "" and FileAccess.file_exists(hdri_path):
		var sky_mat := PanoramaSkyMaterial.new()
		sky_mat.panorama = _load_tex(hdri_path)
		var sky := Sky.new()
		sky.sky_material = sky_mat
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		# Keep the sky for reflections, but low enough that torch color still reads.
		env.ambient_light_energy = 0.4
	else:
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

	# A second hue against the world grade: cool fill in the furnace, warm fill in the cool worlds.
	var rim := DirectionalLight3D.new()
	var world_id := String(_preset.get("id", ""))
	if world_id == "emberfall":
		rim.light_color = Color(0.55, 0.48, 0.62)
	else:
		rim.light_color = Color(1.0, 0.7, 0.38)
	rim.light_energy = 0.4
	rim.shadow_enabled = false
	rim.rotation_degrees = Vector3(-28.0, -150.0, 0.0)
	_root3.add_child(rim)

	_lava_light = OmniLight3D.new()
	_lava_light.light_color = Color(1.0, 0.32, 0.06)
	_lava_light.light_energy = 1.15
	_lava_light.omni_range = 8.0
	_lava_light.shadow_enabled = false
	_lava_light.visible = false
	_root3.add_child(_lava_light)

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
	if piece == "lava_plane" or piece == "lava_river" or piece == "lava_pool":
		mi.material_override = _lava_mat
	elif piece == "lava_bank" or piece == "lava_pool_bank" or piece == "bank_riser":
		mi.material_override = _wall_mat
	elif piece == "lava_cracks":
		mi.material_override = _crack_mat
	elif piece == "fog_sheet":
		mi.material_override = _fog_mat
	elif piece == "shaft":
		mi.material_override = _shaft_mat
	elif piece == "glow_mushroom":
		mi.material_override = _shroom_mat
	elif piece == "lava_haze" or piece == "lava_pool_haze":
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
		mat.set_shader_parameter("vein_color", Vector3(0.32, 0.48, 0.62))
	return mat


func _prop_material(piece: String) -> ShaderMaterial:
	if _prop_mats.has(piece):
		return _prop_mats[piece]
	var mat := _make_surface("floor", 0.55, 0.05, 0.25, 1.0, 0.0, 0.0)
	var key := piece
	if piece.ends_with("_hot"):
		key = piece.trim_suffix("_hot")
	var tint: Color = _PROP_TINT.get(key, Color(0.72, 0.62, 0.5))
	if piece.ends_with("_hot"):
		tint = tint.lerp(Color(1.0, 0.45, 0.16), 0.5)
	mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	_prop_mats[piece] = mat
	return mat


func _flush() -> void:
	if _floor_mat == null and _preset.has("floor_albedo"):
		var wet := float(_preset.get("wet_strength", 0.15))
		var world_id := String(_preset.get("id", ""))
		var veins := 0.55 if world_id == "crystal_deep" else 0.0
		var floor_value := 1.5 if world_id == "whispering_mire" else 1.2
		_floor_mat = _make_surface("floor", 0.16, wet, 0.4, floor_value, 0.0, 0.0)
		_wall_mat = _make_surface("wall", 0.2, wet * 0.25, 0.55, 0.5, 1.0, veins)
		_water_mat = ShaderMaterial.new()
		_water_mat.shader = WaterShader
		var hdri_path := String(_preset.get("hdri", ""))
		if hdri_path != "":
			_water_mat.set_shader_parameter("panorama", _load_tex(hdri_path))
		_water_mat.set_shader_parameter("normal_tex", load(String(_preset.get("floor_normal", ""))))
		_lava_mat = ShaderMaterial.new()
		_lava_mat.shader = LavaShader
		_lava_mat.set_shader_parameter("albedo", _load_tex(LAVA_COLOR))
		_lava_mat.set_shader_parameter("emission_tex", _load_tex(LAVA_EMIT))
		_lava_mat.set_shader_parameter("normal_tex", _load_tex(LAVA_NORMAL))
		_lava_mat.set_shader_parameter("rough_tex", _load_tex(LAVA_ROUGH))
		_crack_mat = ShaderMaterial.new()
		_crack_mat.shader = CrackShader
		_crack_mat.set_shader_parameter("emission_tex", _load_tex(LAVA_EMIT))
		_fog_mat = ShaderMaterial.new()
		_fog_mat.shader = FogShader
		var fog_c: Color = _preset.get("fog_color", Color(0.4, 0.4, 0.4))
		_fog_mat.set_shader_parameter("fog_tint", Vector3(fog_c.r, fog_c.g, fog_c.b))
		_fog_mat.set_shader_parameter("alpha_scale", 0.05)
		_shaft_mat = ShaderMaterial.new()
		_shaft_mat.shader = ShaftShader
		var torch: Color = _preset.get("torch_color", Color(1, 0.6, 0.3))
		_shaft_mat.set_shader_parameter("shaft_color", Vector3(torch.r, torch.g, torch.b))
		_shroom_mat = StandardMaterial3D.new()
		_shroom_mat.albedo_color = Color(0.16, 0.48, 0.32)
		_shroom_mat.emission_enabled = true
		_shroom_mat.emission = Color(0.2, 0.85, 0.42)
		_shroom_mat.emission_energy_multiplier = 0.65
		_shroom_mat.roughness = 0.42
		if world_id == "crystal_deep":
			_water_mat.set_shader_parameter("deep", Vector3(0.12, 0.16, 0.28))
			_water_mat.set_shader_parameter("glaze", Vector3(0.62, 0.74, 0.95))
			_water_mat.set_shader_parameter("reflect_strength", 0.38)
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
	# Channel is one tile wide (2 m) and four tiles long. Pool is a 2×2 tile cut.
	_meshes["lava_river"] = _rounded_mesh(3.65, 0.68, 0.68, -0.32)
	_meshes["lava_pool"] = _rounded_mesh(1.66, 1.66, 0.55, -0.32)
	_meshes["water"] = _meshes["lava_pool"]
	_meshes["bank_riser"] = _riser_mesh()
	var fog := PlaneMesh.new()
	fog.size = Vector2(14.0, 10.0)
	_meshes["fog_sheet"] = fog
	_meshes["shaft"] = _shaft_mesh()
	if _meshes.has("crate"):
		_meshes["crate_hot"] = _meshes["crate"]
	if _meshes.has("barrel"):
		_meshes["barrel_hot"] = _meshes["barrel"]
	var cuts := _cut_cells()
	for id in _dungeon.room_ids():
		var o: Vector2 = _dungeon.origin_of(id)
		var cols := int(ceil(ROOM_W / TILE_PX))
		var rows := int(ceil(ROOM_H / TILE_PX))
		for cy in rows:
			for cx in cols:
				var px := o + Vector2((float(cx) + 0.5) * TILE_PX, (float(cy) + 0.5) * TILE_PX)
				var drop := -0.55 if cuts.has(_cell_key(cx, cy)) else 0.0
				_queue("floor_a", px, 0.0, Vector3.ONE, drop)
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
	_place_floor_cuts()
	_place_torches()
	_place_outdoor()
	_place_boss_arena()
	_flush()


func _place_props() -> void:
	var world := String(_preset.get("id", ""))
	for id in _dungeon.room_ids():
		var rid := String(id)
		var o: Vector2 = _dungeon.origin_of(rid)
		_place_frames(rid)
		_place_fog_and_shafts(o)
		if world == "emberfall":
			_place_ember_walls(o)
		elif world == "whispering_mire":
			_place_mire_walls(o)
		else:
			_place_crystal_walls(o)


func _place_frames(id: String) -> void:
	var openings := _openings(id)
	var frame_scale := Vector3(1.15, 1.28, 1.05)
	for i in openings.size():
		var op: Dictionary = openings[i]
		var piece := "doorway" if i % 2 == 0 else "arch"
		if not _meshes.has(piece):
			piece = "doorway" if _meshes.has("doorway") else "arch"
		_queue(piece, op["pos"], float(op["yaw"]), frame_scale, 0.0)
	var o: Vector2 = _dungeon.origin_of(id)
	var corners: Array[Vector2] = [
		o + Vector2(WALL_PX * 0.5, WALL_PX * 0.5),
		o + Vector2(ROOM_W - WALL_PX * 0.5, WALL_PX * 0.5),
		o + Vector2(WALL_PX * 0.5, ROOM_H - WALL_PX * 0.5),
		o + Vector2(ROOM_W - WALL_PX * 0.5, ROOM_H - WALL_PX * 0.5),
	]
	for c in corners:
		_queue("corner_tower", c, 0.15, Vector3.ONE * 0.8, 0.0)


func _openings(id: String) -> Array:
	var out: Array = []
	if not _dungeon.has_method("doors"):
		return out
	var o: Vector2 = _dungeon.origin_of(id)
	for d in _dungeon.doors():
		var other := ""
		if String(d["a"]) == id:
			other = String(d["b"])
		elif String(d["b"]) == id:
			other = String(d["a"])
		else:
			continue
		# One frame per shared opening. The other room skips it.
		if id > other:
			continue
		var oo: Vector2 = _dungeon.origin_of(other)
		var delta := oo - o
		if absf(delta.x) > absf(delta.y):
			var edge_x := o.x + ROOM_W - WALL_PX * 0.5 if delta.x > 0.0 else o.x + WALL_PX * 0.5
			out.append({"pos": Vector2(edge_x, o.y + ROOM_H * 0.5), "yaw": PI * 0.5})
		else:
			var edge_y := o.y + ROOM_H - WALL_PX * 0.5 if delta.y > 0.0 else o.y + WALL_PX * 0.5
			out.append({"pos": Vector2(o.x + ROOM_W * 0.5, edge_y), "yaw": 0.0})
	return out


func _place_ember_walls(o: Vector2) -> void:
	# North bank of the lava. y=150 sits inside the room, clear of the thick wall mesh.
	_queue("crate", o + Vector2(270, 140), 0.35, Vector3.ONE * 1.35, 0.0)
	_queue("barrel", o + Vector2(345, 136), 0.9, Vector3.ONE * 1.25, 0.0)
	_queue("rubble", o + Vector2(308, 152), 0.2, Vector3.ONE * 1.15, 0.0)
	_queue("statue", o + Vector2(425, 142), 0.45, Vector3.ONE * 1.15, 0.0)
	_queue("pillar", o + Vector2(845, 160), 0.15, Vector3.ONE * 0.95, 0.0)
	_queue("banner", o + Vector2(790, 150), 0.05, Vector3.ONE, 0.0)
	# Beside the south-east pool, off the coin at (1000, 520).
	_queue("crate_hot", o + Vector2(700, 500), 0.55, Vector3.ONE * 1.05, 0.0)
	_queue("barrel_hot", o + Vector2(735, 430), 1.1, Vector3.ONE * 1.0, 0.0)


func _place_mire_walls(o: Vector2) -> void:
	# Long fallen log on the north wall, between the pool and the door.
	# Log mesh is long on local Z. Yaw turns that along the north wall.
	_queue("log", o + Vector2(430, 210), PI * 0.5, Vector3(1.0, 0.9, 1.15), 0.0)
	_queue("glow_mushroom", o + Vector2(165, 215), 0.35, Vector3.ONE * 1.1, 0.0)
	_queue("glow_mushroom", o + Vector2(760, 175), 0.25, Vector3.ONE * 1.1, 0.0)
	_queue("glow_mushroom", o + Vector2(830, 200), 0.9, Vector3.ONE * 0.95, 0.0)
	_queue("roots", o + Vector2(880, 165), 0.55, Vector3.ONE * 1.05, 0.0)
	_queue("swamp_tree", o + Vector2(1090, 185), 1.05, Vector3.ONE * 0.72, 0.0)
	_queue("grave", o + Vector2(900, 175), 0.2, Vector3.ONE * 0.9, 0.0)
	_queue("hanging_moss", o + Vector2(360, 155), 0.1, Vector3.ONE * 1.15, 2.65)


func _place_crystal_walls(o: Vector2) -> void:
	_queue("crystal_cluster", o + Vector2(450, 158), 0.4, Vector3.ONE * 1.45, 0.0)
	_queue("cave_rock", o + Vector2(400, 175), 0.25, Vector3.ONE * 1.15, 0.0)
	_queue("stalactite", o + Vector2(500, 185), 0.5, Vector3(1.15, -1.15, 1.15), 0.0)
	_queue("crystal_cyan", o + Vector2(780, 160), 0.75, Vector3.ONE * 1.35, 0.0)
	_queue("pillar", o + Vector2(860, 160), 0.2, Vector3.ONE * 0.85, 0.0)
	_queue("crystal_pink", o + Vector2(320, 530), 0.35, Vector3.ONE * 1.25, 0.0)
	_queue("statue", o + Vector2(390, 480), 0.6, Vector3.ONE * 0.9, 0.0)


func _place_fog_and_shafts(o: Vector2) -> void:
	_queue("fog_sheet", o + Vector2(ROOM_W * 0.5, ROOM_H * 0.55), 0.0, Vector3.ONE, 0.22)


func _place_outdoor() -> void:
	# Trees and crystals sit in the player cluster. A fringe around the whole
	# dungeon landed outside the first frame and blew the triangle budget.
	return


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


func _cell_key(cx: int, cy: int) -> String:
	return "%d:%d" % [cx, cy]


func _cut_cells() -> Dictionary:
	# Room-local tile indices. The east-west walk is row 5 (y ~324) and the
	# north-south walk is columns 8-9 (x ~576). Cuts stay off both.
	var cells := {}
	var world := String(_preset.get("id", ""))
	if world == "emberfall":
		for cx in [2, 3, 4, 5]:
			cells[_cell_key(int(cx), 3)] = true
		for cx in [12, 13]:
			for cy in [7, 8]:
				cells[_cell_key(int(cx), int(cy))] = true
	else:
		# North corners, one tile in from the thick wall, above the east-west walk.
		for cx in [3, 4]:
			for cy in [2, 3]:
				cells[_cell_key(int(cx), int(cy))] = true
		for cx in [13, 14]:
			for cy in [2, 3]:
				cells[_cell_key(int(cx), int(cy))] = true
	return cells


func _span_center(o: Vector2, cx0: int, cx1: int, cy0: int, cy1: int) -> Vector2:
	var x := ((float(cx0) + float(cx1)) * 0.5 + 0.5) * TILE_PX
	var y := ((float(cy0) + float(cy1)) * 0.5 + 0.5) * TILE_PX
	return o + Vector2(x, y)


func _place_floor_cuts() -> void:
	var world := String(_preset.get("id", ""))
	var cells := _cut_cells()
	for id in _dungeon.room_ids():
		var o: Vector2 = _dungeon.origin_of(id)
		if world == "emberfall":
			_queue("lava_river", _span_center(o, 2, 5, 3, 3), 0.0, Vector3.ONE, 0.0)
			_queue("lava_pool", _span_center(o, 12, 13, 7, 8), 0.0, Vector3.ONE, 0.0)
			_lava_glow_at[String(id)] = _span_center(o, 2, 5, 3, 3)
		else:
			_queue("water", _span_center(o, 3, 4, 2, 3), 0.0, Vector3.ONE, 0.16)
			_queue("water", _span_center(o, 13, 14, 2, 3), 0.0, Vector3.ONE, 0.16)
		_place_risers(o, cells)


func _place_risers(o: Vector2, cells: Dictionary) -> void:
	for key in cells.keys():
		var parts := String(key).split(":")
		var cx := int(parts[0])
		var cy := int(parts[1])
		var center := o + Vector2((float(cx) + 0.5) * TILE_PX, (float(cy) + 0.5) * TILE_PX)
		if not cells.has(_cell_key(cx, cy - 1)):
			_queue("bank_riser", center + Vector2(0, -32), PI, Vector3.ONE, 0.0)
		if not cells.has(_cell_key(cx, cy + 1)):
			_queue("bank_riser", center + Vector2(0, 32), 0.0, Vector3.ONE, 0.0)
		if not cells.has(_cell_key(cx + 1, cy)):
			_queue("bank_riser", center + Vector2(32, 0), PI * 0.5, Vector3.ONE, 0.0)
		if not cells.has(_cell_key(cx - 1, cy)):
			_queue("bank_riser", center + Vector2(-32, 0), -PI * 0.5, Vector3.ONE, 0.0)


func _rim_uv(p: Vector2, hx: float, hz: float) -> Vector2:
	return Vector2(p.x / (hx * 2.0) + 0.5, p.y / (hz * 2.0) + 0.5)


func _rounded_mesh(hx: float, hz: float, radius: float, y: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := minf(radius, minf(hx, hz) * 0.98)
	var ix := hx - r
	var iz := hz - r
	var pts := PackedVector2Array()
	var segs := 4
	var corners: Array[Vector2] = [Vector2(ix, -iz), Vector2(ix, iz), Vector2(-ix, iz), Vector2(-ix, -iz)]
	var a0: Array[float] = [-PI * 0.5, 0.0, PI * 0.5, PI]
	for k in 4:
		for s in segs + 1:
			var ang := a0[k] + (PI * 0.5) * float(s) / float(segs)
			pts.append(corners[k] + Vector2(cos(ang), sin(ang)) * r)
	pts.append(pts[0])
	var c := Vector3(0.0, y, 0.0)
	for i in pts.size() - 1:
		var p0 := pts[i]
		var p1 := pts[i + 1]
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(c)
		st.set_uv(_rim_uv(p1, hx, hz))
		st.add_vertex(Vector3(p1.x, y, p1.y))
		st.set_uv(_rim_uv(p0, hx, hz))
		st.add_vertex(Vector3(p0.x, y, p0.y))
	st.generate_normals()
	return st.commit()


func _riser_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(-1.0, -0.55, 0.0)
	var b := Vector3(1.0, -0.55, 0.0)
	var cv := Vector3(1.0, 0.04, 0.42)
	var d := Vector3(-1.0, 0.04, 0.42)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(a)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(d)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(cv)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(a)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(cv)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(b)
	st.generate_normals()
	return st.commit()


func _sheet(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.set_uv(Vector2(0, 0))
	st.add_vertex(a)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(d)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(c)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(a)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(c)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(b)


func _shaft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_sheet(st, Vector3(-0.9, 0.35, 0.0), Vector3(0.9, 0.35, 0.0), Vector3(0.9, 3.15, 0.0), Vector3(-0.9, 3.15, 0.0))
	_sheet(st, Vector3(0.0, 0.35, -0.9), Vector3(0.0, 0.35, 0.9), Vector3(0.0, 3.15, 0.9), Vector3(0.0, 3.15, -0.9))
	st.generate_normals()
	return st.commit()


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
	_cam.fov = 43.0
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
	# Far enough that the player, enemies and pickups read, close enough to see the walls.
	var desired := target + Vector3(0.4, 9.6, 10.8)
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
	if _lava_light != null:
		var glow: Vector2 = _lava_glow_at.get(rid, Vector2.ZERO)
		var show_lava := glow != Vector2.ZERO and String(_preset.get("id", "")) == "emberfall"
		_lava_light.visible = show_lava
		if show_lava:
			_lava_light.global_position = _to3(glow, 0.65)


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
