extends Node2D
## CreatureArt.gd — drawn-in-code monsters: bat, wasp, vulture (flying), spider, scorpion, golem,
## wraith. Same interface as EnemyArt.gd so Guard.gd can use either one.
## Set `species` before add_child(), then call setup(tier).

const EnemyArtScript := preload("res://EnemyArt.gd")

const FIXED: Dictionary = {
	"bat": {"skin": Color(0.30, 0.22, 0.34), "dark": Color(0.14, 0.10, 0.18), "accent": Color(0.55, 0.40, 0.60),
		"eye": Color(2.0, 0.4, 0.4), "blood": Color(0.6, 0.15, 0.2)},
	"wasp": {"skin": Color(0.92, 0.75, 0.15), "dark": Color(0.12, 0.10, 0.06), "accent": Color(0.85, 0.95, 1.0),
		"eye": Color(2.0, 0.3, 0.2), "blood": Color(0.8, 0.7, 0.2)},
	"vulture": {"skin": Color(0.30, 0.24, 0.20), "dark": Color(0.14, 0.11, 0.09), "accent": Color(0.85, 0.55, 0.5),
		"eye": Color(2.0, 1.5, 0.3), "blood": Color(0.6, 0.15, 0.15)},
	"spider": {"skin": Color(0.14, 0.19, 0.11), "dark": Color(0.05, 0.07, 0.04), "accent": Color(0.55, 0.75, 0.20),
		"eye": Color(2.0, 0.2, 0.2), "blood": Color(0.3, 0.7, 0.15)},
	"scorpion": {"skin": Color(0.62, 0.45, 0.22), "dark": Color(0.32, 0.20, 0.10), "accent": Color(0.85, 0.70, 0.35),
		"eye": Color(1.8, 0.8, 0.2), "blood": Color(0.8, 0.7, 0.3)},
	"hound": {"skin": Color(0.42, 0.36, 0.30), "dark": Color(0.18, 0.14, 0.12), "accent": Color(0.75, 0.65, 0.5),
		"eye": Color(2.0, 0.9, 0.2), "blood": Color(0.6, 0.12, 0.1)},
}

## Skeletons and ghosts change colour with the level tier: bone / ember / frost / void.
const SKELETON_PALS: Array[Dictionary] = [
	{"skin": Color(0.86, 0.84, 0.74), "dark": Color(0.26, 0.24, 0.20), "accent": Color(0.62, 0.58, 0.48),
		"eye": Color(0.5, 1.9, 0.7), "blood": Color(0.85, 0.82, 0.68)},
	{"skin": Color(0.82, 0.72, 0.60), "dark": Color(0.32, 0.17, 0.10), "accent": Color(0.95, 0.55, 0.20),
		"eye": Color(2.0, 0.9, 0.2), "blood": Color(0.95, 0.50, 0.15)},
	{"skin": Color(0.82, 0.92, 0.98), "dark": Color(0.18, 0.28, 0.40), "accent": Color(0.55, 0.80, 1.00),
		"eye": Color(0.6, 1.7, 2.2), "blood": Color(0.60, 0.85, 1.00)},
	{"skin": Color(0.76, 0.68, 0.86), "dark": Color(0.20, 0.10, 0.30), "accent": Color(0.85, 0.40, 1.00),
		"eye": Color(2.0, 0.5, 1.7), "blood": Color(0.80, 0.35, 0.95)},
]
const GHOST_PALS: Array[Dictionary] = [
	{"skin": Color(0.88, 0.95, 0.92), "dark": Color(0.30, 0.45, 0.42), "accent": Color(0.55, 1.00, 0.85),
		"eye": Color(0.5, 2.0, 1.4), "blood": Color(0.6, 1.0, 0.85)},
	{"skin": Color(1.00, 0.88, 0.75), "dark": Color(0.55, 0.25, 0.10), "accent": Color(1.00, 0.55, 0.20),
		"eye": Color(2.0, 0.9, 0.2), "blood": Color(1.0, 0.6, 0.25)},
	{"skin": Color(0.88, 0.95, 1.00), "dark": Color(0.25, 0.40, 0.60), "accent": Color(0.55, 0.85, 1.00),
		"eye": Color(0.6, 1.7, 2.3), "blood": Color(0.65, 0.88, 1.0)},
	{"skin": Color(0.90, 0.80, 1.00), "dark": Color(0.35, 0.18, 0.50), "accent": Color(0.85, 0.45, 1.00),
		"eye": Color(2.0, 0.5, 1.8), "blood": Color(0.85, 0.45, 1.0)},
]

