extends Control
## StoryScene.gd — plays one short animated story scene (see Story.gd). Everything is drawn from shapes:
## a parallax world (sky, moon, clouds, mountains, trees, ground, drifting particles) in the level's colours,
## the hero, Princess Zara and the enemy acting out the scene, a slow camera push-in, fade-in, vignette,
## and captions that type themselves out. Click, tap or press any key for the next caption; SKIP ends it.
## Use: var s = StorySceneScript.new(); s.setup(level_idx, scene_dict); parent.add_child(s); await s.finished

signal finished

const LevelsScript := preload("res://Levels.gd")
const SaveScript := preload("res://Save.gd")
const LINE_TIME := 3.6      # seconds each caption stays when nobody clicks
const GROUND := 470.0       # y of the ground line (design space is 1152 x 648)

var level: int = 0
var data: Dictionary = {}
var _lines: Array = []
var _chapter: String = ""
var _line: int = 0
var _line_t: float = 0.0
var _chars: float = 0.0
var _time: float = 0.0
var _done: bool = false
var _base: Transform2D = Transform2D.IDENTITY    # design space with the camera push-in
var _plain: Transform2D = Transform2D.IDENTITY   # design space without camera (captions, vignette)
var _kind: String = ""
var _dawn: float = 0.0                           # 0 = night, 1 = sunrise (final scene)
var _scroll: float = 0.0                         # how far the world has scrolled (track scenes)
var _sky_top: Color = Color(0.05, 0.05, 0.1)
var _sky_bot: Color = Color(0.2, 0.2, 0.3)
var _ground: Color = Color(0.15, 0.15, 0.2)
var _accent: Color = Color(1.0, 0.8, 0.4)


func setup(level_idx: int, scene_data: Dictionary) -> void:
	level = level_idx
	data = scene_data
	_kind = String(scene_data.get("kind", ""))
	var hn: String = SaveScript.hero_name()
	_lines = []
	for l in data["lines"]:
		_lines.append(String(l).replace("{hero}", hn))
	_chapter = String(data.get("chapter", "")).replace("{hero}", hn)
	var lv: Dictionary = LevelsScript.LEVELS[clampi(level_idx, 0, LevelsScript.LAST)]
	var amb: Color = lv["ambient"]
	var fl: Color = lv["floor"]
	_accent = lv["banner"]
	_sky_top = Color(amb.r * 0.18, amb.g * 0.18, amb.b * 0.24)
	_sky_bot = Color(fl.r * 1.6 + 0.08, fl.g * 1.6 + 0.08, fl.b * 1.6 + 0.12)
	_ground = Color(fl.r * 1.1 + 0.03, fl.g * 1.1 + 0.03, fl.b * 1.1 + 0.03)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var skip := Button.new()
	skip.text = "SKIP  >>"
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.offset_left = -130.0
	skip.offset_right = -20.0
	skip.offset_top = 20.0
	skip.offset_bottom = 60.0
	skip.pressed.connect(_finish)
	add_child(skip)


func _input(event: InputEvent) -> void:
	if _done:
		return
	var press: bool = false
	if event is InputEventKey and event.pressed and not event.echo:
		press = true
	elif event is InputEventMouseButton and event.pressed:
		press = true
	# (touch taps arrive as emulated mouse clicks, so no separate touch branch: it would double-advance)
	if press:
		_advance()


func _advance() -> void:
	if _done:
		return
	_line += 1
	_line_t = 0.0
	_chars = 0.0
	if _line >= _lines.size():
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()


func _process(delta: float) -> void:
	if _done:
		return
	_time += delta
	_line_t += delta
	_chars += delta * 36.0
	if _line_t >= LINE_TIME:
		_advance()
	queue_redraw()


## Progress through the whole scene, 0 to 1. The action follows the captions.
func _prog() -> float:
	var n: int = maxi(_lines.size(), 1)
	return (float(mini(_line, n - 1)) + clampf(_line_t / LINE_TIME, 0.0, 1.0)) / float(n)


func _sm(t: float, a: float, b: float) -> float:
	var k: float = clampf((t - a) / (b - a), 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


# ------------------------------------------------------------------ drawing
func _draw() -> void:
	var s: float = minf(size.x / 1152.0, size.y / 648.0)
	var off: Vector2 = (size - Vector2(1152.0, 648.0) * s) * 0.5
	_plain = Transform2D(0.0, Vector2(s, s), 0.0, off)
	# slow camera push-in around the middle of the picture
	var z: float = 1.0 + 0.06 * _prog() + 0.01 * sin(_time * 0.6)
	_base = _plain * Transform2D(0.0, Vector2(z, z), 0.0, Vector2(576.0, 300.0) * (1.0 - z))
	var kind: String = String(data["kind"])
	_scroll = 900.0 * _sm(_prog(), 0.0, 1.0) if kind == "track" else 0.0
	_dawn = _sm(_prog(), 0.25, 1.0) if kind == "sunrise" else 0.0
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	_world()
	_bg()
	_scene(kind, _prog())
	_particles()
	# black bars hide anything that moved outside the 16:9 picture
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_rect(Rect2(0.0, 0.0, off.x, size.y), Color.BLACK)
	draw_rect(Rect2(size.x - off.x, 0.0, off.x, size.y), Color.BLACK)
	draw_rect(Rect2(0.0, 0.0, size.x, off.y), Color.BLACK)
	draw_rect(Rect2(0.0, size.y - off.y, size.x, off.y), Color.BLACK)
	draw_set_transform_matrix(_plain)
	_vignette()
	_caption()
	var fade: float = 1.0 - clampf(_time / 0.8, 0.0, 1.0)
	if fade > 0.0:
		draw_rect(Rect2(0, 0, 1152, 648), Color(0, 0, 0, fade))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _world() -> void:
	draw_set_transform_matrix(_base)


func _vignette() -> void:
	var c0 := Color(0, 0, 0, 0.55)
	var c1 := Color(0, 0, 0, 0.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1152, 0), Vector2(1152, 150), Vector2(0, 150)]), PackedColorArray([c0, c0, c1, c1]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(170, 0), Vector2(170, 648), Vector2(0, 648)]), PackedColorArray([c0, c1, c1, c0]))
	draw_polygon(PackedVector2Array([Vector2(982, 0), Vector2(1152, 0), Vector2(1152, 648), Vector2(982, 648)]), PackedColorArray([c1, c0, c0, c1]))


