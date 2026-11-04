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
var _lights: Array[OmniLight3D] = []
var _weather: GPUParticles3D
var _active: bool = false
var _meshes: Dictionary = {}
var _flicker_t: float = 0.0


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


func _load_kit(kit_dir: String) -> bool:
	_meshes.clear()
	var needed := ["floor_a", "wall_straight", "pillar", "rubble", "brazier", "lava_plane"]
	for n in needed:
		var path := kit_dir + n + ".glb"
		if not ResourceLoader.exists(path):
			continue
		var packed: PackedScene = load(path)
		if packed == null:
			continue
		var inst := packed.instantiate()
		var mesh := _find_mesh(inst)
		if mesh:
			_meshes[n] = mesh
		inst.free()
	for n in ["floor_b", "floor_c", "bone_pile", "cracked_statue", "ash_heap", "ember_rock", "gate"]:
		var path2 := kit_dir + n + ".glb"
		if not ResourceLoader.exists(path2):
			continue
		var packed2: PackedScene = load(path2)
		if packed2 == null:
			continue
		var inst2 := packed2.instantiate()
		var mesh2 := _find_mesh(inst2)
		if mesh2:
			_meshes[n] = mesh2
		inst2.free()
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
	env.background_color = Color(0.04, 0.015, 0.01)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _preset["ambient"]
	env.ambient_light_energy = float(_preset["ambient_energy"]) * float(_preset.get("lighting_boost", 1.0))
	env.fog_enabled = true
	env.fog_light_color = _preset["fog_color"]
	env.fog_density = float(_preset["fog_density"])
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.2
	var we := WorldEnvironment.new()
	we.environment = env
	_root3.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = _preset["sun_color"]
	sun.light_energy = float(_preset["sun_energy"])
	sun.shadow_enabled = false
	sun.rotation_degrees = Vector3(float(_preset["sun_pitch_deg"]), 35.0, 0.0)
	_root3.add_child(sun)

	_pivot = Node3D.new()
	_root3.add_child(_pivot)
	_prop_root = Node3D.new()
	_pivot.add_child(_prop_root)


func _make_mm(mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = maxi(count, 1)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.visibility_range_end = 60.0
	mi.visibility_range_end_margin = 10.0
	return mi


func _build_from_dungeon() -> void:
	var floor_xforms: Array[Transform3D] = []
	var wall_xforms: Array[Transform3D] = []
	for id in _dungeon.room_ids():
		var o: Vector2 = _dungeon.origin_of(id)
		var cols := int(ceil(1152.0 / 64.0))
		var rows := int(ceil(648.0 / 64.0))
		for cy in rows:
			for cx in cols:
				var px := o + Vector2((cx + 0.5) * 64.0, (cy + 0.5) * 64.0)
				floor_xforms.append(Transform3D(Basis.IDENTITY, _to3(px, 0.0)))

	var walls: Array = _dungeon.wall_rects_world() if _dungeon.has_method("wall_rects_world") else []
	for r in walls:
		var rect: Rect2 = r
		if rect.size.x >= rect.size.y:
			var n: int = maxi(1, int(ceil(rect.size.x / 64.0)))
			for i in n:
				var px := Vector2(rect.position.x + (i + 0.5) * (rect.size.x / float(n)), rect.position.y + rect.size.y * 0.5)
				wall_xforms.append(Transform3D(Basis.IDENTITY, _to3(px, 0.0)))
		else:
			var n2: int = maxi(1, int(ceil(rect.size.y / 64.0)))
			for i in n2:
				var px2 := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + (i + 0.5) * (rect.size.y / float(n2)))
				wall_xforms.append(Transform3D(Basis.from_euler(Vector3(0, deg_to_rad(90.0), 0)), _to3(px2, 0.0)))

	var floor_mm := _make_mm(_meshes["floor_a"], floor_xforms.size())
	_pivot.add_child(floor_mm)
	for i in floor_xforms.size():
		floor_mm.multimesh.set_instance_transform(i, floor_xforms[i])

	var wall_mm := _make_mm(_meshes["wall_straight"], wall_xforms.size())
	_pivot.add_child(wall_mm)
	for i in wall_xforms.size():
		wall_mm.multimesh.set_instance_transform(i, wall_xforms[i])

	_place_props()
	_place_lava()
	_place_torches()