var species: String = "bat"
var tier: int = 0
var aim_angle: float = 0.0
var pulse: float = 0.0

var _walk: float = randf() * TAU
var _time: float = randf() * 10.0
var _angle: float = 0.0
var _pal: Dictionary = {}


func setup(new_tier: int) -> void:
	tier = new_tier % 4
	if species == "skeleton":
		_pal = SKELETON_PALS[tier]
	elif species == "ghost":
		_pal = GHOST_PALS[tier]
	elif FIXED.has(species):
		_pal = FIXED[species]
	else:
		_pal = EnemyArtScript.PALETTES[tier]


func blood_color() -> Color:
	return _pal["blood"]


func eye_color() -> Color:
	return _pal["eye"]


func _ready() -> void:
	_angle = aim_angle
	if _pal.is_empty():
		setup(tier)


func _process(delta: float) -> void:
	_time += delta
	_walk += delta * 10.0
	pulse = maxf(pulse - delta * 6.0, 0.0)
	_angle = lerp_angle(_angle, aim_angle, minf(1.0, delta * 12.0))
	queue_redraw()


func _ellipse(center: Vector2, rx: float, ry: float, color: Color, segs: int = 16) -> void:
	var pts := PackedVector2Array()
	for i in segs:
		var a: float = TAU * float(i) / float(segs)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)


func _is_flyer() -> bool:
	return species == "bat" or species == "wasp" or species == "vulture" or species == "wraith" or species == "ghost"


func _draw() -> void:
	if _pal.is_empty():
		return
	var fly: bool = _is_flyer()
	var lift: float = 0.0
	if fly:
		lift = -9.0 + sin(_time * 4.0) * 3.0
	draw_set_transform(Vector2(2.0, 13.0), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 15.0 if fly else 21.0, Color(0, 0, 0, 0.17 if fly else 0.24))
	var squash := Vector2(1.0 + pulse * 0.3, 1.0 - pulse * 0.25)
	draw_set_transform(Vector2(0.0, lift), _angle, squash)
	match species:
		"bat":
			_draw_bat()
		"wasp":
			_draw_wasp()
		"vulture":
			_draw_vulture()
		"spider":
			_draw_spider()
		"scorpion":
			_draw_scorpion()
		"golem":
			_draw_golem()
		"wraith":
			_draw_wraith()
		"skeleton":
			_draw_skeleton()
		"ghost":
			_draw_ghost()
		"hound":
			_draw_hound()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_bat() -> void:
	var skin: Color = _pal["skin"]
	var dark: Color = _pal["dark"]
	var acc: Color = _pal["accent"]
	var flap: float = sin(_time * 17.0)
	var span: float = 21.0 + flap * 9.0
	for s in [-1.0, 1.0]:
		var sy: float = float(s)
		draw_colored_polygon(PackedVector2Array([Vector2(3, 3 * sy), Vector2(-1, span * sy), Vector2(-8, span * 0.78 * sy),
				Vector2(-11, span * 0.46 * sy), Vector2(-15, span * 0.6 * sy), Vector2(-15, 5 * sy)]), dark)
		draw_colored_polygon(PackedVector2Array([Vector2(1, 4 * sy), Vector2(-3, span * 0.8 * sy), Vector2(-9, span * 0.55 * sy), Vector2(-11, 5 * sy)]), skin)
		draw_line(Vector2(1, 3 * sy), Vector2(-5, span * 0.92 * sy), acc, 1.4)
	_ellipse(Vector2.ZERO, 8.5, 6.5, skin)
	draw_circle(Vector2(7, 0), 5.4, skin)
	draw_colored_polygon(PackedVector2Array([Vector2(5, -3), Vector2(3, -9), Vector2(8, -4)]), dark)
	draw_colored_polygon(PackedVector2Array([Vector2(5, 3), Vector2(3, 9), Vector2(8, 4)]), dark)
	draw_circle(Vector2(10, -2), 1.4, _pal["eye"])
	draw_circle(Vector2(10, 2), 1.4, _pal["eye"])
	draw_line(Vector2(11.5, -0.8), Vector2(12.5, -1.5), Color(1, 1, 1, 0.8), 1.0)


