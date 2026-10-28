extends Node2D
## HeroArt.gd — the hero: an armored knight drawn from layered, shaded shapes (top-down view)
## with procedural animation: idle breathing, walk cycle, sword swing with glowing trail,
## dodge-roll squash. Player.gd feeds it the state below every physics frame.

var steel := Color(0.60, 0.65, 0.74)
var steel_dark := Color(0.26, 0.29, 0.37)
var gold := Color(0.93, 0.74, 0.30)
var gold_dark := Color(0.50, 0.36, 0.12)
var cape := Color(0.66, 0.10, 0.15)
var cape_dark := Color(0.34, 0.05, 0.09)
var blade_color := Color(0.82, 0.87, 0.95)
var bow_color := Color(1.4, 1.3, 1.0)
var bow_show: float = 0.0          # >0 while the bow is drawn (after a shot)
var sword_tex: Texture2D = null   # sprite of the equipped sword, if it has one
var sword_scale: float = 1.0      # scales the sprite so its blade is about 46 px long
var female: bool = false          # adds a skirt and long hair
var plume_color := Color(0.78, 0.12, 0.16)
var hair_color := Color(0.20, 0.12, 0.06)

# ---- state set by Player.gd ----
var aim_angle: float = 0.0         # direction the hero faces (radians)
var move_amount: float = 0.0       # 0..1
var attack_progress: float = -1.0  # -1 = not attacking, 0..1 = swing progress
var dodging: bool = false

var _walk: float = 0.0
var _time: float = 0.0
var _angle: float = 0.0

const OUTLINE := Color(0.06, 0.06, 0.09)


## Look of the chosen hero (see Heroes.gd): cape and plume colours, and whether she has a skirt.
func apply_hero(h: Dictionary) -> void:
	cape = h["cape"]
	cape_dark = Color(cape.r * 0.5, cape.g * 0.5, cape.b * 0.5)
	plume_color = h["plume"]
	female = bool(h["female"])


## Colours from the equipped suit / sword / bow (see Items.gd).
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


func _process(delta: float) -> void:
	_time += delta
	bow_show = maxf(bow_show - delta, 0.0)
	if move_amount > 0.05:
		_walk += delta * 13.0
	_angle = lerp_angle(_angle, aim_angle, minf(1.0, delta * 20.0))
	queue_redraw()


func _ellipse(center: Vector2, rx: float, ry: float, color: Color, segs: int = 22) -> void:
	var pts := PackedVector2Array()
	for i in segs:
		var a: float = TAU * float(i) / float(segs)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)


## Ellipse with a dark rim, so every part reads clearly against the floor.
func _ellipse_o(center: Vector2, rx: float, ry: float, color: Color, rim: float = 1.4) -> void:
	_ellipse(center, rx + rim, ry + rim, OUTLINE)
	_ellipse(center, rx, ry, color)


## Circle with a dark rim.
func _circle_o(center: Vector2, r: float, color: Color, rim: float = 1.4) -> void:
	draw_circle(center, r + rim, OUTLINE)
	draw_circle(center, r, color)