func _mix(a: Color, b: Color, k: float) -> Color:
	return a.lerp(b, k)


func _bg() -> void:
	var sky_top: Color = _mix(_sky_top, Color(0.35, 0.5, 0.85), _dawn * 0.85)
	var sky_bot: Color = _mix(_sky_bot, Color(1.0, 0.72, 0.45), _dawn * 0.9)
	var mid: Color = _mix(sky_top, sky_bot, 0.55)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1152, 0), Vector2(1152, 240), Vector2(0, 240)]),
			PackedColorArray([sky_top, sky_top, mid, mid]))
	draw_polygon(PackedVector2Array([Vector2(0, 240), Vector2(1152, 240), Vector2(1152, GROUND), Vector2(0, GROUND)]),
			PackedColorArray([mid, mid, sky_bot, sky_bot]))
	for i in 60:
		var sx: float = fposmod(float(i) * 137.5, 1152.0)
		var sy: float = fposmod(float(i) * 71.3, 300.0)
		var a: float = (0.3 + 0.4 * sin(_time * 1.5 + float(i))) * (1.0 - _dawn)
		draw_circle(Vector2(sx, sy), 1.0 + float(i % 3) * 0.5, Color(1, 1, 1, clampf(a, 0.0, 0.8)))
	if _kind == "sunrise":
		var sun := Vector2(576.0, GROUND + 50.0 - 250.0 * _dawn)
		for r in 6:
			draw_circle(sun, 90.0 + float(r) * 30.0, Color(1.0, 0.85, 0.5, 0.07))
		for k in 14:
			var ra: float = TAU * float(k) / 14.0 + _time * 0.1
			draw_line(sun + Vector2.from_angle(ra) * 100.0, sun + Vector2.from_angle(ra) * 260.0, Color(1.0, 0.9, 0.6, 0.12 * _dawn), 6.0)
		draw_circle(sun, 84.0, Color(1.0, 0.93, 0.62))
	# moon with soft glow
	for r in 5:
		draw_circle(Vector2(190, 120), 46.0 + float(r) * 16.0, Color(1.0, 0.95, 0.8, 0.05))
	draw_circle(Vector2(190, 120), 46.0, Color(1.0, 0.96, 0.82))
	draw_circle(Vector2(176, 108), 9.0, Color(0.9, 0.86, 0.72))
	draw_circle(Vector2(206, 132), 6.0, Color(0.9, 0.86, 0.72))
	# drifting clouds
	for i in 5:
		var cx: float = fposmod(float(i) * 290.0 + _time * (6.0 + float(i) * 2.0) - _scroll * 0.05, 1500.0) - 170.0
		var cy: float = 90.0 + float(i % 3) * 55.0
		var cc := Color(_sky_bot.r, _sky_bot.g, _sky_bot.b, 0.22)
		draw_circle(Vector2(cx, cy), 30.0, cc)
		draw_circle(Vector2(cx + 34.0, cy - 10.0), 38.0, cc)
		draw_circle(Vector2(cx + 76.0, cy), 30.0, cc)
	# mountains: far and near layers scroll at different speeds
	_range(0.10, 150.0, 0.012, _mix(_sky_bot, _sky_top, 0.45))
	_range(0.25, 90.0, 0.018, _mix(_sky_bot, Color.BLACK, 0.55))
	# trees
	for i in 10:
		var tx: float = fposmod(float(i) * 170.0 - _scroll * 0.55, 1700.0) - 200.0
		var th: float = 90.0 + float((i * 37) % 50)
		var tc: Color = _mix(_ground, Color.BLACK, 0.65)
		draw_rect(Rect2(tx - 3.0, GROUND - 14.0, 6.0, 14.0), tc)
		for k in 3:
			var w: float = 34.0 - float(k) * 8.0
			var y0: float = GROUND - 12.0 - th * float(k) * 0.33
			draw_colored_polygon(PackedVector2Array([Vector2(tx - w, y0), Vector2(tx + w, y0), Vector2(tx, y0 - th * 0.5)]), tc)
	# ground
	draw_rect(Rect2(0, GROUND, 1152, 190), _ground)
	draw_rect(Rect2(0, GROUND, 1152, 5), _ground.lightened(0.25))
	draw_polygon(PackedVector2Array([Vector2(0, GROUND - 40.0), Vector2(1152, GROUND - 40.0), Vector2(1152, GROUND), Vector2(0, GROUND)]),
			PackedColorArray([Color(_accent, 0.0), Color(_accent, 0.0), Color(_accent, 0.16), Color(_accent, 0.16)]))
	for i in 26:
		var gx: float = fposmod(float(i) * 61.0 - _scroll, 1250.0) - 50.0
		var gy2: float = GROUND + 18.0 + float((i * 29) % 90)
		draw_line(Vector2(gx, gy2), Vector2(gx + 14.0, gy2), _ground.darkened(0.25), 2.0)
		if i % 3 == 0:
			draw_circle(Vector2(gx + 6.0, gy2 - 5.0), 3.0, _ground.lightened(0.12))
	# low fog hugging the ground
	for i in 4:
		var fx: float = fposmod(float(i) * 330.0 + _time * 14.0, 1500.0) - 200.0
		draw_circle(Vector2(fx, GROUND + 2.0), 120.0, Color(_sky_bot.r, _sky_bot.g, _sky_bot.b, 0.05))


