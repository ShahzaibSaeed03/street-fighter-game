extends Node2D
## HeroArt.gd — top-down hero art driven by pre-baked shaded sprites (option B).
## Public API matches the old procedural version so Player.gd / Menu.gd keep working:
## apply_hero, apply_loadout, aim_angle, move_amount, attack_progress, dodging, bow_show.

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

# ---- state set by Player.gd ----
var aim_angle: float = 0.0
var move_amount: float = 0.0
var attack_progress: float = -1.0
var dodging: bool = false

var _walk: float = 0.0
var _time: float = 0.0
var _angle: float = 0.0

## Display scale: baked sprites are 256px; in-dungeon footprint stays ~old procedural size.
const SPRITE_SCALE := 0.40
const OUTLINE := Color(0.06, 0.06, 0.09)

var _frames: Dictionary = {}  # frame_name -> Texture2D
var _frame_names := ["idle", "walk_a", "walk_b", "attack", "dodge"]


func apply_hero(h: Dictionary) -> void:
	cape = h["cape"]
	cape_dark = Color(cape.r * 0.5, cape.g * 0.5, cape.b * 0.5)
	plume_color = h["plume"]
	female = bool(h["female"])
	hero_id = String(h.get("id", "ayaan"))
	_load_frames()


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


func _load_frames() -> void:
	_frames.clear()
	for fr in _frame_names:
		var path := "res://assets/heroes/%s_top_%s.png" % [hero_id, fr]
		if ResourceLoader.exists(path):
			_frames[fr] = load(path)


func _ready() -> void:
	if _frames.is_empty():
		_load_frames()


func _process(delta: float) -> void:
	_time += delta
	bow_show = maxf(bow_show - delta, 0.0)
	if move_amount > 0.05:
		_walk += delta * 13.0
	_angle = lerp_angle(_angle, aim_angle, minf(1.0, delta * 20.0))
	queue_redraw()


func _pick_frame() -> Texture2D:
	if dodging and _frames.has("dodge"):
		return _frames["dodge"]
	if attack_progress >= 0.0 and _frames.has("attack"):
		return _frames["attack"]
	if move_amount > 0.08:
		var phase: float = fposmod(_walk * 0.5, TAU)
		var name := "walk_a" if sin(phase) >= 0.0 else "walk_b"
		if _frames.has(name):
			return _frames[name]
	if _frames.has("idle"):
		return _frames["idle"]
	# Any available frame as last resort.
	for fr in _frame_names:
		if _frames.has(fr):
			return _frames[fr]
	return null


func _draw() -> void:
	var tex: Texture2D = _pick_frame()
	var swinging := attack_progress >= 0.0
	var breathe := 1.0 + sin(_time * 2.2) * 0.015
	var squash := Vector2(1.18, 0.82) if dodging else Vector2.ONE
	var sc := SPRITE_SCALE * breathe

	# Soft ground shadow (extra, under sprite's own baked shadow)
	draw_set_transform(Vector2(2, 10), 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.18))

	draw_set_transform(Vector2.ZERO, _angle, squash * sc)
	if tex != null:
		var sz := tex.get_size()
		# Baked facing +X (right); CharacterBody2D aim_angle 0 also faces +X.
		draw_texture(tex, -sz * 0.5)
	else:
		_draw_fallback_blob()

	# Keep equipped sword sprite overlay when a custom sword is equipped (attack read).
	if sword_tex != null and swinging:
		var e := 1.0 - pow(1.0 - clampf(attack_progress, 0.0, 1.0), 3.0)
		var sword_a := lerpf(2.0, -1.9, e)
		var hand := Vector2(10.0, 13.0) / sc
		var body_t := Transform2D(_angle, squash * sc, 0.0, Vector2.ZERO)
		var local_t := Transform2D(sword_a + PI * 0.5, Vector2(sword_scale / sc, sword_scale / sc), 0.0, hand)
		draw_set_transform_matrix(body_t * local_t)
		var ssz := sword_tex.get_size()
		draw_texture(sword_tex, Vector2(-ssz.x * 0.5, -ssz.y * 0.85))

	# Brief bow flash after a shot (readable cue on top of sprite)
	if bow_show > 0.0:
		draw_set_transform(Vector2.ZERO, _angle, squash * sc)
		var bc := Vector2(55.0, 0.0)
		draw_arc(bc, 28.0, -1.15, 1.15, 14, Color(0.55, 0.36, 0.18), 3.4)
		draw_line(bc + Vector2.from_angle(-1.15) * 28.0, bc + Vector2.from_angle(1.15) * 28.0, Color(1, 1, 1, 0.7), 1.0)
		draw_line(Vector2(18.0, 0.0), bc + Vector2(5.0, 0.0), bow_color, 2.0)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Tiny procedural stand-in if assets failed to load (should not happen in shipping builds).
func _draw_fallback_blob() -> void:
	draw_circle(Vector2.ZERO, 18.0, OUTLINE)
	draw_circle(Vector2.ZERO, 16.0, steel)
	draw_circle(Vector2(6, 0), 8.0, steel_dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2, -10), Vector2(-2, 10), Vector2(-28, 6), Vector2(-30, 0), Vector2(-28, -6)]), cape)
