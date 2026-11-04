extends Node2D
## EnemyLook.gd — 3D-in-2D enemy visuals via SubViewport; falls back to CreatureArt / EnemyArt.
## Same Guard interface: setup(tier), aim_angle, pulse, blood_color(), eye_color().

const CreatureScript := preload("res://CreatureArt.gd")
const EnemyArtScript := preload("res://EnemyArt.gd")

var species: String = "ghoul"
var tier: int = 0
var aim_angle: float = 0.0
var pulse: float = 0.0
var move_amount: float = 0.0
var attacking: bool = false
var dying: bool = false
var is_boss: bool = false

var _fallback: Node2D
var _use_3d: bool = false
var _svpc: SubViewportContainer
var _svp: SubViewport
var _world: Node3D
var _pivot: Node3D
var _model_root: Node3D
var _anim: AnimationPlayer
var _cam: Camera3D
var _current_anim: String = ""
var _hit_timer: float = 0.0
var _angle: float = 0.0
var _far_lod: bool = false


func setup(new_tier: int) -> void:
	tier = new_tier % 4
	_ensure_fallback()
	_fallback.setup(tier)
	if is_boss:
		modulate = Color(1.35, 0.55, 0.55)
	call_deferred("_try_enable_3d")


func blood_color() -> Color:
	if _fallback and _fallback.has_method("blood_color"):
		return _fallback.blood_color()
	return Color(0.7, 0.12, 0.12)


func eye_color() -> Color:
	if _fallback and _fallback.has_method("eye_color"):
		return _fallback.eye_color()
	return Color(2.0, 0.4, 0.3)


func release_3d_slot() -> void:
	_teardown_3d()
	_use_3d = false
	if _fallback:
		_fallback.visible = true
		_fallback.set_process(true)
	queue_redraw()


func _ensure_fallback() -> void:
	if _fallback and is_instance_valid(_fallback):
		return
	_fallback = Node2D.new()
	_fallback.name = "Fallback2D"
	if species == "ghoul":
		_fallback.set_script(EnemyArtScript)
	else:
		_fallback.set_script(CreatureScript)
		_fallback.set("species", species)
	add_child(_fallback)


func _try_enable_3d() -> void:
	if not is_inside_tree():
		call_deferred("_try_enable_3d")
		return
	if not EnemyModels.has_model(species):
		_use_3d = false
		return
	if not EnemyModels.request_slot(self):
		_use_3d = false
		return
	_setup_viewport()
	_load_model()
	_use_3d = _model_root != null
	if _svpc:
		_svpc.visible = _use_3d
	if _fallback:
		_fallback.visible = not _use_3d
		_fallback.set_process(not _use_3d)
	if is_boss and _model_root:
		_model_root.scale = Vector3.ONE * 1.6
		_tint_boss()
	if _use_3d:
		_play_anim("idle")


func _tint_boss() -> void:
	if _model_root == null:
		return
	_apply_tint(_model_root, Color(1.25, 0.35, 0.3))


func _apply_tint(n: Node, col: Color) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.get_surface_override_material_count():
			var mat := mi.get_active_material(i)
			if mat is StandardMaterial3D:
				var m: StandardMaterial3D = (mat as StandardMaterial3D).duplicate()
				m.albedo_color = m.albedo_color * col
				mi.set_surface_override_material(i, m)
	for c in n.get_children():
		_apply_tint(c, col)


func _teardown_3d() -> void:
	EnemyModels.release_slot(self)
	if _svpc and is_instance_valid(_svpc):
		_svpc.queue_free()
	_svpc = null
	_svp = null
	_world = null
	_pivot = null
	_model_root = null
	_anim = null
	_cam = null
	_current_anim = ""