func _range(par: float, height: float, freq: float, col: Color) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(0, GROUND))
	var x: float = 0.0
	while x <= 1200.0:
		var wx: float = x + _scroll * par
		var y: float = GROUND - height * (0.55 + 0.3 * sin(wx * freq) + 0.15 * sin(wx * freq * 2.7 + 1.0))
		pts.append(Vector2(x, y))
		x += 40.0
	pts.append(Vector2(1200, GROUND))
	draw_colored_polygon(pts, col)


## Mood particles: snow in the Frozen Keep, rising embers/motes everywhere else.
func _particles() -> void:
	_world()
	var snow: bool = level == 4
	for i in 36:
		var seed_x: float = float(i) * 97.0
		var spd: float = 14.0 + float((i * 7) % 5) * 7.0
		var px: float = fposmod(seed_x + sin(_time * 0.8 + float(i)) * 20.0 - _scroll * 0.3, 1152.0)
		var py: float
		if snow:
			py = fposmod(float(i) * 53.0 + _time * spd, GROUND + 100.0)
		else:
			py = GROUND - fposmod(float(i) * 53.0 + _time * spd, GROUND)
		var col: Color = Color(1, 1, 1, 0.65) if snow else Color(_accent.r, _accent.g, _accent.b, 0.55)
		draw_circle(Vector2(px, py), 1.4 + float(i % 3) * 0.6, col)


func _caption() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(40, 520, 1072, 100), Color(0, 0, 0, 0.74))
	draw_rect(Rect2(40, 520, 1072, 100), Color(_accent, 0.6), false, 2.0)
	draw_rect(Rect2(40, 520, 6, 100), _accent)
	var text: String = String(_lines[mini(_line, _lines.size() - 1)])
	var shown: String = text.substr(0, int(_chars))
	draw_multiline_string(font, Vector2(70, 556), shown, HORIZONTAL_ALIGNMENT_LEFT, 1000.0, 25, 2, Color(1, 0.96, 0.85))
	draw_string(font, Vector2(800, 608), "click / any key to continue", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(0.7, 0.7, 0.75))
	# progress dots
	for i in _lines.size():
		var dc: Color = _accent if i <= _line else Color(1, 1, 1, 0.25)
		draw_circle(Vector2(1070.0 - float(_lines.size() - 1 - i) * 16.0, 540.0), 4.0, dc)
	if _chapter != "" and _line == 0:
		var fade: float = clampf(_line_t / 0.8, 0.0, 1.0) * (1.0 - _sm(_line_t, 2.8, 3.6))
		draw_string(font, Vector2(2, 252), _chapter, HORIZONTAL_ALIGNMENT_CENTER, 1152.0, 42, Color(0, 0, 0, fade))
		draw_string(font, Vector2(0, 250), _chapter,HORIZONTAL_ALIGNMENT_CENTER, 1152.0, 42, Color(_accent.r, _accent.g, _accent.b, fade))
	if bool(data.get("end", false)) and _prog() > 0.9:
		draw_string(font, Vector2(0, 300), "THE END", HORIZONTAL_ALIGNMENT_CENTER, 1152.0, 80, Color(1.0, 0.9, 0.55))


# ------------------------------------------------------------------ props
## The dark fortress: towers, battlements, flickering windows, a glowing gate and a waving flag.
func _castle(x: float, y: float, sc: float, flag: Color) -> void:
	_place(x, y, 0.0, sc, 1.0)
	var dark := Color(0.06, 0.05, 0.09)
	draw_circle(Vector2(0, -120), 200.0, Color(_accent, 0.05))
	draw_rect(Rect2(-110, -170, 220, 170), dark)
	draw_rect(Rect2(-142, -230, 50, 230), dark)
	draw_rect(Rect2(92, -250, 50, 250), dark)
	draw_colored_polygon(PackedVector2Array([Vector2(-150, -230), Vector2(-84, -230), Vector2(-117, -292)]), dark)
	draw_colored_polygon(PackedVector2Array([Vector2(84, -250), Vector2(150, -250), Vector2(117, -322)]), dark)
	for i in 7:
		draw_rect(Rect2(-110.0 + float(i) * 33.0, -184, 20, 14), dark)
	# gate and windows
	draw_circle(Vector2(0, -66), 26.0, Color(1.0, 0.7, 0.3, 0.30))
	draw_rect(Rect2(-26, -66, 52, 66), Color(1.0, 0.7, 0.3, 0.30))
	var wins: Array = [Vector2(-70, -130), Vector2(-25, -130), Vector2(25, -130), Vector2(70, -130), Vector2(-117, -190), Vector2(117, -210)]
	for k in wins.size():
		var fl: float = 0.55 + 0.35 * sin(_time * 3.0 + float(k) * 1.9)
		var wp: Vector2 = wins[k]
		draw_rect(Rect2(wp.x - 7.0, wp.y - 12.0, 14.0, 24.0), Color(1.0, 0.75, 0.35, fl))
	# flag
	draw_line(Vector2(117, -322), Vector2(117, -356), Color(0.25, 0.2, 0.2), 3.0)
	var w: float = 5.0 * sin(_time * 4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(117, -356), Vector2(150, -348.0 + w), Vector2(117, -338)]), flag)