func _draw_wasp() -> void:
	var skin: Color = _pal["skin"]
	var dark: Color = _pal["dark"]
	var wing: Color = _pal["accent"]
	var flap: float = 0.5 + 0.5 * sin(_time * 40.0)
	for s in [-1.0, 1.0]:
		var sy: float = float(s)
		_ellipse(Vector2(-3, sy * (9.0 + flap * 3.0)), 10.0, 3.4 + flap * 1.5, Color(wing.r, wing.g, wing.b, 0.38))
		_ellipse(Vector2(-7, sy * (7.0 + flap * 2.0)), 7.0, 2.6, Color(wing.r, wing.g, wing.b, 0.3))
	_ellipse(Vector2(-13, 0), 10.0, 6.5, skin)
	for k in 3:
		var x: float = -9.0 - float(k) * 5.0
		draw_line(Vector2(x, -5.5), Vector2(x, 5.5), dark, 2.6)
	draw_colored_polygon(PackedVector2Array([Vector2(-22, -2), Vector2(-29, 0), Vector2(-22, 2)]), dark)
	_ellipse(Vector2(-1, 0), 6.5, 5.5, dark)
	draw_circle(Vector2(8, 0), 4.8, skin)
	draw_circle(Vector2(10, -2.6), 1.9, _pal["eye"])
	draw_circle(Vector2(10, 2.6), 1.9, _pal["eye"])
	draw_line(Vector2(12, -1), Vector2(18, -4), dark, 1.2)
	draw_line(Vector2(12, 1), Vector2(18, 4), dark, 1.2)


func _draw_vulture() -> void:
	var skin: Color = _pal["skin"]
	var dark: Color = _pal["dark"]
	var bare: Color = _pal["accent"]
	var flap: float = sin(_time * 8.0)
	var span: float = 30.0 + flap * 8.0
	for s in [-1.0, 1.0]:
		var sy: float = float(s)
		draw_colored_polygon(PackedVector2Array([Vector2(4, 5 * sy), Vector2(0, span * sy), Vector2(-9, span * 0.92 * sy),
				Vector2(-17, span * 0.6 * sy), Vector2(-19, 6 * sy)]), dark)
		for k in 4:
			var f: float = float(k) / 3.0
			draw_line(Vector2(0.0 - 4.0 * f, (8.0 + (span - 8.0) * f) * sy), Vector2(-14.0 - 2.0 * f, (7.0 + (span * 0.7) * f) * sy), skin, 2.0)
	_ellipse(Vector2.ZERO, 11.0, 8.0, skin)
	_ellipse(Vector2(-6, 0), 8.0, 5.5, dark)
	draw_line(Vector2(8, 0), Vector2(13, 0), bare, 4.0)
	draw_circle(Vector2(15, 0), 4.2, bare)
	draw_colored_polygon(PackedVector2Array([Vector2(18, -2), Vector2(24, 1), Vector2(18, 2.5)]), Color(0.95, 0.8, 0.3))
	draw_circle(Vector2(15.5, -2.2), 1.2, _pal["eye"])
	draw_circle(Vector2(15.5, 2.2), 1.2, _pal["eye"])