func _setup_viewport() -> void:
	if _svpc and is_instance_valid(_svpc):
		return
	var sz: Vector2i = EnemyModels.VIEW_SIZE
	_svpc = SubViewportContainer.new()
	_svpc.name = "Enemy3DView"
	_svpc.stretch = true
	_svpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_svpc.position = Vector2(-sz.x * 0.5, -sz.y * 0.5)
	_svpc.size = Vector2(sz)
	add_child(_svpc)

	_svp = SubViewport.new()
	_svp.name = "SVP"
	_svp.size = sz
	_svp.transparent_bg = true
	_svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_svp.world_3d = World3D.new()
	_svpc.add_child(_svp)

	_world = Node3D.new()
	_world.name = "World"
	_svp.add_child(_world)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 40, 0)
	light.light_energy = 1.1
	_world.add_child(light)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.0, 1.4, 1.2)
	fill.light_energy = 0.45
	_world.add_child(fill)

	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	_world.add_child(_pivot)

	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	_cam.fov = 32.0
	_cam.position = Vector3(0.0, 2.4, 2.2)
	_cam.rotation_degrees = Vector3(-40.0, 0.0, 0.0)
	_cam.current = true
	_world.add_child(_cam)
	_cam.look_at(Vector3(0.0, 0.85, 0.0))


func _load_model() -> void:
	if _model_root and is_instance_valid(_model_root):
		_model_root.queue_free()
		_model_root = null
		_anim = null
	var packed: PackedScene = EnemyModels.get_packed(species)
	if packed == null:
		return
	_model_root = packed.instantiate() as Node3D
	if _model_root == null:
		return
	_pivot.add_child(_model_root)
	_model_root.position = Vector3(0, 0, 0)
	_model_root.scale = Vector3.ONE * 0.9
	_anim = _find_anim_player(_model_root)
	_current_anim = ""


func _find_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var found := _find_anim_player(c)
		if found:
			return found
	return null


func _play_anim(want: String) -> void:
	if _anim == null or not _use_3d:
		return
	var resolved := EnemyModels.resolve_anim(_anim, want)
	if resolved == "":
		return
	if resolved == _current_anim and _anim.is_playing():
		return
	_current_anim = resolved
	_anim.play(resolved)


func _pick_anim() -> String:
	if dying:
		return "death"
	if _hit_timer > 0.0:
		return "hit"
	if attacking:
		return "attack"
	if move_amount > 0.12:
		return "move"
	return "idle"


func _process(delta: float) -> void:
	pulse = maxf(pulse - delta * 6.0, 0.0)
	if pulse > 0.85:
		_hit_timer = 0.28
	_hit_timer = maxf(_hit_timer - delta, 0.0)
	_angle = lerp_angle(_angle, aim_angle, minf(1.0, delta * 14.0))

	if _fallback and is_instance_valid(_fallback) and _fallback.visible:
		_fallback.aim_angle = aim_angle
		_fallback.pulse = pulse

	if not _use_3d:
		_maybe_reclaim_slot()
		return

	# LOD / on-screen budget: pause far enemies
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and _svp:
		var dist: float = global_position.distance_to(player.global_position)
		_far_lod = dist > EnemyModels.FAR_LOD_DIST
		if dist > EnemyModels.NEAR_UPDATE_DIST:
			_svp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			release_3d_slot()
			return
		elif _far_lod:
			_svp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
			if _model_root:
				_model_root.scale = Vector3.ONE * (0.7 if not is_boss else 1.2)
		else:
			_svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			if _model_root:
				_model_root.scale = Vector3.ONE * (0.9 if not is_boss else 1.6)

	if _pivot:
		_pivot.rotation.y = -_angle + PI * 0.5
	if pulse > 0.0 and _svpc:
		var squash := 1.0 - pulse * 0.12
		_svpc.scale = Vector2(1.0 / squash, squash)
	elif _svpc:
		_svpc.scale = Vector2.ONE
	_play_anim(_pick_anim())


func _maybe_reclaim_slot() -> void:
	if EnemyModels.has_model(species) and not _use_3d:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player and global_position.distance_to(player.global_position) < EnemyModels.NEAR_UPDATE_DIST * 0.85:
			_try_enable_3d()


func _exit_tree() -> void:
	EnemyModels.release_slot(self)
