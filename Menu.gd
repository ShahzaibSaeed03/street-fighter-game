extends Control
## Menu.gd — main menu: level select (levels unlock one by one), and the shop where you spend
## the coins you collected on swords, armor, bows and health. Everything is built in code.

const SaveScript := preload("res://Save.gd")
const LevelsScript := preload("res://Levels.gd")
const ItemsScript := preload("res://Items.gd")
const HeroArtScript := preload("res://HeroArt.gd")

var _page: String = "home"
var _home: Control
var _levels_page: Control
var _shop_page: Control
var _profile_page: Control
var _missions_page: Control
var _missions_box: VBoxContainer
const MissionsScript := preload("res://Missions.gd")
var _profile_box: VBoxContainer
var _grid: GridContainer
var _shop_list: VBoxContainer
var _shop_scroll: SmoothScroll
var _equip_label: Label
var _shop_tab: String = "sword"
var _tab_buttons: Dictionary = {}
var _coin_label: Label
var _hero: Node2D
var _stage: Control   # 1152x648 design area, centred on wide / tall screens
var _toast: Label
var _level_page: int = 0
var _page_label: Label
var _speed_btns: Array[Button] = []
const PER_PAGE := 6
var _toast_tween: Tween
var _t: float = 0.0
var _embers: Array[Dictionary] = []


