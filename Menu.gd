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
var _shop_tab: String = "sword"
var _tab_buttons: Dictionary = {}
var _coin_label: Label
var _hero: Node2D
var _toast: Label
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
			_:  # shadow: moon
				draw_circle(c, 28.0, Color(0.75, 0.45, 1.0))
				draw_circle(c + Vector2(12, -6), 24.0, Color(0.12, 0.08, 0.2))
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
		draw_string(font, Vector2(16, 92), String(info["desc"]).substr(0, 30), HORIZONTAL_ALIGNMENT_LEFT, 250, 13, Color(0.85, 0.85, 0.9, 0.85))
		var desc: String = String(info["desc"])
		if desc.length() > 30:
			draw_string(font, Vector2(16, 108), desc.substr(30), HORIZONTAL_ALIGNMENT_LEFT, 250, 13, Color(0.85, 0.85, 0.9, 0.85))
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


# ------------------------------------------------------------------ setup
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SaveScript.ensure()
	Engine.time_scale = 1.0
	get_tree().paused = false
	for i in 55:
		_embers.append({"p": Vector2(randf() * 1152.0, randf() * 648.0), "v": Vector2(randf_range(-6.0, 6.0), randf_range(-38.0, -10.0)),
				"r": randf_range(1.2, 3.2), "ph": randf() * TAU})
	_build_home()
	_build_levels()
	_build_shop()
	_build_profile()
	_build_missions()
	_toast = _label(self, "", 24, Color(1.0, 0.9, 0.5))
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
			p = Vector2(randf() * 1152.0, 660.0)
		e["p"] = p
	queue_redraw()
	if _coin_label != null:
		_coin_label.text = "COINS  %d" % SaveScript.coins


func _draw() -> void:
	var top := Color(0.05, 0.05, 0.10)
	var bot := Color(0.16, 0.08, 0.06)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1152, 0), Vector2(1152, 648), Vector2(0, 648)]),
			PackedColorArray([top, top, bot, bot]))
	for e in _embers:
		var p: Vector2 = e["p"]
		var a: float = 0.25 + 0.2 * sin(_t * 2.0 + float(e["ph"]))
		draw_circle(p, float(e["r"]), Color(1.0, 0.55, 0.2, a))


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


func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	return sb