func _draw_hound() -> void:
	var skin: Color = _pal["skin"]
	var dark: Color = _pal["dark"]
	var acc: Color = _pal["accent"]
	# tail, wagging
	draw_line(Vector2(-13, 0), Vector2(-21, -5 + sin(_time * 7.0) * 3.0), dark, 2.5)
	# legs, trotting
	for i in 4:
		var lx: float = -7.0 if i < 2 else 6.0
		var sy: float = -1.0 if i % 2 == 0 else 1.0
		var sw: float = sin(_walk * 2.2 + float(i) * PI * 0.5) * 3.5
		draw_line(Vector2(lx, sy * 4.5), Vector2(lx + sw, sy * 11.0 + 3.0), dark, 3.0)
	# body and head
	_ellipse(Vector2(-2, 0), 12.0, 6.8, dark)
	_ellipse(Vector2(-2, 0), 10.5, 5.6, skin)
	_ellipse(Vector2(10, -1), 6.0, 5.0, dark)
	_ellipse(Vector2(10.5, -1), 5.2, 4.2, skin)
	# ear, snout, nose, eye
	draw_colored_polygon(PackedVector2Array([Vector2(6, -4), Vector2(8, -12), Vector2(11, -4)]), dark)
	draw_line(Vector2(14, -1), Vector2(20, 0), dark, 3.0)
	draw_circle(Vector2(20.5, 0), 1.3, dark)
	draw_circle(Vector2(12.5, -2.4), 1.4, _pal["eye"])
	draw_line(Vector2(8, 4), Vector2(12, 4), acc, 1.0)


func _draw_spider() -> void:
	var skin: Color = _pal["skin"]
	var dark: Color = _pal["dark"]
	var acc: Color = _pal["accent"]
	for s in [-1.0, 1.0]:
		var sy: float = float(s)
		for i in 4:
			var ph: float = _walk * 1.1 + float(i) * 1.6 + (PI if sy > 0.0 else 0.0)
			var base := Vector2(7.0 - float(i) * 4.5, 3.0 * sy)
			var tip := Vector2(11.0 - float(i) * 8.5 + sin(ph) * 3.5, sy * (24.0 + cos(ph) * 2.0))
			var mid := Vector2(base.x + (tip.x - base.x) * 0.35 + 3.0, sy * 17.0)
			draw_polyline(PackedVector2Array([base, mid, tip]), dark, 2.6)
			draw_polyline(PackedVector2Array([base, mid, tip]), skin, 1.2)
	_ellipse(Vector2(-10, 0), 11.5, 9.0, dark)
	_ellipse(Vector2(-10, 0), 9.5, 7.2, skin)
	_ellipse(Vector2(-10, 0), 4.0, 3.0, acc)
	_ellipse(Vector2(4, 0), 7.5, 6.0, dark)
	_ellipse(Vector2(4.5, 0), 6.0, 4.6, skin)
	for p in [Vector2(9, -2.4), Vector2(9, 2.4), Vector2(10.5, -0.9), Vector2(10.5, 0.9)]:
		draw_circle(p, 1.2, _pal["eye"])
	draw_line(Vector2(11, -3), Vector2(15, -5), dark, 2.0)
	draw_line(Vector2(11, 3), Vector2(15, 5), dark, 2.0)


func _draw_scorpion() -> void:
	var skin: Color = _pal["skin"]
	var dark: Color = _pal["dark"]
	var acc: Color = _pal["accent"]
	for s in [-1.0, 1.0]:
		var sy: float = float(s)
		for i in 4:
			var sw: float = sin(_walk + float(i) * 1.4 + (PI if sy > 0.0 else 0.0)) * 3.0
			draw_line(Vector2(6.0 - float(i) * 5.0, 5.0 * sy), Vector2(8.0 - float(i) * 6.0 + sw, 17.0 * sy), dark, 2.2)
		var claw_base := Vector2(10, 7.0 * sy)
		var claw_tip := Vector2(24, 12.0 * sy + sin(_time * 3.0 + sy) * 2.0)
		draw_line(claw_base, claw_tip, dark, 4.6)
		draw_line(claw_base, claw_tip, skin, 2.6)
		draw_colored_polygon(PackedVector2Array([claw_tip + Vector2(-3, -3), claw_tip + Vector2(8, -1.0 * sy), claw_tip + Vector2(-3, 3)]), dark)
		draw_colored_polygon(PackedVector2Array([claw_tip + Vector2(-2, -2), claw_tip + Vector2(6, 0), claw_tip + Vector2(-2, 2)]), skin)
	_ellipse(Vector2(-19, 0), 5.0, 4.0, skin)
	_ellipse(Vector2(-13, 0), 6.5, 5.0, dark)
	_ellipse(Vector2(-13, 0), 5.5, 4.2, skin)
	_ellipse(Vector2(-6, 0), 8.0, 6.0, dark)
	_ellipse(Vector2(-6, 0), 6.8, 5.0, skin)
	_ellipse(Vector2(4, 0), 10.0, 8.0, dark)
	_ellipse(Vector2(4.5, 0), 8.6, 6.8, skin)
	_ellipse(Vector2(2, -1), 4.0, 2.6, acc)
	var prev := Vector2(-22, 0)
	for k in 8:
		var t: float = float(k + 1) / 8.0
		var pos := Vector2(-22.0 + t * 38.0, -sin(t * PI) * 13.0 + sin(_time * 3.0) * 2.0 * t)
		draw_line(prev, pos, dark, 5.0 - t * 2.0)
		draw_line(prev, pos, skin, 3.0 - t * 1.2)
		prev = pos
	draw_colored_polygon(PackedVector2Array([prev + Vector2(-2, -3), prev + Vector2(8, 1), prev + Vector2(-2, 3)]), Color(0.9, 0.25, 0.2))
	draw_circle(Vector2(11, -3), 1.3, _pal["eye"])
	draw_circle(Vector2(11, 3), 1.3, _pal["eye"])