# ------------------------------------------------------------------ cards (inner class)
class Card extends Control:
	signal chosen(idx: int)
	var idx: int = 0
	var info: Dictionary = {}
	var locked: bool = false
	var stars: int = 0
	var best_time: float = -1.0
	var _hover: bool = false

	func _ready() -> void:
		custom_minimum_size = Vector2(336, 196)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func() -> void: _hover = true)
		mouse_exited.connect(func() -> void: _hover = false)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			chosen.emit(idx)

	func _process(_d: float) -> void:
		queue_redraw()

	func _star(c: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 10:
			var a: float = -PI * 0.5 + TAU * float(i) / 10.0
			var rr: float = r if i % 2 == 0 else r * 0.45
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(pts, col)

	func _icon(c: Vector2) -> void:
		var col: Color = info["banner"]
		match idx:
			0:  # dungeon: torch
				draw_rect(Rect2(c + Vector2(-4, -6), Vector2(8, 34)), Color(0.35, 0.22, 0.12))
				draw_circle(c + Vector2(0, -14), 14.0, Color(1.0, 0.45, 0.1, 0.9))
				draw_circle(c + Vector2(0, -16), 8.0, Color(1.0, 0.85, 0.4))
			1:  # jungle: tree
				draw_rect(Rect2(c + Vector2(-4, 4), Vector2(8, 26)), Color(0.35, 0.22, 0.12))
				draw_circle(c + Vector2(0, -8), 24.0, Color(0.14, 0.45, 0.16))
				draw_circle(c + Vector2(-8, -14), 14.0, Color(0.3, 0.65, 0.25))
			2:  # desert: pyramid + sun
				draw_circle(c + Vector2(22, -22), 11.0, Color(1.0, 0.85, 0.4))
				draw_colored_polygon(PackedVector2Array([c + Vector2(-34, 30), c + Vector2(0, -22), c + Vector2(34, 30)]), Color(0.78, 0.6, 0.32))
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -22), c + Vector2(34, 30), c + Vector2(6, 30)]), Color(0.6, 0.44, 0.22))
			3:  # lava: flame
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -34), c + Vector2(20, 0), c + Vector2(14, 28), c + Vector2(-14, 28), c + Vector2(-20, 0)]), Color(1.0, 0.4, 0.1))
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -12), c + Vector2(10, 8), c + Vector2(6, 26), c + Vector2(-6, 26), c + Vector2(-10, 8)]), Color(1.0, 0.85, 0.35))
			4:  # ice: crystal
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -36), c + Vector2(20, -4), c + Vector2(0, 32), c + Vector2(-20, -4)]), Color(0.55, 0.82, 1.0))
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -36), c + Vector2(6, -4), c + Vector2(0, 32), c + Vector2(-20, -4)]), Color(0.85, 0.96, 1.0))
			5:  # shadow: moon
				draw_circle(c, 28.0, Color(0.75, 0.45, 1.0))
				draw_circle(c + Vector2(12, -6), 24.0, Color(0.12, 0.08, 0.2))
			6:  # bone crypt: skull
				var bone := Color(0.88, 0.86, 0.76)
				draw_circle(c + Vector2(0, -4), 22.0, bone)
				draw_rect(Rect2(c + Vector2(-12, 12), Vector2(24, 15)), bone)
				draw_circle(c + Vector2(-8, -3), 6.5, Color(0.08, 0.06, 0.06))
				draw_circle(c + Vector2(8, -3), 6.5, Color(0.08, 0.06, 0.06))
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, 4), c + Vector2(-3, 11), c + Vector2(3, 11)]), Color(0.08, 0.06, 0.06))
				for i in 4:
					draw_line(c + Vector2(-9 + i * 6, 17), c + Vector2(-9 + i * 6, 26), Color(0.3, 0.28, 0.24), 1.5)
			7:  # haunted manor: ghost
				var gc := Color(0.85, 0.95, 1.0, 0.95)
				draw_circle(c + Vector2(0, -8), 20.0, gc)
				draw_rect(Rect2(c + Vector2(-20, -8), Vector2(40, 30)), gc)
				for i in 4:
					draw_circle(c + Vector2(-15 + i * 10, 22), 5.5, gc)
				draw_circle(c + Vector2(-7, -9), 4.5, Color(0.05, 0.08, 0.15))
				draw_circle(c + Vector2(7, -9), 4.5, Color(0.05, 0.08, 0.15))
				draw_circle(c + Vector2(0, 3), 3.5, Color(0.05, 0.08, 0.15))
			8:  # sunken temple: pillars over water
				var sc := Color(0.55, 0.8, 0.75)
				draw_rect(Rect2(c + Vector2(-26, -26), Vector2(12, 40)), sc)
				draw_rect(Rect2(c + Vector2(14, -26), Vector2(12, 40)), sc)
				draw_rect(Rect2(c + Vector2(-30, -32), Vector2(60, 8)), sc.lightened(0.15))
				for i in 3:
					draw_arc(c + Vector2(-20 + i * 20, 22), 10.0, PI, TAU, 12, Color(0.3, 0.8, 0.95), 3.0)
			9:  # crimson cathedral: pointed window with a cross
				var rc := Color(0.9, 0.25, 0.3)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-18, 30), c + Vector2(-18, -6), c + Vector2(0, -34), c + Vector2(18, -6), c + Vector2(18, 30)]), rc)
				draw_line(c + Vector2(0, -22), c + Vector2(0, 26), Color(0.2, 0.05, 0.08), 4.0)
				draw_line(c + Vector2(-12, 0), c + Vector2(12, 0), Color(0.2, 0.05, 0.08), 4.0)
			10:  # storm fortress: lightning bolt
				draw_colored_polygon(PackedVector2Array([c + Vector2(6, -36), c + Vector2(-14, 4), c + Vector2(-2, 4), c + Vector2(-8, 36), c + Vector2(16, -8), c + Vector2(3, -8)]), Color(1.0, 0.92, 0.35))
			_:  # abyss throne: crown
				var kc := Color(1.0, 0.82, 0.3)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-28, 22), c + Vector2(-28, -14), c + Vector2(-14, 2), c + Vector2(0, -22), c + Vector2(14, 2), c + Vector2(28, -14), c + Vector2(28, 22)]), kc)
				draw_circle(c + Vector2(0, 8), 5.0, Color(0.7, 0.3, 1.0))
				draw_circle(c + Vector2(-16, 12), 3.0, Color(0.9, 0.2, 0.3))
				draw_circle(c + Vector2(16, 12), 3.0, Color(0.9, 0.2, 0.3))
		draw_arc(c, 42.0, 0.0, TAU, 32, Color(col, 0.35), 2.0)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var floor_c: Color = info["floor"]
		var amb: Color = info["ambient"]
		var top := Color(floor_c.r * 2.2 + 0.05, floor_c.g * 2.2 + 0.05, floor_c.b * 2.2 + 0.05)
		var bot := Color(amb.r * 0.25, amb.g * 0.25, amb.b * 0.25)
		draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
				PackedColorArray([top, top, bot, bot]))
		var edge: Color = info["banner"]
		draw_rect(r, Color(edge, 0.95 if _hover and not locked else 0.45), false, 3.0 if _hover else 2.0)
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(16, 30), "LEVEL %d" % (idx + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.9))
		draw_string(font, Vector2(16, 58), String(info["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, edge)
		_icon(Vector2(size.x - 70.0, 84.0))
		draw_multiline_string(font, Vector2(16, 90), String(info["desc"]), HORIZONTAL_ALIGNMENT_LEFT, 205.0, 14, 3, Color(0.85, 0.85, 0.9, 0.88))
		for i in 3:
			_star(Vector2(34.0 + float(i) * 34.0, 152.0), 14.0, Color(1.0, 0.82, 0.25) if i < stars else Color(0, 0, 0, 0.5))
		if best_time >= 0.0:
			draw_string(font, Vector2(150, 158), "Best  %02d:%02d" % [int(best_time) / 60, int(best_time) % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.9, 0.9, 1.0, 0.85))
		var boss_info: Dictionary = info["boss"]
		draw_string(font, Vector2(16, 184), "Boss: %s" % boss_info["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.5, 0.45, 0.9))
		if locked:
			draw_rect(r, Color(0, 0, 0, 0.72))
			var c: Vector2 = r.get_center() + Vector2(0, -10)
			draw_arc(c + Vector2(0, -6), 15.0, PI, TAU, 16, Color(0.8, 0.8, 0.85), 5.0)
			draw_rect(Rect2(c + Vector2(-20, -6), Vector2(40, 32)), Color(0.85, 0.7, 0.3))
			draw_circle(c + Vector2(0, 8), 4.5, Color(0.2, 0.15, 0.05))
			draw_string(font, Vector2(0, r.end.y - 20.0), "Clear level %d to unlock" % idx, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color(0.9, 0.9, 0.95))


## Small vector icon drawn on the left of a button.
class Glyph extends Control:
	var kind: String = ""
	var col: Color = Color.WHITE

	func _init(k: String, c: Color) -> void:
		kind = k
		col = c
		custom_minimum_size = Vector2(32, 32)
		size = Vector2(32, 32)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		match kind:
			"play":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -13), c + Vector2(13, 0), c + Vector2(-9, 13)]), col)
			"shop":
				draw_circle(c + Vector2(0, 6), 11.0, col.darkened(0.35))
				draw_circle(c + Vector2(0, -1), 11.0, col)
				draw_arc(c + Vector2(0, -1), 6.5, 0.0, TAU, 20, col.darkened(0.5), 2.0)
			"missions":
				draw_rect(Rect2(c + Vector2(-11, -13), Vector2(22, 26)), col, false, 2.6)
				for i in 3:
					draw_line(c + Vector2(-6, -6 + i * 6), c + Vector2(6, -6 + i * 6), col, 2.2)
			"profile":
				draw_circle(c + Vector2(0, -6), 6.5, col)
				draw_arc(c + Vector2(0, 15), 12.0, PI * 1.1, PI * 1.9, 16, col, 5.0)
			"quit":
				draw_arc(c, 10.0, -PI * 0.5 + 0.65, -PI * 0.5 + TAU - 0.65, 24, col, 3.0)
				draw_line(c + Vector2(0, -13), c + Vector2(0, -2), col, 3.0)
			"back":
				draw_polyline(PackedVector2Array([c + Vector2(6, -11), c + Vector2(-6, 0), c + Vector2(6, 11)]), col, 3.6)
			"next":
				draw_polyline(PackedVector2Array([c + Vector2(-6, -11), c + Vector2(6, 0), c + Vector2(-6, 11)]), col, 3.6)


## The crest above the title on the home page.
class EmblemView extends Control:
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		Emblem.draw(self, size * 0.5, minf(size.y / 140.0, 1.0), _t, 0.8)


## Touch-friendly scroller. Buttons inside it ignore the mouse; this control watches the
## finger itself, so a drag that starts on a button still scrolls and a short tap presses it.
class SmoothScroll extends Control:
	signal press_started(btn: Button)
	signal press_cancelled(btn: Button)
	signal tapped(btn: Button)
	var content: Control
	var _scroll: float = 0.0
	var _vel: float = 0.0
	var _down: bool = false
	var _dragging: bool = false
	var _press_pos: Vector2 = Vector2.ZERO
	var _last_y: float = 0.0
	var _last_ms: int = 0
	var _btn: Button = null
	var _bar_a: float = 0.0

	func _init() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP

	func set_content(c: Control) -> void:
		content = c
		add_child(c)
		c.position = Vector2.ZERO

	func reset() -> void:
		_scroll = 0.0
		_vel = 0.0

	func _max_scroll() -> float:
		if content == null:
			return 0.0
		return maxf(0.0, content.get_combined_minimum_size().y - size.y)

	func _button_at(p: Vector2) -> Button:
		var gp: Vector2 = get_global_transform() * p
		return _find(content, gp)

	func _find(n: Node, gp: Vector2) -> Button:
		for c in n.get_children():
			if c is Button:
				var b: Button = c
				if b.is_visible_in_tree() and not b.disabled and b.get_global_rect().has_point(gp):
					return b
			var r: Button = _find(c, gp)
			if r != null:
				return r
		return null

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			var mb: InputEventMouseButton = ev
			if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_scroll -= 110.0
				_bar_a = 1.0
			elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_scroll += 110.0
				_bar_a = 1.0
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_down = true
					_dragging = false
					_vel = 0.0
					_press_pos = mb.position
					_last_y = mb.position.y
					_last_ms = Time.get_ticks_msec()
					_btn = _button_at(mb.position)
					if _btn != null:
						press_started.emit(_btn)
				else:
					_down = false
					if not _dragging and _btn != null and _button_at(mb.position) == _btn:
						var b: Button = _btn
						_btn = null
						tapped.emit(b)
					elif _btn != null:
						press_cancelled.emit(_btn)
						_btn = null
					if Time.get_ticks_msec() - _last_ms > 90:
						_vel = 0.0
		elif ev is InputEventMouseMotion and _down:
			var mm: InputEventMouseMotion = ev
			var now: int = Time.get_ticks_msec()
			var dy: float = mm.position.y - _last_y
			_last_y = mm.position.y
			if not _dragging and absf(mm.position.y - _press_pos.y) > 10.0:
				_dragging = true
				if _btn != null:
					press_cancelled.emit(_btn)
					_btn = null
			if _dragging:
				_scroll -= dy
				var dt: float = maxf(float(now - _last_ms) / 1000.0, 0.001)
				_vel = lerpf(_vel, -dy / dt, 0.5)
				_last_ms = now
				_bar_a = 1.0
		accept_event()

	func _process(delta: float) -> void:
		if content == null:
			return
		if content.size.x != size.x:
			content.custom_minimum_size.x = size.x
			content.size.x = size.x
		if not _down and absf(_vel) > 8.0:
			_scroll += _vel * delta
			_vel *= exp(-4.2 * delta)
			_bar_a = 1.0
		else:
			if not _down:
				_vel = 0.0
		var mx: float = _max_scroll()
		if _scroll < 0.0 or _scroll > mx:
			_scroll = clampf(_scroll, 0.0, mx)
			_vel = 0.0
		var y: float = -roundf(_scroll)
		if content.position.y != y:
			content.position.y = y
		if _bar_a > 0.0:
			if not _down and absf(_vel) < 8.0:
				_bar_a = maxf(0.0, _bar_a - delta * 1.6)
			queue_redraw()

	func _draw() -> void:
		var mx: float = _max_scroll()
		if mx <= 0.0 or _bar_a <= 0.0:
			return
		var ch: float = content.get_combined_minimum_size().y
		var bh: float = maxf(40.0, size.y * size.y / ch)
		var by: float = (size.y - bh) * (_scroll / mx)
		draw_rect(Rect2(size.x - 7.0, by, 5.0, bh), Color(1.0, 0.82, 0.35, 0.65 * minf(_bar_a, 1.0)))


## Small red heart used by the vitality row.
class HeartIcon extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(56, 56)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var col := Color(0.92, 0.22, 0.3)
		draw_circle(c + Vector2(-9, -5), 11.0, col)
		draw_circle(c + Vector2(9, -5), 11.0, col)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-19.5, 0), c + Vector2(19.5, 0), c + Vector2(0, 22)]), col)
		draw_circle(c + Vector2(-12, -9), 3.0, Color(1, 1, 1, 0.5))


