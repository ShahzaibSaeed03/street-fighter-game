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

# ---- state set by Player.gd ----
var aim_angle: float = 0.0         # direction the hero faces (radians)
var move_amount: float = 0.0       # 0..1
var attack_progress: float = -1.0  # -1 = not attacking, 0..1 = swing progress
var dodging: bool = false

var _walk: float = 0.0
var _time: float = 0.0
var _angle: float = 0.0


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

	# ---------- cape ----------
	var tail := -24.0 - move_amount * 7.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-1, -13), Vector2(-1, 13), Vector2(tail, 9.0 + sway),
		Vector2(tail - 3.0, 0.0), Vector2(tail, -9.0 + sway)]), cape_dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2, -9), Vector2(-2, 9), Vector2(tail + 5.0, 6.0 + sway * 0.8),
		Vector2(tail + 3.0, 0.0), Vector2(tail + 5.0, -6.0 + sway * 0.8)]), cape)

	# ---------- boots (walk cycle) ----------
	var step := sin(_walk) * 7.0 * move_amount
	_ellipse(Vector2(step, -7.0), 6.5, 4.6, steel_dark)
	_ellipse(Vector2(-step, 7.0), 6.5, 4.6, steel_dark)
	_ellipse(Vector2(step + 1.5, -7.5), 3.6, 2.4, steel)
	_ellipse(Vector2(-step + 1.5, 6.5), 3.6, 2.4, steel)

	# ---------- shield arm (left, -y) ----------
	var sh := Vector2(8.0, -17.0)
	draw_line(Vector2(-1, -14.5), sh, steel_dark, 6.0)
	_ellipse(sh, 7.5, 11.5, gold_dark)
	_ellipse(sh, 6.2, 10.2, Color(0.55, 0.09, 0.13))
	_ellipse(sh + Vector2(1.5, -2.0), 3.2, 5.0, Color(1, 1, 1, 0.12))
	draw_circle(sh, 3.0, gold)
	draw_circle(sh + Vector2(0.6, -0.6), 1.2, Color(1, 1, 0.8, 0.9))

	# ---------- torso ----------
	_ellipse(Vector2.ZERO, 12.8, 16.8, steel_dark)
	_ellipse(Vector2(0.5, 0.0), 11.2, 14.8, steel)
	_ellipse(Vector2(2.6, -3.2), 5.6, 7.6, Color(0.92, 0.95, 1.0, 0.42))
	draw_line(Vector2(-8, 0), Vector2(9, 0), gold, 1.6)
	draw_arc(Vector2(0.5, 0.0), 11.2, -1.2, 1.2, 12, Color(gold, 0.7), 1.4)
	for s in [-1.0, 1.0]:
		var pc := Vector2(-1.0, 15.5 * s)
		draw_circle(pc, 7.8, steel_dark)
		draw_circle(pc + Vector2(0.5, -0.5), 6.3, steel)
		draw_circle(pc + Vector2(1.6, -1.8), 2.7, Color(1, 1, 1, 0.38))

	# ---------- sword arm (right, +y) ----------
	var sword_a := -0.30 + sin(_walk) * 0.08 * move_amount
	if swinging:
		var e := 1.0 - pow(1.0 - clampf(attack_progress, 0.0, 1.0), 3.0)
		sword_a = lerpf(2.0, -1.9, e)
	var hand := Vector2(10.0, 13.0) + Vector2.from_angle(sword_a) * 4.0
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
	draw_line(hand - dir * 4.0, base, Color(0.25, 0.14, 0.08), 3.4)                       # grip
	draw_colored_polygon(PackedVector2Array([base + perp * 3.2, tip, base - perp * 3.2]),
			blade_color)                                                                  # blade
	draw_colored_polygon(PackedVector2Array([base + perp * 1.0, tip, base - perp * 0.2]),
			Color(1, 1, 1, 0.85))                                                         # highlight
	draw_line(base + perp * 8.0, base - perp * 8.0, gold, 3.2)                             # guard
	draw_circle(hand - dir * 5.0, 2.4, gold)                                               # pommel

	# ---------- bow (shown briefly after a shot) ----------
	if bow_show > 0.0:
		var bc: Vector2 = Vector2(26.0, 0.0)
		draw_arc(bc, 17.0, -1.15, 1.15, 14, Color(0.55, 0.36, 0.18), 3.4)
		draw_line(bc + Vector2.from_angle(-1.15) * 17.0, bc + Vector2.from_angle(1.15) * 17.0, Color(1, 1, 1, 0.7), 1.0)
		draw_line(Vector2(8.0, 0.0), bc + Vector2(5.0, 0.0), bow_color, 2.0)

	# ---------- head ----------
	var hp := Vector2(3.5, 0.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, -3), Vector2(-5, 3), Vector2(-20.0 - sway, 2.0 + sway * 0.5),
		Vector2(-23.0 - sway, -1.0)]), Color(0.78, 0.12, 0.16))                            # plume
	draw_circle(hp, 10.2, steel_dark)
	draw_circle(hp, 8.9, steel)
	draw_circle(hp + Vector2(-1.5, -2.6), 4.6, Color(1, 1, 1, 0.28))
	draw_line(hp + Vector2(-8, 0), hp + Vector2(9, 0), gold, 1.7)                          # crest
	_ellipse(hp + Vector2(5.6, 0.0), 3.4, 6.2, Color(0.03, 0.03, 0.05))                    # visor
	draw_circle(hp + Vector2(6.6, -2.4), 0.95, Color(1.2, 1.7, 2.2))                       # eye glints
	draw_circle(hp + Vector2(6.6, 2.4), 0.95, Color(1.2, 1.7, 2.2))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
