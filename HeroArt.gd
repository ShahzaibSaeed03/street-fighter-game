extends Node2D
## HeroArt.gd — prefers Mixamo GLB via SubViewport (3D-in-2D); falls back to procedural draw.

var steel := Color(0.60, 0.65, 0.74)
var steel_dark := Color(0.26, 0.29, 0.37)
var gold := Color(0.93, 0.74, 0.30)
var gold_dark := Color(0.50, 0.36, 0.12)
var cape := Color(0.66, 0.10, 0.15)
var cape_dark := Color(0.34, 0.05, 0.09)
var blade_color := Color(0.82, 0.87, 0.95)
var bow_color := Color(1.4, 1.3, 1.0)
var bow_show: float = 0.0
var sword_tex: Texture2D = null
var sword_scale: float = 1.0
var female: bool = false
var plume_color := Color(0.78, 0.12, 0.16)
var hair_color := Color(0.20, 0.12, 0.06)
var hero_id: String = "ayaan"
## When true (shop preview), slowly spin the 3D model.
var shop_spin: bool = false

# ---- state set by Player.gd ----
var aim_angle: float = 0.0
var move_amount: float = 0.0
var attack_progress: float = -1.0
var dodging: bool = false

var _walk: float = 0.0
var _time: float = 0.0
var _angle: float = 0.0

const OUTLINE := Color(0.06, 0.06, 0.09)
const VIEW_SIZE := Vector2i(256, 256)

var _use_3d: bool = false
var _svpc: SubViewportContainer
var _svp: SubViewport
var _world: Node3D
var _pivot: Node3D
var _model_root: Node3D
var _anim: AnimationPlayer
var _cam: Camera3D
var _loaded_id: String = ""
var _current_anim: String = ""
var _spin: float = 0.0


func apply_hero(h: Dictionary) -> void:
	cape = h["cape"]
	cape_dark = Color(cape.r * 0.5, cape.g * 0.5, cape.b * 0.5)
	plume_color = h["plume"]
	female = bool(h["female"])
	hero_id = String(h.get("id", "ayaan"))
	_ensure_3d()


func apply_loadout(suit: Dictionary, sword: Dictionary, bow: Dictionary) -> void:
	steel = suit["steel"]
	steel_dark = suit["steel_dark"]
	gold = suit["gold"]
	cape = suit["cape"]
	cape_dark = Color(cape.r * 0.5, cape.g * 0.5, cape.b * 0.5)
	gold_dark = Color(gold.r * 0.55, gold.g * 0.55, gold.b * 0.55)
	blade_color = sword["blade"]
	bow_color = bow["color"]
	sword_tex = null
	if sword.has("sprite"):
		sword_tex = load(String(sword["sprite"]))
		sword_scale = 46.0 / maxf(sword_tex.get_height(), 1.0)


func _ready() -> void:
	call_deferred("_ensure_3d")


func _glb_path(id: String) -> String:
	return "res://assets/models/heroes/final/%s/hero.glb" % id


func _ensure_3d() -> void:
	if not is_inside_tree():
		call_deferred("_ensure_3d")
		return
	var path := _glb_path(hero_id)
	if not ResourceLoader.exists(path):
		_teardown_3d()
		_use_3d = false
		queue_redraw()
		return
	if _use_3d and _loaded_id == hero_id and _model_root != null:
		return
	_setup_viewport()
	_load_model(path)
	_use_3d = _model_root != null
	_loaded_id = hero_id if _use_3d else ""
	if _svpc:
		_svpc.visible = _use_3d
	queue_redraw()


func _teardown_3d() -> void:
	if _svpc and is_instance_valid(_svpc):
		_svpc.queue_free()
	_svpc = null
	_svp = null
	_world = null
	_pivot = null
	_model_root = null
	_anim = null
	_cam = null


func _setup_viewport() -> void:
	if _svpc and is_instance_valid(_svpc):
		return
	_svpc = SubViewportContainer.new()
	_svpc.name = "Hero3DView"
	_svpc.stretch = true
	_svpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_svpc.position = Vector2(-64, -64)
	_svpc.size = Vector2(VIEW_SIZE)
	add_child(_svpc)

	_svp = SubViewport.new()
	_svp.name = "SVP"
	_svp.size = VIEW_SIZE
	_svp.transparent_bg = true
	_svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_svp.world_3d = World3D.new()
	_svpc.add_child(_svp)

	_world = Node3D.new()
	_world.name = "World"
	_svp.add_child(_world)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 35, 0)
	light.light_energy = 1.15
	_world.add_child(light)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.2, 1.6, 1.4)
	fill.light_energy = 0.55
	_world.add_child(fill)

	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	_world.add_child(_pivot)

	_cam = Camera3D.new()
	# Top-down-ish for dungeon; shop uses same with spin.
	_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	_cam.fov = 35.0
	_cam.position = Vector3(0.0, 2.6, 2.4)
	# look_at requires node in tree — set basis manually until added.
	_cam.rotation_degrees = Vector3(-42.0, 0.0, 0.0)
	_cam.current = true
	_world.add_child(_cam)
	_cam.look_at(Vector3(0.0, 0.9, 0.0))


func _load_model(path: String) -> void:
	if _model_root and is_instance_valid(_model_root):
		_model_root.queue_free()
		_model_root = null
		_anim = null
	var packed: PackedScene = load(path)
	if packed == null:
		return
	_model_root = packed.instantiate() as Node3D
	if _model_root == null:
		return
	_pivot.add_child(_model_root)
	# Ground the model roughly at origin
	_model_root.position = Vector3(0, 0, 0)
	_model_root.scale = Vector3.ONE * 0.95
	_anim = _find_anim_player(_model_root)
	_current_anim = ""
	_play_anim("idle")