# ------------------------------------------------------------------ setup
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SaveScript.ensure()
	Engine.time_scale = 1.0
	get_tree().paused = false
	_stage = Control.new()
	_stage.size = Vector2(1152, 648)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	get_viewport().size_changed.connect(_fit_stage)
	_fit_stage()
	var vs: Vector2 = get_viewport_rect().size
	for i in 55:
		_embers.append({"p": Vector2(randf() * vs.x, randf() * vs.y), "v": Vector2(randf_range(-6.0, 6.0), randf_range(-38.0, -10.0)),
				"r": randf_range(1.2, 3.2), "ph": randf() * TAU})
	_build_home()
	_build_levels()
	_build_shop()
	_build_profile()
	_build_missions()
	_toast = _label(_stage, "", 24, Color(1.0, 0.9, 0.5))
	_toast.position = Vector2(176, 560)
	_toast.custom_minimum_size = Vector2(800, 0)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	_show("home")


func _process(delta: float) -> void:
	_t += delta
	for e in _embers:
		var p: Vector2 = e["p"]
		var v: Vector2 = e["v"]
		p += v * delta + Vector2(sin(_t + float(e["ph"])) * 6.0 * delta, 0.0)
		if p.y < -10.0:
			p = Vector2(randf() * size.x, size.y + 12.0)
		e["p"] = p
	queue_redraw()
	if _coin_label != null:
		_coin_label.text = "COINS  %d" % SaveScript.coins


