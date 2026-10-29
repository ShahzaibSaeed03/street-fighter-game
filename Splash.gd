extends Control
## Splash.gd - the intro: studio card -> the crest slams in -> title letters rise -> loading bar
## -> "TAP TO START" -> fade into the menu. Tap anywhere to skip ahead once the menu is loaded.
## Everything is drawn in code. The menu is loaded in the background while the splash plays.

const MENU := "res://Menu.tscn"
const TITLE := "DUNGEON SNEAK"
const TIPS: Array[String] = [
	"Stab a guard from behind for a silent kill.",
	"Hold still in the shadows - guards hear footsteps.",
	"Use the roll to slip past a guard's attack.",
	"Throw a decoy to lure guards away from the door.",
	"Aim the bow with the right stick - it locks onto enemies for you.",
	"Ghosts float through props. Skeletons shoot from far away.",
]

var _t: float = 0.0
var _embers: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _flash: float = 0.0
var _shake: float = 0.0
var _slammed: bool = false
var _progress: float = 0.0
var _loaded: bool = false
var _want_go: bool = false
var _ready_time: float = -1.0
var _leaving: bool = false
var _leave_t: float = 0.0
var _tip: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_tip = randi() % TIPS.size()
	ResourceLoader.load_threaded_request(MENU)
	var vs: Vector2 = get_viewport_rect().size
	for i in 70:
		_embers.append({"p": Vector2(randf() * vs.x, randf() * vs.y), "v": Vector2(randf_range(-8.0, 8.0), randf_range(-60.0, -14.0)),
				"r": randf_range(1.2, 3.6), "ph": randf() * TAU})


func _gui_input(ev: InputEvent) -> void:
	var pressed: bool = (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed)
	if pressed and _t > 0.8:
		_want_go = true
		accept_event()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and _t > 0.8:
		_want_go = true


func _process(delta: float) -> void:
	_t += delta
	var vs: Vector2 = size
	for e in _embers:
		var p: Vector2 = e["p"]
		p += (e["v"] as Vector2) * delta + Vector2(sin(_t * 1.5 + float(e["ph"])) * 10.0 * delta, 0.0)
		if p.y < -10.0:
			p = Vector2(randf() * vs.x, vs.y + 10.0)
		e["p"] = p
	for sp in _sparks:
		sp["p"] = (sp["p"] as Vector2) + (sp["v"] as Vector2) * delta
		sp["v"] = (sp["v"] as Vector2) * (1.0 - delta * 2.2) + Vector2(0, 260.0) * delta
		sp["life"] = float(sp["life"]) - delta
	_sparks = _sparks.filter(func(s: Dictionary) -> bool: return float(s["life"]) > 0.0)
	_flash = maxf(_flash - delta * 2.6, 0.0)
	_shake = maxf(_shake - delta * 14.0, 0.0)

	if not _slammed and _t >= 1.55:
		_slammed = true
		_flash = 0.9
		_shake = 9.0
		Audio.play("gate", -2.0, 0.02)
		Audio.play("swing", -2.0, 0.02)
		var c := Vector2(vs.x * 0.5, vs.y * 0.36)
		for i in 46:
			var a: float = randf() * TAU
			var sp: float = randf_range(140.0, 520.0)
			_sparks.append({"p": c, "v": Vector2.from_angle(a) * sp, "life": randf_range(0.45, 1.0), "w": randf_range(1.5, 3.2)})

	# real loading progress, paced so the bar always takes a moment to fill
	var info: Array = []
	var status: int = ResourceLoader.load_threaded_get_status(MENU, info)
	var real: float = float(info[0]) if info.size() > 0 else 0.0
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		real = 1.0
		_loaded = true
	var pace: float = clampf((_t - 2.3) / 2.0, 0.0, 1.0)
	_progress = move_toward(_progress, minf(real, pace), delta * 0.7)
	if _progress >= 0.999 and _ready_time < 0.0:
		_ready_time = _t
	if _t > 2.3 and fmod(_t, 2.6) < delta:
		_tip = (_tip + 1) % TIPS.size()

	var go: bool = _ready_time >= 0.0 and _loaded and (_want_go or _t - _ready_time > 2.4)
	if go and not _leaving:
		_leaving = true
		_leave_t = 0.0
		Audio.play("click", -2.0)
	if _leaving:
		_leave_t += delta
		if _leave_t >= 0.45:
			var scene := ResourceLoader.load_threaded_get(MENU) as PackedScene
			get_tree().change_scene_to_packed(scene)
			set_process(false)
	queue_redraw()