func _draw_golem() -> void:
	var skin: Color = _pal["skin"]
	var dark: Color = _pal["dark"]
	var acc: Color = _pal["accent"]
	var step: float = sin(_walk * 0.6) * 4.0
	draw_rect(Rect2(-11.0 + step, -13.0, 13.0, 9.0), dark)
	draw_rect(Rect2(-11.0 - step, 4.0, 13.0, 9.0), dark)
	var reach: float = pulse * 8.0
	draw_rect(Rect2(-8.0, -26.0, 20.0 + reach, 11.0), dark)
	draw_rect(Rect2(-6.0, -24.0, 17.0 + reach, 8.0), skin)
	draw_rect(Rect2(-8.0, 15.0, 20.0 + reach, 11.0), dark)
	draw_rect(Rect2(-6.0, 17.0, 17.0 + reach, 8.0), skin)
	draw_circle(Vector2(14.0 + reach, -20.0), 7.5, dark)
	draw_circle(Vector2(14.0 + reach, -20.0), 6.0, skin)
	draw_circle(Vector2(14.0 + reach, 21.0), 7.5, dark)
	draw_circle(Vector2(14.0 + reach, 21.0), 6.0, skin)
	draw_rect(Rect2(-14.0, -16.0, 28.0, 32.0), dark)
	draw_rect(Rect2(-11.0, -13.0, 22.0, 26.0), skin)
	draw_rect(Rect2(-6.0, -9.0, 8.0, 18.0), Color(skin.r * 1.15, skin.g * 1.15, skin.b * 1.15))
	draw_line(Vector2(-9, -8), Vector2(-2, -1), acc, 2.0)
	draw_line(Vector2(-2, -1), Vector2(-8, 7), acc, 2.0)
	draw_line(Vector2(6, -10), Vector2(9, -2), acc, 1.6)
	draw_rect(Rect2(5.0, -7.0, 11.0, 14.0), dark)
	draw_rect(Rect2(6.5, -5.5, 8.0, 11.0), skin)
	draw_rect(Rect2(12.0, -3.0, 3.5, 6.0), _pal["eye"])


