import sys
p = sys.argv[1]
raw = open(p, 'rb').read().decode('utf-8')
crlf = '\r\n' in raw
s = raw.replace('\r\n', '\n')

def cut(s, start, end, new):
    a = s.index(start)
    b = s.index(end, a)
    return s[:a] + new + s[b:]

# ---------- inner classes (insert before "# ---- setup")
classes = '''## Touch-friendly scroller. Buttons inside it ignore the mouse; this control watches the
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


'''
s = s.replace('# ------------------------------------------------------------------ setup\n', classes + '# ------------------------------------------------------------------ setup\n', 1)

# ---------- vars
s = s.replace('var _shop_list: VBoxContainer\n', 'var _shop_list: VBoxContainer\nvar _shop_scroll: SmoothScroll\nvar _equip_label: Label\n', 1)

# ---------- build shop
build = '''func _build_shop() -> void:
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


'''
s = cut(s, 'func _build_shop() -> void:', 'func _set_tab(tab: String) -> void:', build)

s = s.replace('''	_shop_tab = tab
	Audio.play("click", -6.0)
	_refresh_shop()''', '''	_shop_tab = tab
	Audio.play("click", -6.0)
	_shop_scroll.reset()
	_refresh_shop()''', 1)

# ---------- refresh / rows
rows = '''func _refresh_shop() -> void:
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
	var st := _label(vb, _stat_text(slot, it).replace("\\\\n", "\\n"), 15, Color(0.78, 0.8, 0.88))
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


'''
s = cut(s, 'func _refresh_shop() -> void:', '## Big picture and details of one item', rows)

vit = '''func _add_vitality_row() -> void:
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


'''
s = cut(s, 'func _add_vitality_row() -> void:', 'func _on_item(slot: String', vit)

# equipped summary under the hero
s = s.rstrip('\n') + '''
	if _equip_label != null:
		_equip_label.text = "Sword:  %s\\nArmor:  %s\\nBow:  %s" % [sword["name"], suit["name"], bow["name"]]
'''
open(p, 'wb').write((s.replace('\n', '\r\n') if crlf else s).encode('utf-8'))
print("ok", crlf)