func _spawn_prop(piece: String, pos: Vector2, yaw: float = 0.0, scl: float = 1.0) -> void:
	if not _meshes.has(piece):
		return
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[piece]
	mi.position = _to3(pos, 0.0)
	mi.rotation.y = yaw
	mi.scale = Vector3.ONE * scl
	mi.visibility_range_end = 42.0
	_prop_root.add_child(mi)


func _place_props() -> void:
	var dens: float = float(_preset.get("prop_density", 1.0))
	var obstacles: Array = _dungeon.obstacles_world() if _dungeon.has_method("obstacles_world") else []
	for ob in obstacles:
		var r: Rect2 = ob["r"]
		var kind: String = String(ob.get("k", "crate"))
		var piece := "pillar" if kind.find("pillar") >= 0 else "rubble"
		if piece == "rubble" and _meshes.has("ember_rock") and randf() < 0.25:
			piece = "ember_rock"
		if randf() > dens:
			continue
		_spawn_prop(piece, r.get_center(), randf() * TAU, clampf(r.size.x / 64.0, 0.7, 1.4))
	for id in _dungeon.room_ids():
		var c: Vector2 = _dungeon.room_center(id)
		if randf() < 0.5 * dens:
			_spawn_prop("bone_pile", c + Vector2(randf_range(-180, 180), randf_range(-100, 100)), randf() * TAU)
		if randf() < 0.3 * dens:
			_spawn_prop("cracked_statue", c + Vector2(randf_range(-200, 200), randf_range(-120, 120)), randf() * TAU, 1.1)
		if randf() < 0.4 * dens:
			_spawn_prop("ash_heap", c + Vector2(randf_range(-220, 220), randf_range(-140, 140)), 0.0, randf_range(0.8, 1.3))


func _place_lava() -> void:
	if not _meshes.has("lava_plane"):
		return
	var lavas: Array = _dungeon.lava_rects_world() if _dungeon.has_method("lava_rects_world") else []
	for r in lavas:
		var rect: Rect2 = r
		var mi := MeshInstance3D.new()
		mi.mesh = _meshes["lava_plane"]
		mi.position = _to3(rect.get_center(), 0.05)
		mi.scale = Vector3(maxf(rect.size.x * PX_TO_M / TILE_M, 0.5), 1.0, maxf(rect.size.y * PX_TO_M / TILE_M, 0.5))
		_prop_root.add_child(mi)


func _place_torches() -> void:
	var torches: Array = _dungeon.torch_positions() if _dungeon.has_method("torch_positions") else []
	var n := 0
	var cap: int = int(_preset.get("max_torches", 8))
	for pos in torches:
		if n >= cap:
			break
		_spawn_prop("brazier", pos, 0.0, 0.85)
		var light := OmniLight3D.new()
		light.light_color = _preset["torch_color"]
		light.light_energy = float(_preset["torch_energy"]) * float(_preset.get("lighting_boost", 1.0))
		light.omni_range = float(_preset["torch_range"])
		light.shadow_enabled = false
		light.position = _to3(pos, 1.6)
		_pivot.add_child(light)
		_lights.append(light)
		n += 1


func _setup_camera() -> void:
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_cam.current = true
	_root3.add_child(_cam)
	_update_camera(true)


func _setup_weather() -> void:
	_weather = GPUParticles3D.new()
	_weather.amount = 40
	_weather.lifetime = 3.2
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.2, 1.0, 0.1)
	mat.spread = 22.0
	mat.initial_velocity_min = 0.3
	mat.initial_velocity_max = 1.2
	mat.gravity = Vector3(0, 0.12, 0)
	mat.scale_min = 0.04
	mat.scale_max = 0.1
	mat.color = Color(1.0, 0.4, 0.08, 0.8)
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
	# Match SubViewport to window
	if _svp and get_viewport():
		var sz: Vector2i = get_viewport().get_visible_rect().size
		if sz.x > 0 and sz.y > 0:
			_svp.size = sz


func _process(delta: float) -> void:
	if not _active:
		return
	_update_camera(false)
	_flicker_t += delta
	var base_e: float = float(_preset["torch_energy"]) * float(_preset.get("lighting_boost", 1.0))
	for i in _lights.size():
		var L: OmniLight3D = _lights[i]
		if is_instance_valid(L):
			L.light_energy = base_e * (0.85 + 0.2 * sin(_flicker_t * 7.0 + float(i) * 1.7))