## Skeleton: walks on bone legs, ribcage and spine, arms reaching forward, glowing eyes in the skull.
func _draw_skeleton() -> void:
	var bone: Color = _pal["skin"]
	var dark: Color = _pal["dark"]
	var eye: Color = _pal["eye"]
	var s: float = sin(_walk)
	# legs
	for side in [-1.0, 1.0]:
		var sd: float = side
		var step: float = s * 6.5 * sd
		var hip := Vector2(-3.0, 4.0 * sd)
		var knee := Vector2(step * 0.6, 7.0 * sd)
		var foot := Vector2(step * 1.5, 10.5 * sd)
		draw_line(hip, knee, dark, 5.2)
		draw_line(knee, foot, dark, 5.2)
		draw_line(hip, knee, bone, 3.0)
		draw_line(knee, foot, bone, 3.0)
		draw_circle(knee, 2.3, bone)
		draw_circle(foot, 2.8, bone)
	# ribcage + spine
	_ellipse(Vector2.ZERO, 12.5, 13.5, dark)
	_ellipse(Vector2.ZERO, 10.8, 11.8, Color(dark.r * 0.55, dark.g * 0.55, dark.b * 0.55))
	for i in 5:
		var x: float = -7.0 + float(i) * 3.6
		var w: float = 11.0 - absf(float(i) - 2.0) * 1.6
		draw_line(Vector2(x, -w), Vector2(x + 1.2, w), dark, 3.6)
		draw_line(Vector2(x, -w), Vector2(x + 1.2, w), bone, 2.0)
	draw_line(Vector2(-10.0, 0.0), Vector2(10.0, 0.0), dark, 4.2)
	draw_line(Vector2(-10.0, 0.0), Vector2(10.0, 0.0), bone, 2.4)
	# arms
	for side in [-1.0, 1.0]:
		var sd2: float = side
		var shoulder := Vector2(4.0, 12.0 * sd2)
		var elbow := Vector2(13.0 + s * 3.0 * sd2, 15.5 * sd2)
		var hand := Vector2(23.0 - s * 3.0 * sd2, 9.0 * sd2)
		draw_line(shoulder, elbow, dark, 5.2)
		draw_line(elbow, hand, dark, 5.2)
		draw_line(shoulder, elbow, bone, 2.8)
		draw_line(elbow, hand, bone, 2.8)
		draw_circle(elbow, 2.3, bone)
		for f in 3:
			var fa: float = (float(f) - 1.0) * 0.42
			draw_line(hand, hand + Vector2.from_angle(fa) * 6.5, bone, 1.5)
	# skull
	var hp := Vector2(13.0, 0.0)
	draw_circle(hp, 9.6, dark)
	draw_circle(hp, 8.3, bone)
	draw_circle(hp + Vector2(-2.0, -2.5), 3.4, Color(1, 1, 1, 0.2))
	_ellipse(hp + Vector2(6.5, 0.0), 3.9, 5.0, dark)
	_ellipse(hp + Vector2(6.5, 0.0), 3.0, 4.2, bone.darkened(0.12))
	for t in 4:
		var ty: float = -3.0 + float(t) * 2.0
		draw_line(hp + Vector2(5.2, ty), hp + Vector2(8.6, ty), dark, 0.9)
	for side in [-1.0, 1.0]:
		var sd3: float = side
		var ep := hp + Vector2(3.0, 3.7 * sd3)
		draw_circle(ep, 3.1, Color(0.03, 0.02, 0.03))
		draw_circle(ep, 1.6, Color(eye.r, eye.g, eye.b, 0.95))
	draw_colored_polygon(PackedVector2Array([hp + Vector2(6.5, -1.1), hp + Vector2(6.5, 1.1), hp + Vector2(8.8, 0.0)]), Color(0.08, 0.06, 0.06))