func _ease_out_back(x: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


func _draw() -> void:
	var vs: Vector2 = size
	var top := Color(0.02, 0.02, 0.05)
	var bot := Color(0.17, 0.07, 0.05)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(vs.x, 0), vs, Vector2(0, vs.y)]), PackedColorArray([top, top, bot, bot]))
	var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	draw_set_transform(off, 0.0, Vector2.ONE)
	for e in _embers:
		var a: float = 0.22 + 0.22 * sin(_t * 2.0 + float(e["ph"]))
		draw_circle(e["p"], float(e["r"]), Color(1.0, 0.55, 0.2, a))

	var font: Font = ThemeDB.fallback_font
	var mid: float = vs.x * 0.5

	# 1) studio card
	var card_a: float = clampf((_t - 0.3) / 0.5, 0.0, 1.0) * (1.0 - clampf((_t - 1.25) / 0.3, 0.0, 1.0))
	if card_a > 0.0:
		var s1 := "CODEX THRILL"
		var w1: float = font.get_string_size(s1, HORIZONTAL_ALIGNMENT_LEFT, -1, 52).x
		draw_string_outline(font, Vector2(mid - w1 * 0.5, vs.y * 0.5), s1, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, 8, Color(0, 0, 0, card_a))
		draw_string(font, Vector2(mid - w1 * 0.5, vs.y * 0.5), s1, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, Color(1.0, 0.92, 0.7, card_a))
		var s2 := "P R E S E N T S"
		var w2: float = font.get_string_size(s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(font, Vector2(mid - w2 * 0.5, vs.y * 0.5 + 40.0), s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.8, 0.8, 0.9, card_a * 0.85))
		draw_rect(Rect2(mid - 90.0, vs.y * 0.5 + 56.0, 180.0 * card_a, 2.0), Color(0.96, 0.76, 0.3, card_a))

	# 2) the crest slams in
	if _t >= 1.55:
		var k: float = clampf((_t - 1.55) / 0.5, 0.0, 1.0)
		var sc: float = 1.25 * lerpf(2.6, 1.0, _ease_out_back(k)) * (vs.y / 648.0 if vs.y > 0.0 else 1.0)
		sc = clampf(sc, 0.7, 3.4)
		var lift: float = clampf((_t - 2.1) / 0.5, 0.0, 1.0)
		var cy: float = lerpf(vs.y * 0.44, vs.y * 0.33, lift)
		Emblem.draw(self, Vector2(mid, cy), sc, _t, k)
		for sp in _sparks:
			var l: float = clampf(float(sp["life"]), 0.0, 1.0)
			var v: Vector2 = sp["v"]
			draw_line(sp["p"], (sp["p"] as Vector2) - v.normalized() * (6.0 + 10.0 * l), Color(1.0, 0.8, 0.35, l), float(sp["w"]))

	# 3) title letters rise one by one, then a light sweeps across
	if _t >= 2.1:
		var fs: int = int(clampf(vs.y * 0.125, 56.0, 110.0))
		var total: float = font.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + float(TITLE.length() - 1) * 4.0
		var x: float = mid - total * 0.5
		var base_y: float = vs.y * 0.62
		for i in TITLE.length():
			var ch: String = TITLE.substr(i, 1)
			var cw: float = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var la: float = clampf((_t - 2.1 - float(i) * 0.05) / 0.3, 0.0, 1.0)
			var rise: float = (1.0 - la) * 40.0
			var sweep: float = clampf(1.0 - absf((_t - 3.0) * 900.0 - (x - (mid - total * 0.5))) / 220.0, 0.0, 1.0)
			var col := Color(0.97, 0.78, 0.32, la).lerp(Color(1.0, 0.97, 0.85, la), sweep)
			draw_string_outline(font, Vector2(x, base_y + rise), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0.03, 0.02, 0.05, la))
			draw_string(font, Vector2(x + 3.0, base_y + rise + 4.0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.5, 0.3, 0.05, la * 0.7))
			draw_string(font, Vector2(x, base_y + rise), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
			x += cw + 4.0
		var sub_a: float = clampf((_t - 3.0) / 0.5, 0.0, 1.0)
		var sub := "S N E A K   -   S T A B   -   S H O O T   -   S U R V I V E"
		var sw: float = font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(font, Vector2(mid - sw * 0.5, base_y + 46.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.85, 0.87, 0.95, sub_a * 0.9))

	# 4) loading bar, tip, tap to start
	if _t >= 2.3:
		var bw: float = minf(560.0, vs.x * 0.5)
		var bx: float = mid - bw * 0.5
		var by: float = vs.y * 0.84
		var a2: float = clampf((_t - 2.3) / 0.4, 0.0, 1.0)
		draw_rect(Rect2(bx - 3.0, by - 3.0, bw + 6.0, 18.0), Color(0.0, 0.0, 0.0, 0.5 * a2))
		draw_rect(Rect2(bx, by, bw, 12.0), Color(0.12, 0.1, 0.16, a2))
		draw_rect(Rect2(bx, by, bw * _progress, 12.0), Color(0.96, 0.76, 0.3, a2))
		draw_rect(Rect2(bx, by, bw * _progress, 5.0), Color(1.0, 0.92, 0.6, 0.55 * a2))
		draw_circle(Vector2(bx + bw * _progress, by + 6.0), 9.0, Color(1.0, 0.7, 0.2, 0.25 * a2))
		if _ready_time >= 0.0:
			var blink: float = 0.55 + 0.45 * sin(_t * 5.0)
			var ts := "TAP TO START"
			var tw: float = font.get_string_size(ts, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			draw_string_outline(font, Vector2(mid - tw * 0.5, by - 18.0), ts, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, Color(0, 0, 0, blink))
			draw_string(font, Vector2(mid - tw * 0.5, by - 18.0), ts, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1.0, 0.95, 0.8, blink))
		else:
			var ls := "Loading...  %d%%" % int(_progress * 100.0)
			var lw: float = font.get_string_size(ls, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			draw_string(font, Vector2(mid - lw * 0.5, by - 14.0), ls, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.85, 0.85, 0.95, a2))
		var tip: String = "TIP:  " + TIPS[_tip]
		var tpw: float = font.get_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(font, Vector2(mid - tpw * 0.5, by + 44.0), tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.7, 0.72, 0.82, a2 * 0.9))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# white flash on the slam, black fade in at the start and out at the end
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(1.0, 0.95, 0.85, _flash * 0.6))
	var black: float = 1.0 - clampf(_t / 0.5, 0.0, 1.0)
	if _leaving:
		black = maxf(black, clampf(_leave_t / 0.45, 0.0, 1.0))
	if black > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, black))
