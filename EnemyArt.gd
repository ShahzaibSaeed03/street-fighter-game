extends Node2D
## EnemyArt.gd — a hunched creature drawn from layered shapes with a lurching walk cycle,
## hit-squash, and glowing eyes (see EnemyEyes.gd). Colour palette changes every wave
## (green ghoul -> ember -> frost -> void) so each wave looks different.

const PALETTES: Array[Dictionary] = [
	{"skin": Color(0.34, 0.45, 0.31), "dark": Color(0.17, 0.25, 0.17), "accent": Color(0.78, 0.74, 0.55),
		"eye": Color(1.6, 1.5, 0.3), "blood": Color(0.35, 0.65, 0.2)},
	{"skin": Color(0.55, 0.22, 0.15), "dark": Color(0.30, 0.10, 0.08), "accent": Color(0.95, 0.55, 0.15),
		"eye": Color(2.0, 1.0, 0.2), "blood": Color(1.0, 0.45, 0.1)},
	{"skin": Color(0.36, 0.52, 0.66), "dark": Color(0.19, 0.30, 0.44), "accent": Color(0.85, 0.95, 1.0),
		"eye": Color(0.7, 1.6, 2.0), "blood": Color(0.5, 0.85, 1.0)},
	{"skin": Color(0.40, 0.22, 0.54), "dark": Color(0.20, 0.10, 0.30), "accent": Color(0.95, 0.35, 0.95),
		"eye": Color(2.0, 0.5, 1.6), "blood": Color(0.8, 0.3, 0.9)},
]

var tier: int = 0
var aim_angle: float = 0.0   # set by Enemy.gd (direction of the player)
var pulse: float = 0.0       # set to 1.0 on hit -> squash that decays

var _walk: float = randf() * TAU
var _time: float = randf() * 10.0
var _angle: float = 0.0
var _pal: Dictionary = PALETTES[0]


func setup(new_tier: int) -> void:
	tier = new_tier % PALETTES.size()
	_pal = PALETTES[tier]


func blood_color() -> Color:
	return _pal["blood"]


func eye_color() -> Color:
	return _pal["eye"]


func get_angle() -> float:
	return _angle


func _ready() -> void:
	_angle = aim_angle
	var eyes := Node2D.new()
	eyes.set_script(preload("res://EnemyEyes.gd"))
	eyes.material = preload("res://Fx.gd").glow_material()
	add_child(eyes)


func _process(delta: float) -> void:
	_time += delta
	_walk += delta * 9.0
	pulse = maxf(pulse - delta * 6.0, 0.0)
	_angle = lerp_angle(_angle, aim_angle, minf(1.0, delta * 12.0))
	queue_redraw()


func _ellipse(center: Vector2, rx: float, ry: float, color: Color, segs: int = 18) -> void:
	var pts := PackedVector2Array()
	for i in segs:
		var a: float = TAU * float(i) / float(segs)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)


func _draw() -> void:
	var skin: Color = _pal["skin"]
	var dark: Color = _pal["dark"]
	var accent: Color = _pal["accent"]

	# shadow
	draw_set_transform(Vector2(2, 11), 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, 23.0, Color(0, 0, 0, 0.22))
	draw_circle(Vector2.ZERO, 17.0, Color(0, 0, 0, 0.28))

	# body space (+x forward), hit-squash along the facing axis
	var squash := Vector2(1.0 - pulse * 0.22, 1.0 + pulse * 0.28)
	var lurch := sin(_walk) * 0.07
	draw_set_transform(Vector2.ZERO, _angle + lurch, squash)

	var s := sin(_walk)

	# legs
	_ellipse(Vector2(s * 6.0, -8.0), 5.8, 4.2, dark)
	_ellipse(Vector2(-s * 6.0, 8.0), 5.8, 4.2, dark)

	# back spikes
	for i in 4:
		var y := -9.0 + float(i) * 6.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(-9, y - 3.0), Vector2(-9, y + 3.0), Vector2(-20.0, y)]), accent)

	# arms reaching forward with claws
	for side in [-1.0, 1.0]:
		var sd: float = side
		var reach: float = 24.0 + s * 5.0 * sd
		var shoulder := Vector2(3.0, 12.0 * sd)
		var hand := Vector2(reach, 9.0 * sd)
		draw_line(shoulder, hand, dark, 6.0)
		draw_line(shoulder, hand, skin, 3.4)
		draw_circle(hand, 4.0, skin)
		for c in 3:
			var ca := (float(c) - 1.0) * 0.45
			var d := Vector2.from_angle(ca)
			var p := d.rotated(PI * 0.5)
			draw_colored_polygon(PackedVector2Array([
				hand + d * 3.0 + p * 1.4, hand + d * 11.0, hand + d * 3.0 - p * 1.4]), accent)

	# torso
	_ellipse(Vector2.ZERO, 14.5, 16.0, dark)
	_ellipse(Vector2(1.0, 0.0), 12.8, 14.2, skin)
	_ellipse(Vector2(3.0, -3.5), 6.0, 7.0, Color(1, 1, 1, 0.12))
	draw_arc(Vector2(1.0, 0.0), 8.0, -0.9, 0.9, 10, Color(dark, 0.7), 2.0)

	# head + horns + jaw
	var hp := Vector2(13.0, 0.0)
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			hp + Vector2(-1, 5.5 * side), hp + Vector2(3, 7.0 * side), hp + Vector2(5, 14.0 * side)]), accent)
	draw_circle(hp, 9.8, dark)
	draw_circle(hp, 8.6, skin)
	draw_circle(hp + Vector2(-1.5, -2.5), 4.0, Color(1, 1, 1, 0.14))
	_ellipse(hp + Vector2(5.0, 0.0), 4.2, 5.4, Color(0.05, 0.02, 0.03))
	for t in 3:
		var ty := (float(t) - 1.0) * 2.8
		draw_colored_polygon(PackedVector2Array([
			hp + Vector2(5.5, ty - 1.0), hp + Vector2(5.5, ty + 1.0), hp + Vector2(8.5, ty)]), Color(0.9, 0.9, 0.8))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