func _draw() -> void:
	var swinging := attack_progress >= 0.0

	# ---------- ground shadow (unrotated, flattened) ----------
	draw_set_transform(Vector2(2, 11), 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, 25.0, Color(0, 0, 0, 0.22))
	draw_circle(Vector2.ZERO, 19.0, Color(0, 0, 0, 0.28))

	# ---------- body space: +x is "forward" ----------
	var squash := Vector2(1.25, 0.78) if dodging else Vector2.ONE
	var breathe := 1.0 + sin(_time * 2.2) * 0.02
	draw_set_transform(Vector2.ZERO, _angle, squash * breathe)

	var sway := sin(_walk * 0.5 + _time * 2.0) * 3.0 + move_amount * 5.0

	# ---------- cape (two layers, with a fold line and a dark rim) ----------
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
	draw_line(Vector2(-3, 0), Vector2(tail + 3.0, sway * 0.4), cape_dark, 1.2)   # fold
	draw_line(Vector2(-3, -5), Vector2(tail + 6.0, -4.0 + sway * 0.6), Color(1, 1, 1, 0.12), 1.0)

	if female:
		draw_colored_polygon(PackedVector2Array([Vector2(2, -12), Vector2(2, 12), Vector2(-12 + sway * 0.3, 14.0), Vector2(-12 + sway * 0.3, -14.0)]), cape)

	# ---------- boots (walk cycle): dark rim, steel, sole highlight ----------
	var step := sin(_walk) * 7.0 * move_amount
	_ellipse_o(Vector2(step, -7.0), 6.5, 4.6, steel_dark)
	_ellipse_o(Vector2(-step, 7.0), 6.5, 4.6, steel_dark)
	_ellipse(Vector2(step + 1.5, -7.5), 3.6, 2.4, steel)
	_ellipse(Vector2(-step + 1.5, 6.5), 3.6, 2.4, steel)
	draw_line(Vector2(step - 2.0, -9.0), Vector2(step + 4.0, -9.0), Color(1, 1, 1, 0.35), 1.0)
	draw_line(Vector2(-step - 2.0, 5.0), Vector2(-step + 4.0, 5.0), Color(1, 1, 1, 0.35), 1.0)

	# ---------- shield arm (left, -y): strap, rim, cross emblem, studs ----------
	var sh := Vector2(8.0, -17.0)
	draw_line(Vector2(-1, -14.5), sh, OUTLINE, 8.0)
	draw_line(Vector2(-1, -14.5), sh, steel_dark, 6.0)
	_ellipse_o(sh, 7.5, 11.5, gold_dark)
	_ellipse(sh, 6.2, 10.2, Color(0.55, 0.09, 0.13))
	_ellipse(sh + Vector2(1.5, -2.0), 3.2, 5.0, Color(1, 1, 1, 0.12))
	draw_line(sh + Vector2(-4.5, 0.0), sh + Vector2(4.5, 0.0), Color(0.95, 0.94, 0.9), 2.0)  # white cross
	draw_line(sh + Vector2(0.0, -6.0), sh + Vector2(0.0, 6.0), Color(0.95, 0.94, 0.9), 2.0)
	for stud in [Vector2(-3.5, -7.0), Vector2(3.5, -7.0), Vector2(-3.5, 7.0), Vector2(3.5, 7.0)]:
		draw_circle(sh + stud, 1.0, gold)
	_circle_o(sh, 2.6, gold)

	# ---------- torso: layered plate, chest ridge, red tabard with a white cross ----------
	_ellipse_o(Vector2.ZERO, 12.8, 16.8, steel_dark)
	_ellipse(Vector2(0.5, 0.0), 11.2, 14.8, steel)
	_ellipse(Vector2(-3.5, 4.0), 6.0, 8.0, Color(0, 0, 0, 0.12))                 # side shade
	_ellipse(Vector2(2.6, -3.2), 5.6, 7.6, Color(0.92, 0.95, 1.0, 0.42))         # highlight
	draw_colored_polygon(PackedVector2Array([
		Vector2(3.0, -7.5), Vector2(9.5, -7.5), Vector2(10.5, 0.0),
		Vector2(9.5, 7.5), Vector2(3.0, 7.5)]), cape)
	draw_line(Vector2(5.0, -4.0), Vector2(5.0, 4.0), Color(0.80, 0.14, 0.16), 2.0)   # tabard cross
	draw_line(Vector2(2.6, 0.0), Vector2(7.4, 0.0), Color(0.80, 0.14, 0.16), 2.0)
	draw_line(Vector2(-8, 0), Vector2(9, 0), gold, 1.6)                          # belt
	_circle_o(Vector2(2.0, 0.0), 1.6, gold, 0.6)                                 # buckle
	draw_arc(Vector2(0.5, 0.0), 11.2, -1.2, 1.2, 12, Color(gold, 0.7), 1.4)
	draw_line(Vector2(-6.0, -9.0), Vector2(-6.0, 9.0), Color(1, 1, 1, 0.10), 1.0)  # ridge
	for s in [-1.0, 1.0]:
		var pc := Vector2(-1.0, 15.5 * s)
		draw_circle(pc, 8.6, OUTLINE)
		draw_circle(pc, 7.8, steel_dark)
		draw_circle(pc + Vector2(0.5, -0.5), 6.3, steel)
		draw_arc(pc, 5.6, -2.4, -0.6, 10, Color(1, 1, 1, 0.45), 1.2)               # rim gleam
		draw_circle(pc + Vector2(1.6, -1.8), 2.7, Color(1, 1, 1, 0.38))
		draw_circle(pc + Vector2(-2.5, 1.5 * s), 0.9, gold)                        # rivet

	# ---------- sword arm (right, +y) ----------
	var sword_a := -0.30 + sin(_walk) * 0.08 * move_amount
	if swinging:
		var e := 1.0 - pow(1.0 - clampf(attack_progress, 0.0, 1.0), 3.0)
		sword_a = lerpf(2.0, -1.9, e)
	var hand := Vector2(10.0, 13.0) + Vector2.from_angle(sword_a) * 4.0
	draw_line(Vector2(-1, 14.5), hand, OUTLINE, 8.0)
	draw_line(Vector2(-1, 14.5), hand, steel_dark, 6.5)
	draw_line(Vector2(-1, 14.5), hand, steel, 3.6)

	if swinging:
		var fade := 1.0 - attack_progress * 0.7
		var a_end := minf(sword_a + 1.5, 2.2)
		draw_arc(hand, 30.0, sword_a, a_end, 24, Color(1.4, 1.2, 0.8, 0.14 * fade), 22.0)
		draw_arc(hand, 33.0, sword_a, a_end, 24, Color(1.6, 1.4, 0.9, 0.30 * fade), 11.0)
		draw_arc(hand, 36.0, sword_a, a_end, 24, Color(2.0, 1.9, 1.5, 0.85 * fade), 3.0)

	var dir := Vector2.from_angle(sword_a)
	var perp := dir.rotated(PI * 0.5)
	var base := hand + dir * 4.0
	var tip := hand + dir * 42.0
	if sword_tex != null:
		# Sprite sword: its tip points up in the image, so turn it to face the swing direction.
		var body_t := Transform2D(_angle, squash * breathe, 0.0, Vector2.ZERO)
		var local_t := Transform2D(sword_a + PI * 0.5, Vector2(sword_scale, sword_scale), 0.0, hand)
		draw_set_transform_matrix(body_t * local_t)
		var sz := sword_tex.get_size()
		draw_texture(sword_tex, Vector2(-sz.x * 0.5, -sz.y * 0.85))
		draw_set_transform_matrix(body_t)
	else:
		# Procedural blade: dark outline, bright edge, fuller line, crossguard with gems.
		draw_colored_polygon(PackedVector2Array([base + perp * 4.4, tip, base - perp * 4.4]), OUTLINE)
		draw_line(hand - dir * 4.0, base, Color(0.25, 0.14, 0.08), 3.4)                       # grip
		draw_colored_polygon(PackedVector2Array([base + perp * 3.2, tip, base - perp * 3.2]),
				blade_color)                                                                  # blade
		draw_colored_polygon(PackedVector2Array([base + perp * 1.0, tip, base - perp * 0.2]),
				Color(1, 1, 1, 0.85))                                                         # edge gleam
		draw_line(base + dir * 6.0, tip - dir * 4.0, blade_color.darkened(0.25), 1.0)        # fuller
		draw_line(base + perp * 8.0, base - perp * 8.0, OUTLINE, 4.6)
		draw_line(base + perp * 8.0, base - perp * 8.0, gold, 3.2)                            # guard
		draw_circle(base + perp * 8.0, 1.4, Color(0.9, 0.2, 0.25))                            # guard gems
		draw_circle(base - perp * 8.0, 1.4, Color(0.9, 0.2, 0.25))
		_circle_o(hand - dir * 5.0, 2.4, gold, 0.8)                                           # pommel
	_circle_o(hand, 3.4, steel, 0.9)                                                          # gauntlet

	# ---------- bow (shown briefly after a shot) ----------
	if bow_show > 0.0:
		var bc: Vector2 = Vector2(26.0, 0.0)
		draw_arc(bc, 17.0, -1.15, 1.15, 14, Color(0.55, 0.36, 0.18), 3.4)
		draw_line(bc + Vector2.from_angle(-1.15) * 17.0, bc + Vector2.from_angle(1.15) * 17.0, Color(1, 1, 1, 0.7), 1.0)
		draw_line(Vector2(8.0, 0.0), bc + Vector2(5.0, 0.0), bow_color, 2.0)

	# ---------- head: plume, bascinet helm with rivets, visor slits and eyes ----------
	var hp := Vector2(3.5, 0.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, -3), Vector2(-5, 3), Vector2(-20.0 - sway, 2.0 + sway * 0.5),
		Vector2(-23.0 - sway, -1.0)]), plume_color)                                           # plume
	draw_line(Vector2(-6, -1.0), Vector2(-20.0 - sway, 1.0 + sway * 0.4), plume_color.lightened(0.35), 1.0)
	if female:
		_ellipse(hp + Vector2(-5.0, 0.0), 8.0, 9.0, hair_color)
	_circle_o(hp, 10.2, steel_dark)
	_circle_o(hp, 8.9, steel, 0.0)
	draw_circle(hp + Vector2(-1.5, -2.6), 4.6, Color(1, 1, 1, 0.28))                       # dome gleam
	draw_arc(hp, 8.4, PI * 0.7, PI * 1.25, 10, Color(1, 1, 1, 0.35), 1.2)
	draw_line(hp + Vector2(-8, 0), hp + Vector2(9, 0), gold, 1.7)                          # crest ridge
	draw_circle(hp + Vector2(-4.0, -5.5), 1.0, gold)                                       # rivets
	draw_circle(hp + Vector2(-4.0, 5.5), 1.0, gold)
	_ellipse(hp + Vector2(5.6, 0.0), 3.6, 6.4, OUTLINE)                                     # visor opening
	_ellipse(hp + Vector2(5.8, 0.0), 2.6, 5.2, Color(0.03, 0.03, 0.05))
	draw_line(hp + Vector2(4.0, -3.0), hp + Vector2(8.6, -3.0), steel_dark, 1.0)            # visor bars
	draw_line(hp + Vector2(4.0, 3.0), hp + Vector2(8.6, 3.0), steel_dark, 1.0)
	draw_circle(hp + Vector2(6.6, -2.4), 0.95, Color(1.2, 1.7, 2.2))                       # eye glints
	draw_circle(hp + Vector2(6.6, 2.4), 0.95, Color(1.2, 1.7, 2.2))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