func _draw() -> void:
	var top := Color(0.05, 0.05, 0.10)
	var bot := Color(0.16, 0.08, 0.06)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), size, Vector2(0, size.y)]),
			PackedColorArray([top, top, bot, bot]))
	for i in 4:
		draw_circle(Vector2(size.x * 0.5, size.y * 0.36), 150.0 + float(i) * 90.0, Color(1.0, 0.55, 0.2, 0.025))
	for e in _embers:
		var p: Vector2 = e["p"]
		var a: float = 0.25 + 0.2 * sin(_t * 2.0 + float(e["ph"]))
		draw_circle(p, float(e["r"]), Color(1.0, 0.55, 0.2, a))


func _fit_stage() -> void:
	_stage.position = ((get_viewport_rect().size - _stage.size) * 0.5).floor()


func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel") and _page != "home":
		_show("home")


func _label(parent: Node, text: String, size: int, col: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	parent.add_child(l)
	return l


func _style(bg: Color, border: Color, radius: int = 8, bw: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(10)
	if radius > 8:
		sb.shadow_color = Color(0, 0, 0, 0.5)
		sb.shadow_size = 7
		sb.shadow_offset = Vector2(0, 4)
	return sb


func _apply_btn_style(b: Button, accent: Color, fill: bool = false, left_pad: float = 0.0) -> void:
	var n: StyleBoxFlat
	var hv: StyleBoxFlat
	var pr: StyleBoxFlat
	var fc := Color(0.95, 0.92, 0.85)
	if fill:
		n = _style(Color(0.97, 0.74, 0.26), Color(1.0, 0.92, 0.55), 16, 4)
		hv = _style(Color(1.0, 0.82, 0.38), Color(1.0, 0.95, 0.65), 16, 4)
		pr = _style(Color(0.85, 0.62, 0.18), Color(1.0, 0.92, 0.55), 16, 4)
		fc = Color(0.17, 0.09, 0.02)
	else:
		n = _style(Color(0.10, 0.10, 0.16, 0.96), accent.darkened(0.25), 14, 3)
		hv = _style(Color(0.22, 0.18, 0.11, 0.98), accent, 14, 3)
		pr = _style(Color(0.34, 0.25, 0.11, 1.0), accent.lightened(0.25), 14, 3)
	var ds := _style(Color(0.07, 0.07, 0.09, 0.9), Color(0.25, 0.25, 0.3), 14, 3)
	for sb in [n, hv, pr, ds]:
		sb.content_margin_left = 10.0 + left_pad
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("disabled", ds)
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc)
	b.add_theme_color_override("font_pressed_color", fc)
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.55))