func _btn(text: String, w: float, h: float, cb: Callable, accent: Color = Color(0.95, 0.75, 0.3), font_size: int = 22) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", _style(Color(0.11, 0.11, 0.17, 0.95), accent.darkened(0.35)))
	b.add_theme_stylebox_override("hover", _style(Color(0.2, 0.17, 0.11, 0.98), accent))
	b.add_theme_stylebox_override("pressed", _style(Color(0.3, 0.22, 0.1, 1.0), accent.lightened(0.2)))
	b.add_theme_stylebox_override("disabled", _style(Color(0.07, 0.07, 0.09, 0.9), Color(0.25, 0.25, 0.3)))
	b.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.55))
	b.pressed.connect(cb)
	return b


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
	add_child(_home)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_home.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var title := _label(box, "DUNGEON SNEAK", 84, Color(0.95, 0.75, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label(box, "Six levels. Six bosses. Sneak, stab, shoot, survive.", 22, Color(0.85, 0.85, 0.92))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	box.add_child(gap)
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var b1 := _btn("PLAY", 320, 58, func() -> void: _show("levels"))
	var b2 := _btn("SHOP", 320, 52, func() -> void: _show("shop"), Color(1.0, 0.85, 0.3))
	var b4 := _btn("PROFILE", 320, 46, func() -> void: _show("profile"), Color(0.6, 0.8, 1.0), 20)
	var b3 := _btn("QUIT", 320, 44, func() -> void: get_tree().quit(), Color(0.7, 0.4, 0.4), 18)
	var b5 := _btn("MISSIONS", 320, 46, func() -> void: _show("missions"), Color(0.9, 0.6, 0.9), 20)
	for b in [b1, b2, b5, b4, b3]:
		var holder := CenterContainer.new()
		holder.add_child(b)
		row.add_child(holder)
	var ctl := _label(box, "WASD move  -  C sneak  -  SPACE / left click: sword (from behind = silent kill)\nF / right click: bow (aim with mouse)  -  SHIFT roll  -  E throw decoy (lures guards)  -  ESC menu", 16, Color(0.7, 0.72, 0.82))
	ctl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coin_label = _label(_home, "COINS  0", 28, Color(1.0, 0.85, 0.3))
	_coin_label.position = Vector2(900, 24)


# ------------------------------------------------------------------ level select
func _build_levels() -> void:
	_levels_page = Control.new()
	_levels_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_levels_page)
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
	var back := _btn("< BACK", 160, 44, func() -> void: _show("home"), Color(0.7, 0.7, 0.8), 20)
	back.position = Vector2(44, 586)
	_levels_page.add_child(back)
	var shop := _btn("SHOP", 160, 44, func() -> void: _show("shop"), Color(1.0, 0.85, 0.3), 20)
	shop.position = Vector2(224, 586)
	_levels_page.add_child(shop)


func _rebuild_levels() -> void:
	for c in _grid.get_children():
		c.queue_free()
	for i in LevelsScript.LEVELS.size():
		var card := Card.new()
		card.idx = i
		card.info = LevelsScript.LEVELS[i]
		card.locked = i > SaveScript.unlocked
		var rec: Dictionary = SaveScript.best.get(str(i), {})
		card.stars = int(rec.get("stars", 0))
		card.best_time = float(rec.get("time", -1.0))
		card.chosen.connect(_on_level_chosen)
		_grid.add_child(card)


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
	add_child(_profile_page)
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
	add_child(_missions_page)
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
	add_child(_shop_page)
	var t := _label(_shop_page, "SHOP", 48, Color(1.0, 0.85, 0.3))
	t.position = Vector2(40, 18)
	var cl := _label(_shop_page, "", 28, Color(1.0, 0.85, 0.3))
	cl.position = Vector2(860, 28)
	cl.name = "ShopCoins"
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	tabs.position = Vector2(40, 86)
	_shop_page.add_child(tabs)
	for tab in [["sword", "SWORDS"], ["suit", "ARMOR"], ["bow", "BOWS"], ["up", "UPGRADES"]]:
		var key: String = tab[0]
		var b := _btn(String(tab[1]), 140, 40, func() -> void: _set_tab(key), Color(0.95, 0.75, 0.3), 18)
		tabs.add_child(b)
		_tab_buttons[key] = b
	var sc := ScrollContainer.new()
	sc.position = Vector2(40, 140)
	sc.custom_minimum_size = Vector2(660, 430)
	sc.size = Vector2(660, 430)
	_shop_page.add_child(sc)
	_shop_list = VBoxContainer.new()
	_shop_list.add_theme_constant_override("separation", 8)
	_shop_list.custom_minimum_size = Vector2(630, 0)
	sc.add_child(_shop_list)
	var back := _btn("< BACK", 160, 44, func() -> void: _show("home"), Color(0.7, 0.7, 0.8), 20)
	back.position = Vector2(40, 590)
	_shop_page.add_child(back)
	var play := _btn("PLAY", 160, 44, func() -> void: _show("levels"), Color(0.95, 0.75, 0.3), 20)
	play.position = Vector2(220, 590)
	_shop_page.add_child(play)
	var pv := _label(_shop_page, "Your hero", 20, Color(0.8, 0.82, 0.9))
	pv.position = Vector2(850, 120)
	_hero = Node2D.new()
	_hero.set_script(HeroArtScript)
	_hero.position = Vector2(930, 330)
	_hero.scale = Vector2(3.6, 3.6)
	_hero.set("aim_angle", -0.35)
	add_child(_hero)


func _set_tab(tab: String) -> void:
	_shop_tab = tab
	Audio.play("click", -6.0)
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
	var cl: Label = _shop_page.get_node("ShopCoins") as Label
	cl.text = "COINS  %d" % SaveScript.coins
	for c in _shop_list.get_children():
		c.queue_free()
	if _shop_tab == "up":
		_add_vitality_row()
		return
	for it in ItemsScript.list_for(_shop_tab):
		_add_row(_shop_tab, it)


func _row_shell() -> Array:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.08, 0.12, 0.95), Color(0.5, 0.4, 0.2, 0.7)))
	panel.custom_minimum_size = Vector2(630, 84)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	panel.add_child(hb)
	_shop_list.add_child(panel)
	return [panel, hb]