## Ghost: a floating, see-through sheet with a wavy hem, raised arms, hollow eyes and an open mouth.
func _draw_ghost() -> void:
	var skin: Color = _pal["skin"]
	var dark: Color = _pal["dark"]
	var acc: Color = _pal["accent"]
	var eye: Color = _pal["eye"]
	var fade: float = 0.74 + sin(_time * 2.3) * 0.14
	draw_circle(Vector2(-5.0, 0.0), 24.0, Color(acc.r, acc.g, acc.b, 0.09))
	draw_circle(Vector2(0.0, 0.0), 17.0, Color(acc.r, acc.g, acc.b, 0.12))
	var pts := PackedVector2Array()
	for i in 9:
		var a: float = -PI * 0.5 + PI * float(i) / 8.0
		pts.append(Vector2(cos(a) * 12.5 + 3.0, sin(a) * 13.5))
	for i in 6:
		var f: float = float(i) / 5.0
		pts.append(Vector2(2.0 - 24.0 * f + sin(_time * 4.0 + float(i) * 1.9) * 2.0, 13.0 - 7.0 * f + sin(_time * 3.0 + float(i) * 2.3) * 2.6))
	pts.append(Vector2(-31.0 + sin(_time * 4.5) * 3.0, 0.0))
	for i in 6:
		var g: float = float(5 - i) / 5.0
		pts.append(Vector2(2.0 - 24.0 * g + sin(_time * 4.2 + float(i) * 2.1) * 2.0, -13.0 + 7.0 * g + sin(_time * 3.3 + float(i) * 1.7) * 2.6))
	draw_colored_polygon(pts, Color(dark.r, dark.g, dark.b, fade * 0.9))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(p * 0.84)
	draw_colored_polygon(inner, Color(skin.r, skin.g, skin.b, fade))
	draw_circle(Vector2(5.0, -4.0), 6.0, Color(1, 1, 1, 0.16))
	for s in [-1.0, 1.0]:
		var sy: float = float(s)
		var w: float = sin(_time * 3.4 + sy * 1.4) * 3.0
		draw_polyline(PackedVector2Array([Vector2(4.0, 11.0 * sy), Vector2(12.0, 16.0 * sy + w), Vector2(20.0, 13.0 * sy + w * 1.5)]), Color(skin.r, skin.g, skin.b, fade), 3.6)
		draw_circle(Vector2(20.0, 13.0 * sy + w * 1.5), 2.6, Color(skin.r, skin.g, skin.b, fade))
	for s in [-1.0, 1.0]:
		var sy2: float = float(s)
		_ellipse(Vector2(10.0, 4.4 * sy2), 2.9, 3.9, Color(0.02, 0.03, 0.05, 0.95))
		draw_circle(Vector2(10.8, 4.4 * sy2), 1.4, Color(eye.r, eye.g, eye.b, 1.0))
	_ellipse(Vector2(15.5, 0.0), 2.4, 3.3, Color(0.02, 0.03, 0.05, 0.9))


func _draw_wraith() -> void:
	var skin: Color = _pal["skin"]
	var dark: Color = _pal["dark"]
	var acc: Color = _pal["accent"]
	var pts := PackedVector2Array()
	pts.append(Vector2(9, -9))
	pts.append(Vector2(12, 0))
	pts.append(Vector2(9, 9))
	pts.append(Vector2(-3, 13))
	for i in 4:
		var f: float = float(i) / 3.0
		pts.append(Vector2(-12.0 - 16.0 * f + sin(_time * 5.0 + float(i)) * 3.0, 9.0 - 6.0 * f + sin(_time * 4.0 + float(i) * 1.7) * 2.5))
	pts.append(Vector2(-30.0 + sin(_time * 5.0) * 3.0, 0.0))
	for i in 4:
		var g: float = float(3 - i) / 3.0
		pts.append(Vector2(-12.0 - 16.0 * g + sin(_time * 5.5 + float(i) * 1.3) * 3.0, -9.0 + 6.0 * g + sin(_time * 4.2 + float(i)) * 2.5))
	pts.append(Vector2(-3, -13))
	draw_colored_polygon(pts, Color(dark.r, dark.g, dark.b, 0.88))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(p * 0.78)
	draw_colored_polygon(inner, Color(skin.r, skin.g, skin.b, 0.8))
	for s in [-1.0, 1.0]:
		var sy: float = float(s)
		var w: float = sin(_time * 3.0 + sy) * 3.0
		draw_polyline(PackedVector2Array([Vector2(3, 10.0 * sy), Vector2(11, 15.0 * sy + w), Vector2(17, 13.0 * sy + w * 1.4)]), Color(acc.r, acc.g, acc.b, 0.7), 2.4)
	draw_circle(Vector2(6, 0), 8.5, dark)
	draw_circle(Vector2(6, 0), 7.0, Color(skin.r * 0.7, skin.g * 0.7, skin.b * 0.7))
	_ellipse(Vector2(9.5, 0), 4.0, 5.4, Color(0.02, 0.02, 0.04))
	draw_circle(Vector2(11, -2.2), 1.5, _pal["eye"])
	draw_circle(Vector2(11, 2.2), 1.5, _pal["eye"])