func _pop(n: Control, s: float) -> void:
	if n.has_meta("pop_tw"):
		var old: Tween = n.get_meta("pop_tw")
		if old != null and old.is_valid():
			old.kill()
	var tw := create_tween()
	n.set_meta("pop_tw", tw)
	tw.tween_property(n, "scale", Vector2(s, s), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _btn(text: String, w: float, h: float, cb: Callable, accent: Color = Color(0.95, 0.75, 0.3), font_size: int = 22, glyph: String = "", fill: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	_apply_btn_style(b, accent, fill, 44.0 if glyph != "" else 0.0)
	b.pressed.connect(cb)
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.mouse_entered.connect(func() -> void: _pop(b, 1.05))
	b.mouse_exited.connect(func() -> void: _pop(b, 1.0))
	b.button_down.connect(func() -> void:
		_pop(b, 0.94)
		Audio.play("click", -8.0))
	b.button_up.connect(func() -> void: _pop(b, 1.03 if b.is_hovered() else 1.0))
	if glyph != "":
		var g := Glyph.new(glyph, Color(0.17, 0.09, 0.02) if fill else accent.lightened(0.2))
		g.position = Vector2(18.0, (h - 32.0) * 0.5)
		b.add_child(g)
	return b


func _set_speed(i: int) -> void:
	SaveScript.speed_pref = i
	SaveScript.save()
	_refresh_speed()
	_toast_msg("Game speed: %s" % Tuning.SPEED_NAMES[i])


func _refresh_speed() -> void:
	for i in _speed_btns.size():
		_apply_btn_style(_speed_btns[i], Color(0.6, 0.85, 1.0), i == SaveScript.speed_pref)


func _toast_msg(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


func _show(page: String) -> void:
	_page = page
	_home.visible = page == "home"
	_levels_page.visible = page == "levels"
	_shop_page.visible = page == "shop"
	_hero.visible = page == "shop"
	_profile_page.visible = page == "profile"
	_missions_page.visible = page == "missions"
	if page == "levels":
		_level_page = clampi(SaveScript.unlocked / PER_PAGE, 0, _pages() - 1)
		_rebuild_levels()
	elif page == "shop":
		_refresh_shop()
		_update_hero()
	elif page == "profile":
		_refresh_profile()
	elif page == "missions":
		_refresh_missions()


# ------------------------------------------------------------------ home
func _build_home() -> void:
	_home = Control.new()
	_home.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(_home)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_home.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	var crest := EmblemView.new()
	crest.custom_minimum_size = Vector2(0, 96)
	box.add_child(crest)
	var title := _label(box, "DUNGEON SNEAK", 76, Color(0.97, 0.78, 0.32))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 12)
	var sub := _label(box, "12 levels  -  12 bosses  -  sneak, stab, shoot, survive", 21, Color(0.85, 0.85, 0.92))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	box.add_child(gap)
	var play := _btn("PLAY", 600, 96, func() -> void: _show("levels"), Color(0.97, 0.74, 0.26), 44, "play", true)
	var play_holder := CenterContainer.new()
	play_holder.add_child(play)
	box.add_child(play_holder)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	row.add_child(_btn("SHOP", 184, 78, func() -> void: _show("shop"), Color(1.0, 0.85, 0.3), 24, "shop"))
	row.add_child(_btn("MISSIONS", 204, 78, func() -> void: _show("missions"), Color(0.9, 0.6, 0.9), 22, "missions"))
	row.add_child(_btn("PROFILE", 184, 78, func() -> void: _show("profile"), Color(0.6, 0.8, 1.0), 24, "profile"))
	var spd_row := HBoxContainer.new()
	spd_row.add_theme_constant_override("separation", 10)
	spd_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(spd_row)
	_label(spd_row, "GAME SPEED", 20, Color(0.8, 0.82, 0.9))
	_speed_btns.clear()
	for i in 3:
		var sb := _btn(String(Tuning.SPEED_NAMES[i]), 124, 52, _set_speed.bind(i), Color(0.6, 0.85, 1.0), 20)
		spd_row.add_child(sb)
		_speed_btns.append(sb)
	_refresh_speed()
	if not Tuning.mobile():
		var ctl := _label(box, "WASD move  -  C sneak  -  SPACE / left click: sword  -  F / right click: bow (aim with mouse)  -  SHIFT roll  -  E decoy", 15, Color(0.7, 0.72, 0.82))
		ctl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var quit := _btn("QUIT", 150, 54, func() -> void: get_tree().quit(), Color(0.85, 0.45, 0.45), 20, "quit")
	quit.position = Vector2(24, 574)
	_home.add_child(quit)
	_coin_label = _label(_home, "COINS  0", 28, Color(1.0, 0.85, 0.3))
	_coin_label.position = Vector2(900, 24)


# ------------------------------------------------------------------ level select
func _pages() -> int:
	return int(ceil(float(LevelsScript.LEVELS.size()) / float(PER_PAGE)))


func _build_levels() -> void:
	_levels_page = Control.new()
	_levels_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(_levels_page)
	var t := _label(_levels_page, "SELECT LEVEL", 48, Color(0.95, 0.75, 0.3))
	t.position = Vector2(40, 18)
	var hint := _label(_levels_page, "Clear a level to unlock the next one. Earn coins, buy gear in the shop.", 17, Color(0.8, 0.82, 0.9))
	hint.position = Vector2(44, 82)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 22)
	_grid.add_theme_constant_override("v_separation", 20)
	_grid.position = Vector2(48, 124)
	_levels_page.add_child(_grid)
	var back := _btn("BACK", 190, 58, func() -> void: _show("home"), Color(0.75, 0.75, 0.85), 22, "back")
	back.position = Vector2(40, 576)
	_levels_page.add_child(back)
	var shop := _btn("SHOP", 170, 58, func() -> void: _show("shop"), Color(1.0, 0.85, 0.3), 22, "shop")
	shop.position = Vector2(246, 576)
	_levels_page.add_child(shop)
	var prev := _btn("PREV", 150, 58, func() -> void: _flip(-1), Color(0.6, 0.8, 1.0), 22, "back")
	prev.position = Vector2(690, 576)
	_levels_page.add_child(prev)
	_page_label = _label(_levels_page, "1 / 2", 24, Color(0.9, 0.9, 1.0))
	_page_label.position = Vector2(856, 588)
	var nxt := _btn("NEXT", 150, 58, func() -> void: _flip(1), Color(1.0, 0.85, 0.3), 22, "next")
	nxt.position = Vector2(950, 576)
	_levels_page.add_child(nxt)


func _flip(d: int) -> void:
	_level_page = clampi(_level_page + d, 0, _pages() - 1)
	_rebuild_levels()


func _rebuild_levels() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var first: int = _level_page * PER_PAGE
	var last: int = mini(first + PER_PAGE, LevelsScript.LEVELS.size())
	for i in range(first, last):
		var card := Card.new()
		card.idx = i
		card.info = LevelsScript.LEVELS[i]
		card.locked = i > SaveScript.unlocked
		var rec: Dictionary = SaveScript.best.get(str(i), {})
		card.stars = int(rec.get("stars", 0))
		card.best_time = float(rec.get("time", -1.0))
		card.chosen.connect(_on_level_chosen)
		_grid.add_child(card)
	_page_label.text = "%d / %d" % [_level_page + 1, _pages()]


func _on_level_chosen(idx: int) -> void:
	if idx > SaveScript.unlocked:
		_toast_msg("Locked - clear level %d first!" % idx)
		Audio.play("hurt", -8.0)
		return
	Audio.play("click", -2.0)
	Engine.set_meta("level", idx)
	get_tree().change_scene_to_file("res://Main.tscn")


# ------------------------------------------------------------------ profile
func _build_profile() -> void:
	_profile_page = Control.new()
	_profile_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_profile_page.hide()
	_stage.add_child(_profile_page)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_profile_page.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_profile_box = VBoxContainer.new()
	_profile_box.add_theme_constant_override("separation", 8)
	center.add_child(_profile_box)
	# Fixed back button, always on screen (not inside the scrolling list).
	var back := _btn("< BACK", 160, 44, func() -> void: _show("home"), Color(0.95, 0.75, 0.3), 20)
	back.position = Vector2(24, 20)
	_profile_page.add_child(back)


func _profile_line(text: String, size: int, col: Color) -> void:
	var l := _label(_profile_box, text, size, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _refresh_profile() -> void:
	SaveScript.ensure()
	for old in _profile_box.get_children():
		old.queue_free()
	var need: int = Progression.xp_needed(SaveScript.level)
	_profile_line("PROFILE", 44, Color(0.6, 0.85, 1.0))
	_profile_line("LEVEL %d" % SaveScript.level, 34, Color(1.0, 0.85, 0.3))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(520, 18)
	bar.max_value = float(need)
	bar.value = float(SaveScript.xp)
	bar.show_percentage = false
	_profile_box.add_child(bar)
	_profile_line("XP  %d / %d     Bosses defeated: %d" % [SaveScript.xp, need, SaveScript.bosses], 20, Color(0.85, 0.85, 0.92))
	_profile_line("PERKS", 26, Color(0.6, 0.85, 1.0))
	var any_perk := false
	for p in Progression.PERKS:
		var owned_perk: bool = SaveScript.perks.has(p["id"])
		any_perk = any_perk or owned_perk
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		_profile_box.add_child(row)
		var ic := PerkIcon.make(String(p["id"]), 34)
		ic.modulate = Color.WHITE if owned_perk else Color(0.4, 0.4, 0.45, 0.6)
		row.add_child(ic)
		_label(row, "%s  -  %s" % [p["name"], p["desc"]], 18, Color(0.6, 1.0, 0.7) if owned_perk else Color(0.6, 0.62, 0.7))
	if not any_perk:
		_profile_line("None yet. Reach a new level and pick one after a boss clear.", 18, Color(0.7, 0.72, 0.82))
	if SaveScript.pending_perks > 0:
		_profile_line("Pending perk choices: %d (picked after your next boss clear)" % SaveScript.pending_perks, 18, Color(1.0, 0.85, 0.3))
	_profile_line("CHALLENGES", 26, Color(0.6, 0.85, 1.0))
	for c in Progression.CHALLENGES:
		var done: bool = SaveScript.challenges_done.has(c["id"])
		_profile_line("%s  %s  -  %s   (+%d coins, +%d XP)" % ["[x]" if done else "[ ]", c["name"], c["desc"], c["coins"], c["xp"]],
				18, Color(0.6, 1.0, 0.7) if done else Color(0.85, 0.85, 0.92))


# ------------------------------------------------------------------ shop
func _build_missions() -> void:
	_missions_page = Control.new()
	_missions_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_missions_page.hide()
	_stage.add_child(_missions_page)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_missions_page.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_missions_box = VBoxContainer.new()
	_missions_box.add_theme_constant_override("separation", 10)
	center.add_child(_missions_box)
	var back := _btn("< BACK", 160, 44, func() -> void: _show("home"), Color(0.95, 0.75, 0.3), 20)
	back.position = Vector2(24, 20)
	_missions_page.add_child(back)


func _refresh_missions() -> void:
	SaveScript.ensure()
	for old in _missions_box.get_children():
		old.queue_free()
	var title := _label(_missions_box, "MISSIONS", 44, Color(0.6, 0.85, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label(_missions_box, "Normal missions pay coins. Hard missions give you a sword.", 18, Color(0.8, 0.82, 0.9))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for m in MissionsScript.LIST:
		var hard: bool = m["kind"] == "hard"
		var goal: int = int(m["goal"])
		var prog: int = MissionsScript.progress(String(m["stat"]))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 16)
		_missions_box.add_child(row)
		var vb := VBoxContainer.new()
		vb.custom_minimum_size = Vector2(560, 0)
		row.add_child(vb)
		var head := "[HARD]  " if hard else ""
		_label(vb, head + String(m["name"]) + "  -  " + String(m["desc"]), 20, Color(1.0, 0.85, 0.3) if hard else Color(0.6, 1.0, 0.7))
		var reward: String = "%d coins" % int(m["reward"]) if not hard else "Sword: %s" % String(ItemsScript.find("sword", String(m["gift"]))["name"])
		_label(vb, "Progress %d / %d     Reward: %s" % [mini(prog, goal), goal, reward], 16, Color(0.8, 0.82, 0.9))
		if MissionsScript.is_claimed(String(m["id"])):
			_label(row, "CLAIMED", 20, Color(0.5, 0.9, 0.5))
		elif MissionsScript.is_ready(m):
			row.add_child(_btn("CLAIM", 160, 46, _on_claim_mission.bind(String(m["id"])), Color(1.0, 0.85, 0.3), 20))
		else:
			_label(row, "In progress", 18, Color(0.6, 0.62, 0.7))


func _on_claim_mission(id: String) -> void:
	var msg := MissionsScript.claim(id)
	if msg != "":
		_toast_msg(msg)
	_refresh_missions()


func _build_shop() -> void:
	_shop_page = Control.new()
	_shop_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(_shop_page)
	var t := _label(_shop_page, "SHOP", 56, Color(1.0, 0.85, 0.3))
	t.add_theme_constant_override("outline_size", 10)
	t.position = Vector2(36, 8)
	# coin pill, top right
	var pill := Panel.new()
	pill.add_theme_stylebox_override("panel", _style(Color(0.10, 0.09, 0.05, 0.95), Color(1.0, 0.85, 0.3), 28, 3))
	pill.position = Vector2(800, 20)
	pill.size = Vector2(320, 58)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_page.add_child(pill)
	var cg := Glyph.new("shop", Color(1.0, 0.85, 0.3))
	cg.position = Vector2(16, 13)
	pill.add_child(cg)
	var cl := _label(pill, "", 28, Color(1.0, 0.85, 0.3))
	cl.name = "ShopCoins"
	cl.position = Vector2(62, 8)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	tabs.position = Vector2(36, 86)
	_shop_page.add_child(tabs)
	for tab in [["sword", "SWORDS"], ["suit", "ARMOR"], ["bow", "BOWS"], ["up", "UPGRADES"]]:
		var key: String = tab[0]
		var b := _btn(String(tab[1]), 172, 54, func() -> void: _set_tab(key), Color(0.95, 0.75, 0.3), 21)
		tabs.add_child(b)
		_tab_buttons[key] = b
	_shop_scroll = SmoothScroll.new()
	_shop_scroll.position = Vector2(36, 152)
	_shop_scroll.size = Vector2(738, 420)
	_shop_page.add_child(_shop_scroll)
	_shop_list = VBoxContainer.new()
	_shop_list.add_theme_constant_override("separation", 10)
	_shop_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_scroll.set_content(_shop_list)
	_shop_scroll.press_started.connect(func(b: Button) -> void: _pop(b, 0.95))
	_shop_scroll.press_cancelled.connect(func(b: Button) -> void: _pop(b, 1.0))
	_shop_scroll.tapped.connect(func(b: Button) -> void:
		_pop(b, 1.0)
		Audio.play("click", -8.0)
		b.pressed.emit())
	var back := _btn("BACK", 200, 58, func() -> void: _show("home"), Color(0.7, 0.75, 0.9), 22, "back")
	back.position = Vector2(36, 582)
	_shop_page.add_child(back)
	var play := _btn("PLAY", 240, 58, func() -> void: _show("levels"), Color(0.97, 0.74, 0.26), 26, "play", true)
	play.position = Vector2(256, 582)
	_shop_page.add_child(play)
	# hero preview card
	var card := Panel.new()
	card.add_theme_stylebox_override("panel", _style(Color(0.07, 0.07, 0.11, 0.92), Color(0.55, 0.42, 0.2, 0.9), 18, 3))
	card.position = Vector2(800, 96)
	card.size = Vector2(320, 544)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_page.add_child(card)
	var pv := _label(card, "YOUR HERO", 22, Color(0.8, 0.84, 0.95))
	pv.position = Vector2(0, 12)
	pv.custom_minimum_size = Vector2(320, 0)
	pv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_equip_label = _label(card, "", 17, Color(0.88, 0.9, 0.97))
	_equip_label.position = Vector2(0, 410)
	_equip_label.custom_minimum_size = Vector2(320, 0)
	_equip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero = Node2D.new()
	_hero.set_script(HeroArtScript)
	_hero.position = Vector2(960, 300)
	_hero.scale = Vector2(3.6, 3.6)
	_hero.set("aim_angle", -0.35)
	_stage.add_child(_hero)


func _set_tab(tab: String) -> void:
	_shop_tab = tab
	Audio.play("click", -6.0)
	_shop_scroll.reset()
	_refresh_shop()


func _stat_text(slot: String, it: Dictionary) -> String:
	if slot == "hero":
		return "%s\\n%s\\nPower: %s   Speed %d%%   Max HP +%d   Arrows +%d" % [it["title"], it["desc"], it["power"], int(round(float(it["speed"]) * 100.0)), int(it["hp"]), int(it["arrows"])]
	if slot == "sword":
		return "%s\\nDamage %d   Speed %.2fs   Reach %d" % [it["desc"], it["dmg"], it["cd"], int(it["range"])]
	if slot == "suit":
		return "%s\\nDamage taken %d%%   Speed %d%%   Noise %d%%" % [it["desc"], int(round(float(it["dmg"]) * 100.0)), int(round(float(it["spd"]) * 100.0)), int(round(float(it["noise"]) * 100.0))]
	return "%s\\nDamage %d   Arrows %d   Pierce %d" % [it["desc"], it["dmg"], it["ammo"], it["pierce"]]


func _swatch_color(slot: String, it: Dictionary) -> Color:
	var c: Color = Color.WHITE
	if slot == "sword":
		c = it["blade"]
	elif slot == "suit":
		c = it["steel"]
	elif slot == "hero":
		c = it["cape"]
	else:
		c = it["color"]
	return Color(minf(c.r, 1.0), minf(c.g, 1.0), minf(c.b, 1.0))


func _refresh_shop() -> void:
	for k in _tab_buttons:
		var b: Button = _tab_buttons[k]
		b.disabled = (k == _shop_tab)
	var cl: Label = _shop_page.find_child("ShopCoins", true, false) as Label
	cl.text = "COINS  %d" % SaveScript.coins
	for c in _shop_list.get_children():
		_shop_list.remove_child(c)
		c.queue_free()
	if _shop_tab == "up":
		_add_vitality_row()
		return
	for it in ItemsScript.list_for(_shop_tab):
		_add_row(_shop_tab, it)


func _ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)


## One shop card: [panel, hbox]. `state` colours the border: equipped / owned / locked / buy.
func _row_shell(state: String = "buy") -> Array:
	var border := Color(0.55, 0.42, 0.2, 0.9)
	var bg := Color(0.09, 0.085, 0.13, 0.96)
	match state:
		"equipped":
			border = Color(0.45, 0.85, 0.5)
			bg = Color(0.07, 0.14, 0.10, 0.96)
		"owned":
			border = Color(0.45, 0.72, 1.0)
		"locked":
			border = Color(0.35, 0.35, 0.4)
			bg = Color(0.07, 0.07, 0.09, 0.96)
	var panel := PanelContainer.new()
	var sb := _style(bg, border, 14, 3)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(716, 116)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	panel.add_child(hb)
	_shop_list.add_child(panel)
	return [panel, hb]


func _thumb(inner: Control) -> Control:
	var tp := PanelContainer.new()
	var sb := _style(Color(0.04, 0.04, 0.07, 0.95), Color(0.3, 0.26, 0.2, 0.9), 12, 2)
	sb.set_content_margin_all(6.0)
	tp.add_theme_stylebox_override("panel", sb)
	tp.custom_minimum_size = Vector2(96, 96)
	tp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tp.add_child(inner)
	return tp


func _add_row(slot: String, it: Dictionary) -> void:
	var id: String = it["id"]
	var price: int = int(it["price"])
	var owned: bool = SaveScript.owns(slot, id)
	var equipped: bool = String(SaveScript.equipped[slot]) == id
	var locked: bool = it.has("unlock") and not owned
	var state: String = "equipped" if equipped else ("owned" if owned else ("locked" if locked else "buy"))
	var shell: Array = _row_shell(state)
	var hb: HBoxContainer = shell[1]
	var sw: Control
	if slot == "hero":
		var pr := HeroPortrait.new()
		pr.hero_id = String(it["id"])
		pr.custom_minimum_size = Vector2(84, 84)
		sw = pr
	elif it.has("sprite"):
		var tr := TextureRect.new()
		tr.texture = load(String(it["sprite"]))
		tr.custom_minimum_size = Vector2(84, 84)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sw = tr
	else:
		var cr := ColorRect.new()
		cr.custom_minimum_size = Vector2(34, 74)
		cr.color = _swatch_color(slot, it)
		var cc := CenterContainer.new()
		cc.custom_minimum_size = Vector2(84, 84)
		cc.add_child(cr)
		sw = cc
	hb.add_child(_thumb(sw))
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vb.custom_minimum_size = Vector2(250, 0)
	vb.add_theme_constant_override("separation", 2)
	hb.add_child(vb)
	_label(vb, String(it["name"]), 24, Color(1, 0.95, 0.85))
	var st := _label(vb, _stat_text(slot, it).replace("\\n", "\n"), 15, Color(0.78, 0.8, 0.88))
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	st.custom_minimum_size = Vector2(250, 0)
	if locked:
		var ul := _label(vb, "Unlock: " + Progression.challenge_name(String(it["unlock"])), 15, Color(1.0, 0.85, 0.3))
		ul.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ul.custom_minimum_size = Vector2(250, 0)
	var btn: Button
	if equipped:
		btn = _btn("EQUIPPED", 150, 60, func() -> void: pass, Color(0.5, 0.9, 0.5), 19)
		btn.disabled = true
	elif owned:
		btn = _btn("EQUIP", 150, 60, _on_item.bind(slot, id, price), Color(0.5, 0.8, 1.0), 21, "", true)
	elif locked:
		btn = _btn("LOCKED", 150, 60, func() -> void: pass, Color(0.5, 0.5, 0.55), 19)
		btn.disabled = true
	else:
		btn = _btn("BUY  %d" % price, 150, 60, _on_item.bind(slot, id, price), Color(1.0, 0.85, 0.3), 21, "", SaveScript.coins >= price)
		btn.disabled = SaveScript.coins < price
	var view_btn := _btn("VIEW", 96, 60, _show_item_view.bind(slot, it), Color(0.6, 0.85, 1.0), 19)
	view_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(view_btn)
	hb.add_child(btn)
	_ignore_mouse(shell[0])


## Big picture and details of one item, opened from its VIEW button.
func _show_item_view(slot: String, it: Dictionary) -> void:
	var old := get_node_or_null("ItemView")
	if old:
		old.queue_free()
	var ov := ColorRect.new()
	ov.name = "ItemView"
	ov.color = Color(0, 0, 0, 0.78)
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ov)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(centre)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.08, 0.12, 0.98)
	sb.border_color = Color(0.95, 0.75, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(24)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(460, 0)
	centre.add_child(card)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 12)
	card.add_child(panel)
	if it.has("sprite"):
		var tr := TextureRect.new()
		tr.texture = load(String(it["sprite"]))
		tr.custom_minimum_size = Vector2(0, 240)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		panel.add_child(tr)
	if slot == "hero":
		var pv := HeroPortrait.new()
		pv.hero_id = String(it["id"])
		pv.custom_minimum_size = Vector2(0, 240)
		panel.add_child(pv)
	var title := _label(panel, String(it["name"]), 32, Color(1, 0.95, 0.85))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stats := _label(panel, _stat_text(slot, it).replace("\\n", "\n"), 18, Color(0.85, 0.87, 0.95))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.custom_minimum_size = Vector2(400, 0)
	panel.add_child(_btn("CLOSE", 200, 48, func() -> void: ov.queue_free(), Color(0.95, 0.75, 0.3), 20))