func _find_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var found := _find_anim_player(c)
		if found:
			return found
	return null


func _anim_names() -> PackedStringArray:
	if _anim == null:
		return PackedStringArray()
	return _anim.get_animation_list()


func _resolve_anim(want: String) -> String:
	var names := _anim_names()
	for n in names:
		if String(n) == want or String(n).ends_with("/" + want) or String(n).get_file() == want:
			return String(n)
	# Case-insensitive contains
	for n in names:
		if want.to_lower() in String(n).to_lower():
			return String(n)
	return ""


func _play_anim(want: String) -> void:
	if _anim == null:
		return
	var resolved := _resolve_anim(want)
	if resolved == "" or resolved == _current_anim:
		if resolved == _current_anim and _anim.is_playing():
			return
		if resolved == "":
			return
	_current_anim = resolved
	_anim.play(resolved)


func _pick_anim() -> String:
	if dodging:
		return "dodge"
	if attack_progress >= 0.0:
		return "slash"
	if move_amount > 0.65:
		return "run"
	if move_amount > 0.08:
		return "walk"
	return "idle"


func _process(delta: float) -> void:
	_time += delta
	bow_show = maxf(bow_show - delta, 0.0)
	if move_amount > 0.05:
		_walk += delta * 13.0
	_angle = lerp_angle(_angle, aim_angle, minf(1.0, delta * 20.0))

	if _use_3d and _pivot != null:
		if shop_spin:
			_spin += delta * 0.7
			_pivot.rotation.y = _spin
			if _cam and _cam.is_inside_tree():
				_cam.position = Vector3(0.0, 1.55, 3.1)
				_cam.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)
		else:
			# Face movement / aim in top-down plane (Godot Y-up)
			_pivot.rotation.y = -_angle + PI * 0.5
			if _cam and _cam.is_inside_tree():
				_cam.position = Vector3(0.0, 2.6, 2.4)
				_cam.look_at(Vector3(0.0, 0.9, 0.0), Vector3.UP)
		_play_anim(_pick_anim())
	else:
		queue_redraw()


func _ellipse(center: Vector2, rx: float, ry: float, color: Color, segs: int = 22) -> void:
	var pts := PackedVector2Array()
	for i in segs:
		var a: float = TAU * float(i) / float(segs)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)


func _ellipse_o(center: Vector2, rx: float, ry: float, color: Color, rim: float = 1.4) -> void:
	_ellipse(center, rx + rim, ry + rim, OUTLINE)
	_ellipse(center, rx, ry, color)


func _circle_o(center: Vector2, r: float, color: Color, rim: float = 1.4) -> void:
	draw_circle(center, r + rim, OUTLINE)
	draw_circle(center, r, color)


func _draw() -> void:
	if _use_3d:
		# Soft ground shadow under the viewport sprite
		draw_set_transform(Vector2(2, 18), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.22))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	_draw_procedural()


## Original procedural knight (fallback if GLB missing).
func _draw_procedural() -> void:
	var swinging := attack_progress >= 0.0
	draw_set_transform(Vector2(2, 11), 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, 25.0, Color(0, 0, 0, 0.22))
	draw_circle(Vector2.ZERO, 19.0, Color(0, 0, 0, 0.28))
	var squash := Vector2(1.25, 0.78) if dodging else Vector2.ONE
	var breathe := 1.0 + sin(_time * 2.2) * 0.02
	draw_set_transform(Vector2.ZERO, _angle, squash * breathe)
	var sway := sin(_walk * 0.5 + _time * 2.0) * 3.0 + move_amount * 5.0
	var tail := -24.0 - move_amount * 7.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-1, -14), Vector2(-1, 14), Vector2(tail - 1.0, 10.0 + sway),
		Vector2(tail - 4.5, 0.0), Vector2(tail - 1.0, -10.0 + sway)]), OUTLINE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-1, -13), Vector2(-1, 13), Vector2(tail, 9.0 + sway),
		Vector2(tail - 3.0, 0.0), Vector2(tail, -9.0 + sway)]), cape_dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2, -9), Vector2(-2, 9), Vector2(tail + 5.0, 6.0 + sway * 0.8),
		Vector2(tail + 3.0, 0.0), Vector2(tail + 5.0, -6.0 + sway * 0.8)]), cape)
	var step := sin(_walk) * 7.0 * move_amount
	_ellipse_o(Vector2(step, -7.0), 6.5, 4.6, steel_dark)
	_ellipse_o(Vector2(-step, 7.0), 6.5, 4.6, steel_dark)
	_ellipse_o(Vector2.ZERO, 12.8, 16.8, steel_dark)
	_ellipse(Vector2(0.5, 0.0), 11.2, 14.8, steel)
	var sword_a := -0.30 + sin(_walk) * 0.08 * move_amount
	if swinging:
		var e := 1.0 - pow(1.0 - clampf(attack_progress, 0.0, 1.0), 3.0)
		sword_a = lerpf(2.0, -1.9, e)
	var hand := Vector2(10.0, 13.0) + Vector2.from_angle(sword_a) * 4.0
	draw_line(Vector2(-1, 14.5), hand, steel, 3.6)
	var dir := Vector2.from_angle(sword_a)
	var tip := hand + dir * 42.0
	draw_line(hand, tip, blade_color, 3.0)
	_circle_o(Vector2(3.5, 0.0), 10.2, steel_dark)
	_circle_o(Vector2(3.5, 0.0), 8.9, steel, 0.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