func _shadow(w: float) -> void:
	var pts := PackedVector2Array()
	for i in 18:
		var a: float = TAU * float(i) / 18.0
		pts.append(Vector2(cos(a) * w, 3.0 + sin(a) * 6.0))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.32))


## Moves the drawing origin to (x, y) with a rotation, scale and facing (+1 right, -1 left).
func _place(x: float, y: float, rot: float = 0.0, sc: float = 1.0, face: float = 1.0) -> void:
	draw_set_transform_matrix(_base * Transform2D(rot, Vector2(sc * face, sc), 0.0, Vector2(x, y)))


func _hero_at(x: float, y: float, face: float, pose: String) -> void:
	_place(x, y, 0.0, 1.0, face)
	_shadow(20.0)
	_draw_hero(pose)


func _princess_at(x: float, y: float, asleep: bool, rot: float = 0.0) -> void:
	_place(x, y, rot, 1.0, 1.0)
	if is_zero_approx(rot):
		_shadow(18.0)
	_draw_princess(asleep)


func _enemy_at(x: float, y: float, face: float, col: Color, sc: float) -> void:
	_place(x, y, 0.0, sc, face)
	_shadow(26.0)
	_draw_enemy(col, sc)


## pose: idle, walk, run, reach, kneel
func _draw_hero(pose: String) -> void:
	var moving: bool = pose == "run" or pose == "walk"
	var sw: float = 0.0
	var bob: float = 1.2 * sin(_time * 2.0)
	if moving:
		var sp: float = 12.0 if pose == "run" else 7.0
		sw = sin(_time * sp)
		bob = absf(sin(_time * sp)) * (4.0 if pose == "run" else 3.0)
	var by: float = 16.0 if pose == "kneel" else 0.0
	by -= bob
	var steel := Color(0.55, 0.65, 0.85)
	var steel_d := Color(0.40, 0.48, 0.68)
	var skin := Color(0.95, 0.78, 0.62)
	# cape streams behind him
	var flap: float = sin(_time * (9.0 if moving else 2.5))
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -76 + by), Vector2(-40 - flap * 5.0 - sw * 4.0, -44 + by), Vector2(-34 - flap * 7.0, -20 + by), Vector2(-4, -30 + by)]), Color(0.72, 0.1, 0.16))
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -76 + by), Vector2(-24, -58 + by), Vector2(-4, -30 + by)]), Color(0.52, 0.07, 0.12))
	# legs with boots
	var l1 := Vector2(-8 + sw * 11.0, 0)
	var l2 := Vector2(8 - sw * 11.0, 0)
	draw_line(Vector2(-4, -38 + by), l1 + Vector2(0, -4), Color(0.25, 0.28, 0.4), 6.0)
	draw_line(Vector2(4, -38 + by), l2 + Vector2(0, -4), Color(0.30, 0.33, 0.46), 6.0)
	draw_line(l1 + Vector2(-2, -1), l1 + Vector2(6, -1), Color(0.12, 0.1, 0.12), 5.0)
	draw_line(l2 + Vector2(-2, -1), l2 + Vector2(6, -1), Color(0.12, 0.1, 0.12), 5.0)
	# torso with shading, belt and shoulder pad
	draw_rect(Rect2(-12, -80 + by, 24, 44), steel)
	draw_rect(Rect2(2, -80 + by, 10, 44), steel_d)
	draw_rect(Rect2(-12, -48 + by, 24, 6), Color(0.9, 0.75, 0.3))
	draw_circle(Vector2(0, -78 + by), 8.0, steel_d)
	# head, helmet, plume, eye
	draw_circle(Vector2(0, -92 + by), 12.0, skin)
	draw_arc(Vector2(0, -94 + by), 13.0, PI, TAU, 10, Color(0.3, 0.33, 0.45), 6.0)
	draw_line(Vector2(-2, -106 + by), Vector2(-14 - flap * 3.0, -112 + by), Color(0.85, 0.15, 0.2), 4.0)
	draw_circle(Vector2(5, -92 + by), 1.8, Color(0.1, 0.1, 0.15))
	# arm and sword
	if pose == "reach":
		draw_line(Vector2(4, -74 + by), Vector2(34, -84 + by), steel, 6.0)
		draw_circle(Vector2(36, -84 + by), 4.0, skin)
	else:
		var hand := Vector2(16, -58 + by + sw * 2.0)
		draw_line(Vector2(4, -74 + by), hand, steel, 6.0)
		draw_line(hand, hand + Vector2(12, -28), Color(0.85, 0.9, 1.0), 3.0)
		draw_line(hand + Vector2(-4, 0), hand + Vector2(4, 0), Color(0.9, 0.75, 0.3), 3.0)
		draw_circle(hand + Vector2(12, -28), 1.8, Color(1, 1, 1, 0.5 + 0.4 * sin(_time * 4.0)))