func _add_vitality_row() -> void:
	var lvl: int = SaveScript.vitality
	var shell: Array = _row_shell("owned" if lvl >= 5 else "buy")
	var hb: HBoxContainer = shell[1]
	hb.add_child(_thumb(HeartIcon.new()))
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vb.custom_minimum_size = Vector2(250, 0)
	hb.add_child(vb)
	_label(vb, "Vitality  (level %d / 5)" % lvl, 24, Color(1, 0.95, 0.85))
	var d := _label(vb, "+%d max health per level.  Current max health: %d" % [ItemsScript.VITALITY_HP, 100 + ItemsScript.VITALITY_HP * lvl], 15, Color(0.78, 0.8, 0.88))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(250, 0)
	var btn: Button
	if lvl >= 5:
		btn = _btn("MAXED", 150, 60, func() -> void: pass, Color(0.5, 0.9, 0.5), 19)
		btn.disabled = true
	else:
		var price: int = ItemsScript.VITALITY_PRICES[lvl]
		btn = _btn("BUY  %d" % price, 150, 60, _on_vitality.bind(price), Color(1.0, 0.85, 0.3), 21, "", SaveScript.coins >= price)
		btn.disabled = SaveScript.coins < price
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(btn)
	_ignore_mouse(shell[0])


func _on_item(slot: String, id: String, price: int) -> void:
	if SaveScript.owns(slot, id):
		SaveScript.equip(slot, id)
		_toast_msg("Equipped!")
		Audio.play("click", -4.0)
	elif SaveScript.buy(slot, id, price):
		_toast_msg("Bought and equipped!")
		Audio.play("coin", -2.0)
	else:
		_toast_msg("Not enough coins")
		Audio.play("hurt", -8.0)
	_refresh_shop()
	_update_hero()


func _on_vitality(price: int) -> void:
	if SaveScript.buy_vitality(price):
		_toast_msg("Max health increased!")
		Audio.play("heal", -2.0)
	else:
		_toast_msg("Not enough coins")
	_refresh_shop()


func _update_hero() -> void:
	var sword: Dictionary = ItemsScript.find("sword", String(SaveScript.equipped["sword"]))
	var suit: Dictionary = ItemsScript.find("suit", String(SaveScript.equipped["suit"]))
	var bow: Dictionary = ItemsScript.find("bow", String(SaveScript.equipped["bow"]))
	_hero.apply_loadout(suit, sword, bow)
	_hero.apply_hero(ItemsScript.find("hero", String(SaveScript.equipped["hero"])))
	if _equip_label != null:
		_equip_label.text = "Sword:  %s\nArmor:  %s\nBow:  %s" % [sword["name"], suit["name"], bow["name"]]