func _add_row(slot: String, it: Dictionary) -> void:
	var shell: Array = _row_shell()
	var hb: HBoxContainer = shell[1]
	var sw: Control
	if slot == "hero":
		var pr := HeroPortrait.new()
		pr.hero_id = String(it["id"])
		pr.custom_minimum_size = Vector2(56, 64)
		sw = pr
	elif it.has("sprite"):
		var tr := TextureRect.new()
		tr.texture = load(String(it["sprite"]))
		tr.custom_minimum_size = Vector2(56, 64)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sw = tr
	else:
		var cr := ColorRect.new()
		cr.custom_minimum_size = Vector2(14, 60)
		cr.color = _swatch_color(slot, it)
		sw = cr
	hb.add_child(sw)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	_label(vb, String(it["name"]), 21, Color(1, 0.95, 0.85))
	_label(vb, _stat_text(slot, it).replace("\\n", "\n"), 14, Color(0.78, 0.8, 0.88))
	if it.has("unlock") and not SaveScript.owns(slot, String(it["id"])):
		_label(vb, "Unlock: " + Progression.challenge_name(String(it["unlock"])), 14, Color(1.0, 0.85, 0.3))
	var id: String = it["id"]
	var price: int = int(it["price"])
	var owned: bool = SaveScript.owns(slot, id)
	var equipped: bool = String(SaveScript.equipped[slot]) == id
	var btn: Button
	if equipped:
		btn = _btn("EQUIPPED", 150, 48, func() -> void: pass, Color(0.5, 0.9, 0.5), 18)
		btn.disabled = true
	elif owned:
		btn = _btn("EQUIP", 150, 48, _on_item.bind(slot, id, price), Color(0.5, 0.8, 1.0), 18)
	elif it.has("unlock"):
		btn = _btn("LOCKED", 150, 48, func() -> void: pass, Color(0.5, 0.5, 0.55), 18)
		btn.disabled = true
	else:
		btn = _btn("BUY  %d" % price, 150, 48, _on_item.bind(slot, id, price), Color(1.0, 0.85, 0.3), 18)
		btn.disabled = SaveScript.coins < price
	var view_btn := _btn("VIEW", 90, 48, _show_item_view.bind(slot, it), Color(0.6, 0.85, 1.0), 18)
	hb.add_child(view_btn)
	hb.add_child(btn)


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
	var shell: Array = _row_shell()
	var hb: HBoxContainer = shell[1]
	var sw := ColorRect.new()
	sw.custom_minimum_size = Vector2(14, 60)
	sw.color = Color(0.9, 0.2, 0.25)
	hb.add_child(sw)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	var lvl: int = SaveScript.vitality
	_label(vb, "Vitality  (level %d / 5)" % lvl, 21, Color(1, 0.95, 0.85))
	_label(vb, "+%d max health per level.  Current max health: %d" % [ItemsScript.VITALITY_HP, 100 + ItemsScript.VITALITY_HP * lvl], 14, Color(0.78, 0.8, 0.88))
	var btn: Button
	if lvl >= 5:
		btn = _btn("MAXED", 150, 48, func() -> void: pass, Color(0.5, 0.9, 0.5), 18)
		btn.disabled = true
	else:
		var price: int = ItemsScript.VITALITY_PRICES[lvl]
		btn = _btn("BUY  %d" % price, 150, 48, _on_vitality.bind(price), Color(1.0, 0.85, 0.3), 18)
		btn.disabled = SaveScript.coins < price
	hb.add_child(btn)


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