func _draw_princess(asleep: bool) -> void:
	var sway: float = sin(_time * 2.0) * 1.5
	draw_circle(Vector2(-2, -82), 13.0, Color(0.35, 0.2, 0.12))    # hair
	draw_line(Vector2(-10, -78), Vector2(-14 + sway, -52), Color(0.35, 0.2, 0.12), 6.0)   # braid
	draw_colored_polygon(PackedVector2Array([Vector2(0, -66), Vector2(-21 + sway, 0), Vector2(21 + sway, 0)]), Color(0.95, 0.5, 0.72))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -66), Vector2(8, 0), Vector2(21 + sway, 0)]), Color(0.85, 0.4, 0.62))
	draw_rect(Rect2(-8, -74, 16, 12), Color(0.97, 0.58, 0.78))
	draw_circle(Vector2(2, -83), 10.0, Color(0.97, 0.82, 0.7))     # face
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -92), Vector2(-8, -104), Vector2(-3, -98), Vector2(2, -106), Vector2(7, -98), Vector2(12, -104), Vector2(10, -92)]), Color(1.0, 0.82, 0.3))
	draw_circle(Vector2(2, -102), 1.6, Color(1, 0.4, 0.5))
	if asleep:
		draw_line(Vector2(0, -83), Vector2(5, -83), Color(0.2, 0.1, 0.1), 1.6)
		draw_line(Vector2(7, -83), Vector2(11, -83), Color(0.2, 0.1, 0.1), 1.6)
	else:
		draw_circle(Vector2(3, -83), 1.8, Color(0.15, 0.1, 0.12))
		draw_circle(Vector2(9, -83), 1.8, Color(0.15, 0.1, 0.12))
		draw_circle(Vector2(6, -78), 1.6, Color(0.95, 0.5, 0.55, 0.7))
	draw_line(Vector2(-6, -62), Vector2(-14, -40), Color(0.97, 0.82, 0.7), 4.0)    # arms
	draw_line(Vector2(6, -62), Vector2(14, -40), Color(0.97, 0.82, 0.7), 4.0)


func _draw_enemy(col: Color, sc: float) -> void:
	var sway: float = sin(_time * 3.0) * 3.0
	draw_colored_polygon(PackedVector2Array([Vector2(-16, -70), Vector2(16, -70), Vector2(28 + sway, 0), Vector2(-28 + sway, 0)]), Color(0.08, 0.06, 0.1))
	draw_colored_polygon(PackedVector2Array([Vector2(-16, -70), Vector2(-4, -70), Vector2(-14 + sway, 0), Vector2(-28 + sway, 0)]), Color(0.13, 0.1, 0.16))
	draw_circle(Vector2(0, -84), 14.0, Color(0.08, 0.06, 0.1))
	draw_circle(Vector2(4, -84), 9.0, Color(0.01, 0.01, 0.03))
	var glow: float = 0.55 + 0.25 * sin(_time * 5.0)
	draw_circle(Vector2(2, -85), 5.0, Color(col, 0.25 * glow))
	draw_circle(Vector2(9, -85), 5.0, Color(col, 0.25 * glow))
	draw_circle(Vector2(2, -85), 2.4, col)
	draw_circle(Vector2(9, -85), 2.4, col)
	draw_line(Vector2(10, -68), Vector2(30, -56 + sway), Color(0.08, 0.06, 0.1), 7.0)       # reaching arm
	if sc > 1.4:   # big villains get horns and a dark aura
		draw_line(Vector2(-8, -94), Vector2(-16, -116), Color(0.2, 0.15, 0.2), 4.0)
		draw_line(Vector2(8, -94), Vector2(16, -116), Color(0.2, 0.15, 0.2), 4.0)
		draw_circle(Vector2(0, -60), 70.0, Color(col, 0.07))


func _heart(p: Vector2, r: float, col: Color) -> void:
	draw_circle(p + Vector2(-r * 0.5, 0.0), r * 0.6, col)
	draw_circle(p + Vector2(r * 0.5, 0.0), r * 0.6, col)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 1.05, r * 0.2), p + Vector2(r * 1.05, r * 0.2), p + Vector2(0.0, r * 1.4)]), col)


func _shard(p: Vector2, r: float, col: Color) -> void:
	draw_circle(p, r * 2.2, Color(col, 0.12))
	draw_colored_polygon(PackedVector2Array([p + Vector2(0.0, -r * 1.4), p + Vector2(r * 0.8, 0.0), p + Vector2(0.0, r * 1.4), p + Vector2(-r * 0.8, 0.0)]), col)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0.0, -r * 1.4), p + Vector2(r * 0.3, -r * 0.2), p + Vector2(-r * 0.3, 0.0)]), Color(1, 1, 1, 0.7))


# ------------------------------------------------------------------ the scenes
func _scene(kind: String, t: float) -> void:
	var gy: float = GROUND
	var vc: Color = data.get("villain", Color(0.85, 0.25, 0.25))
	match kind:
		"raid":
			# the castle with a lit window; the raider grabs the princess and runs off
			_castle(1010.0, gy, 1.0, vc)
			var carried: bool = t >= 0.5
			var ex: float = 1400.0
			var eface: float = -1.0
			if t >= 0.2 and t < 0.5:
				ex = lerpf(1300.0, 880.0, _sm(t, 0.2, 0.5))
			elif t >= 0.5:
				ex = lerpf(880.0, 1400.0, _sm(t, 0.5, 0.85))
				eface = 1.0
			if not carried:
				_princess_at(830.0, gy, false)
			var hpose: String = "idle"
			if t >= 0.9:
				hpose = "kneel"
			elif t >= 0.55:
				hpose = "run"
			_hero_at(240.0 + 240.0 * _sm(t, 0.55, 0.85), gy, 1.0, hpose)
			if t >= 0.2 and ex < 1390.0:
				_enemy_at(ex, gy, eface, vc, 1.0)
				if carried:
					_place(ex - 4.0, gy - 66.0, PI * 0.5, 0.8, eface)
					_draw_princess(false)
			_world()
			if t >= 0.5:
				draw_rect(Rect2(0, 0, 1152, 648), Color(1.0, 0.1, 0.1, 0.07 + 0.05 * sin(_time * 12.0)))
		"snatch":
			# the hero reaches the princess, but another enemy grabs her and runs away
			var carried2: bool = t >= 0.65
			var hpose2: String = "run" if t < 0.4 else "idle"
			if t >= 0.95:
				hpose2 = "kneel"
			elif t >= 0.65:
				hpose2 = "reach"
			var ex2: float = 1400.0
			var eface2: float = -1.0
			if t >= 0.5 and t < 0.65:
				ex2 = lerpf(1350.0, 760.0, _sm(t, 0.5, 0.65))
			elif t >= 0.65:
				ex2 = lerpf(760.0, 1400.0, _sm(t, 0.65, 0.95))
				eface2 = 1.0
			if not carried2:
				_princess_at(720.0, gy, false)
			_hero_at(140.0 + 420.0 * _sm(t, 0.0, 0.4), gy, 1.0, hpose2)
			if t >= 0.5 and ex2 < 1390.0:
				_enemy_at(ex2, gy, eface2, vc, 1.0)
				if carried2:
					_place(ex2 - 4.0, gy - 66.0, PI * 0.5, 0.8, eface2)
					_draw_princess(false)
			_world()
			if t >= 0.35 and t < 0.55:
				_heart(Vector2(700.0, gy - 130.0 - 40.0 * _sm(t, 0.35, 0.55)), 12.0, Color(1.0, 0.4, 0.55, 1.0 - _sm(t, 0.45, 0.55)))
			if t >= 0.65 and t < 0.74:
				draw_rect(Rect2(0, 0, 1152, 648), Color(1, 1, 1, 0.4 * (1.0 - _sm(t, 0.65, 0.74))))
		"track":
			# the world scrolls past while the hero walks; the fortress slides in from the right and grows near
			var hx: float = 330.0 + 70.0 * _sm(t, 0.0, 1.0)
			_castle(1780.0 - _scroll, gy, 1.0, vc)
			# glowing footprints trail behind him
			for i in 24:
				var fx: float = fposmod(float(i) * 56.0 - _scroll, 1344.0)
				if fx < hx - 24.0:
					var fa: float = clampf((fx / hx) * 0.7, 0.0, 0.7)
					draw_circle(Vector2(fx, gy + 14.0 + float(i % 2) * 9.0), 4.0, Color(_accent, fa))
					draw_circle(Vector2(fx, gy + 14.0 + float(i % 2) * 9.0), 8.0, Color(_accent, fa * 0.2))
			_hero_at(hx, gy, 1.0, "walk")
		"reunion":
			# the hero runs to the princess; if she is asleep he kneels and holds her
			var asleep: bool = bool(data.get("asleep", false))
			var rx: float = 160.0 + 540.0 * _sm(t, 0.0, 0.5)
			if asleep:
				_princess_at(740.0, gy - 18.0, true, PI * 0.5)
			else:
				_princess_at(780.0, gy, false)
			var rpose: String = "run" if t < 0.5 else "idle"
			if asleep and t >= 0.5:
				rpose = "kneel"
			_hero_at(rx, gy, 1.0, rpose)
			_world()
			if t > 0.5 and not asleep:
				for i in 3:
					var hk: float = fposmod(_time * 0.4 + float(i) * 0.33, 1.0)
					_heart(Vector2(756.0 + float(i) * 24.0, gy - 120.0 - 90.0 * hk), 10.0, Color(1.0, 0.45, 0.6, 1.0 - hk))
		"curse":
			# the dark king casts a beam at the princess, who falls asleep
			var ka: float = _sm(t, 0.1, 0.3)
			for i in 8:
				var mx: float = 700.0 + 300.0 * sin(_time * 0.6 + float(i) * 1.7)
				var my: float = 380.0 + 70.0 * cos(_time * 0.5 + float(i))
				draw_circle(Vector2(mx, my), 60.0, Color(vc, 0.08 * ka))
			var lie: float = _sm(t, 0.6, 0.85)
			_princess_at(700.0, gy - 18.0 * lie, lie > 0.6, PI * 0.5 * lie)
			_hero_at(470.0 + 90.0 * _sm(t, 0.5, 0.7), gy, 1.0, "kneel" if t > 0.85 else "idle")
			if ka > 0.0:
				_enemy_at(1000.0, gy, -1.0, vc, 1.7)
			_world()
			if t > 0.45 and t < 0.75:
				var a3: float = sin(_time * 14.0) * 0.5 + 0.5
				draw_line(Vector2(930.0, gy - 120.0), Vector2(700.0, gy - 70.0), Color(vc.r, vc.g, vc.b, 0.25), 18.0)
				draw_line(Vector2(930.0, gy - 120.0), Vector2(700.0, gy - 70.0), Color(vc.r, vc.g, vc.b, 0.6 + 0.3 * a3), 8.0)
				draw_line(Vector2(930.0, gy - 120.0), Vector2(700.0, gy - 70.0), Color(1, 1, 1, 0.8), 2.0)
		"shard":
			# the hero holds a glowing Moon Shard over the sleeping princess; the counter shows how many he has
			var count: int = int(data.get("shards", 0))
			_princess_at(260.0, gy - 18.0, true, PI * 0.5)
			_hero_at(640.0, gy, -1.0, "idle")
			_world()
			if count > 0:
				var gk: float = _sm(t, 0.15, 0.7)
				var sp := Vector2(610.0, gy - 120.0 - 10.0 * sin(_time * 3.0))
				for i in 3:
					var rr: float = 20.0 + 80.0 * fposmod(gk + float(i) * 0.33 + _time * 0.3, 1.0)
					draw_arc(sp, rr, 0.0, TAU, 28, Color(0.7, 0.9, 1.0, 0.5 * (1.0 - rr / 100.0)), 2.0)
				_shard(sp, 16.0, Color(0.75, 0.9, 1.0))
			for i in 4:
				var cc: Color = Color(0.75, 0.9, 1.0) if i < count else Color(0.25, 0.28, 0.35)
				_shard(Vector2(900.0 + float(i) * 44.0, 90.0), 12.0, cc)
		"steal_all":
			# a giant shadow tears the shards from the hero and carries the princess away
			var pl: float = _sm(t, 0.5, 0.8)
			var px4: float = lerpf(250.0, 930.0, _sm(t, 0.6, 0.9))
			_princess_at(px4, gy - 18.0 - 190.0 * pl, true, PI * 0.5)
			_hero_at(460.0 - 80.0 * _sm(t, 0.5, 0.6), gy, 1.0, "kneel" if t > 0.6 else "idle")
			if t > 0.15:
				_enemy_at(980.0, gy, -1.0, vc, 2.0)
			_world()
			for i in 4:
				var fk: float = _sm(t, 0.2 + float(i) * 0.05, 0.55)
				var p0 := Vector2(460.0, gy - 110.0)
				var p1 := Vector2(950.0, gy - 150.0)
				_shard(p0.lerp(p1, fk) + Vector2(0.0, -60.0 * sin(fk * PI)), 10.0, Color(0.75, 0.9, 1.0))
			if t > 0.2:
				for i in 10:
					var ang: float = _time * 2.0 + float(i) * 0.628
					draw_circle(Vector2(980.0, gy - 130.0) + Vector2.from_angle(ang) * (60.0 + 10.0 * float(i % 3)), 4.0, Color(vc, 0.5))
		"face":
			# the hero faces a huge villain; lightning flashes now and then
			_hero_at(300.0, gy, 1.0, "idle")
			_enemy_at(900.0, gy, -1.0, vc, 2.3)
			_world()
			if fposmod(_time, 3.0) < 0.12:
				draw_rect(Rect2(0, 0, 1152, 648), Color(1, 1, 1, 0.25))
		"victory":
			# the boss dissolves into sparks while the hero lowers the sword
			var fe: float = 1.0 - _sm(t, 0.2, 0.75)
			_hero_at(380.0, gy, 1.0, "idle")
			if fe > 0.02:
				_enemy_at(760.0, gy + 20.0 * (1.0 - fe), -1.0, vc, 1.5 * fe + 0.05)
			_world()
			for i in 18:
				var ang: float = TAU * float(i) / 18.0 + float(i) * 0.37
				var rr3: float = 140.0 * _sm(t, 0.2, 1.0) * (0.4 + float(i % 4) * 0.2)
				var sp3: Vector2 = Vector2(760.0, gy - 70.0) + Vector2.from_angle(ang) * rr3 + Vector2(0.0, -40.0 * _sm(t, 0.2, 1.0))
				draw_circle(sp3, 2.6, Color(vc.r, vc.g, vc.b, clampf(1.0 - _sm(t, 0.5, 1.0), 0.0, 1.0)))
			var gl: float = 0.5 + 0.5 * sin(_time * 6.0)
			draw_circle(Vector2(404.0, gy - 108.0), 3.0 + gl * 2.0, Color(1, 1, 1, 0.8))
		"vision":
			# the Princess appears in a glowing bubble, far away; the hero listens
			var va: float = _sm(t, 0.1, 0.4)
			var bc := Vector2(820.0, 190.0)
			for i in 4:
				draw_circle(bc, 100.0 + float(i) * 22.0, Color(1.0, 0.8, 0.9, 0.05 * va))
			draw_circle(bc, 100.0, Color(0.07, 0.05, 0.13, 0.9 * va))
			draw_arc(bc, 100.0, 0.0, TAU, 44, Color(1.0, 0.85, 0.5, 0.9 * va), 3.0)
			draw_line(Vector2(330.0, gy - 120.0), bc + Vector2(-90.0, 30.0), Color(1.0, 0.85, 0.5, 0.25 * va), 4.0)
			_hero_at(300.0, gy, 1.0, "idle")
			_world()
			_shard(Vector2(344.0, gy - 112.0 - 6.0 * sin(_time * 3.0)), 12.0, Color(1.0, 0.9, 0.55))
			if va > 0.05:
				_place(bc.x, bc.y + 52.0, 0.0, 0.85, 1.0)
				_draw_princess(false)
				_world()
				for i in 3:
					var hv: float = fposmod(_time * 0.3 + float(i) * 0.33, 1.0)
					_heart(bc + Vector2(-40.0 + float(i) * 40.0, -30.0 - 50.0 * hv), 7.0, Color(1.0, 0.5, 0.65, (1.0 - hv) * va))
		"shardget":
			# the hero raises a freshly won Dawn Shard; the counter shows how many of the 8 are found
			var have: int = int(data.get("shards", 1))
			var ga2: float = _sm(t, 0.1, 0.6)
			var sp4 := Vector2(520.0, gy - 160.0 - 10.0 * sin(_time * 3.0) - 20.0 * ga2)
			_hero_at(430.0, gy, 1.0, "reach")
			_world()
			for i in 3:
				var rr4: float = 20.0 + 120.0 * fposmod(ga2 * 0.5 + float(i) * 0.33 + _time * 0.35, 1.0)
				draw_arc(sp4, rr4, 0.0, TAU, 32, Color(1.0, 0.9, 0.55, 0.5 * (1.0 - rr4 / 140.0)), 2.0)
			_shard(sp4, 18.0, Color(1.0, 0.92, 0.6))
			for i in 8:
				var lit: bool = i < have
				var pulse: float = 1.0 + (0.25 * sin(_time * 6.0) if i == have - 1 else 0.0)
				_shard(Vector2(770.0 + float(i) * 44.0, 90.0), 11.0 * pulse, Color(1.0, 0.9, 0.55) if lit else Color(0.25, 0.27, 0.35))
			if t < 0.15:
				draw_rect(Rect2(0, 0, 1152, 648), Color(1, 1, 1, 0.5 * (1.0 - t / 0.15)))
		"sunrise":
			# the Dawn Crystal is whole, the Princess is free, and the sun rises over the Citadel
			_princess_at(690.0, gy, false)
			_hero_at(470.0, gy, 1.0, "idle")
			_world()
			var crystal := Vector2(576.0, gy - 190.0 - 8.0 * sin(_time * 2.0))
			for i in 4:
				draw_circle(crystal, 26.0 + float(i) * 18.0 * _dawn, Color(1.0, 0.9, 0.6, 0.10))
			_shard(crystal, 22.0, Color(1.0, 0.95, 0.7))
			for i in 5:
				var hk3: float = fposmod(_time * 0.35 + float(i) * 0.2, 1.0)
				_heart(Vector2(600.0 + float(i) * 30.0, gy - 140.0 - 100.0 * hk3), 10.0, Color(1.0, 0.45, 0.6, (1.0 - hk3) * _dawn))
		"bell":
			# the Great Bell rings, golden light spreads, and the princess wakes up
			var wake: float = _sm(t, 0.6, 0.85)
			var glow: float = _sm(t, 0.45, 0.9)
			draw_circle(Vector2(576.0, gy - 120.0), 100.0 + 380.0 * glow, Color(1.0, 0.85, 0.4, 0.10 * glow + 0.05))
			var swing: float = sin(_time * 3.0) * 0.18 * _sm(t, 0.35, 0.6)
			draw_set_transform_matrix(_base * Transform2D(swing, Vector2.ONE, 0.0, Vector2(576.0, 70.0)))
			draw_line(Vector2.ZERO, Vector2(0, 40), Color(0.35, 0.25, 0.15), 4.0)
			draw_circle(Vector2(0, 80), 44.0, Color(1.0, 0.78, 0.3))
			draw_rect(Rect2(-48, 80, 96, 40), Color(1.0, 0.78, 0.3))
			draw_rect(Rect2(-56, 116, 112, 10), Color(0.8, 0.6, 0.2))
			draw_circle(Vector2(0, 134), 9.0, Color(0.35, 0.22, 0.1))
			_world()
			if t > 0.55:
				for i in 3:
					var rr2: float = fposmod(_time * 0.8 + float(i) * 0.33, 1.0)
					draw_arc(Vector2(576.0, 200.0), 60.0 + 360.0 * rr2, 0.0, TAU, 40, Color(1.0, 0.85, 0.4, 0.5 * (1.0 - rr2)), 3.0)
			_princess_at(576.0, gy - 18.0 * (1.0 - wake), wake < 0.6, PI * 0.5 * (1.0 - wake))
			_hero_at(450.0, gy, 1.0, "kneel" if wake < 0.9 else "idle")
			_world()
			if wake > 0.8:
				for i in 4:
					var hk2: float = fposmod(_time * 0.4 + float(i) * 0.25, 1.0)
					_heart(Vector2(520.0 + float(i) * 34.0, gy - 130.0 - 90.0 * hk2), 11.0, Color(1.0, 0.45, 0.6, 1.0 - hk2))
