extends Node2D
## Game.gd — Dungeon Sneak: builds the dungeon + hero + camera + HUD and runs the mission flow.
## Sneak (C / Ctrl), stab guards from behind, collect hearts, find the keys, open the doors,
## defeat the boss. Press R to restart.

const DungeonScript := preload("res://Dungeon.gd")
const PlayerScene := preload("res://Player.tscn")
const MinimapScript := preload("res://Minimap.gd")
const VIGNETTE_SHADER := preload("res://vignette.gdshader")
const LevelsScript := preload("res://Levels.gd")
const SaveScript := preload("res://Save.gd")
const WeatherScript := preload("res://Weather.gd")

var level_idx: int = 0
var lv: Dictionary = {}
var dungeon
var player
var camera: Camera2D
var visited: Dictionary = {}
var current_room: String = ""

var stealth_kills: int = 0
var kills: int = 0
var alerts: int = 0
var elapsed: float = 0.0
var finished: bool = false

var _ui: CanvasLayer
var _hp_label: Label
var _hp_bar: ProgressBar
var _dodge_bar: ProgressBar
var _objective: Label
var _room_label: Label
var _hint: Label
var _toast: Label
var _key_bronze: ColorRect
var _key_gold: ColorRect
var _banner: Label
var _end_panel: PanelContainer
var _end_btn: Button
var _menu_btn: Button
var _coin_label: Label
var _ammo_label: Label
var _weather: CPUParticles2D
var _level_label: Label
var _end_title: Label
var _end_body: Label
var _title_panel: Control
var _vignette_mat: ShaderMaterial
var _hint_timer: float = 0.0
var _toast_tween: Tween
var _banner_tween: Tween
var _shake_strength: float = 0.0
var _pulse: float = 0.0
var _last_hp: int = -1


func _ready() -> void:
	add_to_group("game_manager")
	Engine.time_scale = 1.0
	_setup_inputs()
	_setup_environment()
	level_idx = clampi(int(Engine.get_meta("level", 0)), 0, LevelsScript.LAST)
	lv = LevelsScript.LEVELS[level_idx]

	dungeon = DungeonScript.new()
	add_child(dungeon)
	dungeon.build(level_idx)

	player = PlayerScene.instantiate()
	player.position = dungeon.start_position()
	add_child(player)
	_weather = CPUParticles2D.new()
	_weather.set_script(WeatherScript)
	add_child(_weather)
	_weather.configure(String(lv["weather"]))
	_weather.position = dungeon.room_center("A")

	dungeon.populate()
	dungeon.guard_died.connect(_on_guard_died)

	camera = Camera2D.new()
	camera.position = dungeon.room_center("A")
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	add_child(camera)

	_build_ui()
	player.health_changed.connect(_on_health_changed)
	player.player_died.connect(_on_player_died)
	_on_health_changed(player.health, player.max_health)
	_enter_room("A", true)

	_begin()


# ------------------------------------------------------------------ setup
func _key_action(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


func _setup_inputs() -> void:
	if InputMap.has_action("shoot"):
		return
	var rmb := InputEventMouseButton.new()
	rmb.button_index = MOUSE_BUTTON_RIGHT
	InputMap.add_action("shoot")
	InputMap.action_add_event("shoot", rmb)
	var lmb := InputEventMouseButton.new()
	lmb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", lmb)
	_key_action("menu", KEY_ESCAPE)
	_key_action("sneak", KEY_C)
	_key_action("sneak", KEY_CTRL)
	_key_action("restart", KEY_R)
	_key_action("shoot", KEY_F)


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _label(parent: Node, text: String, size: int, col: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	parent.add_child(l)
	return l


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.92)
	sb.border_color = Color(0.7, 0.55, 0.25, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(22)
	return sb


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui)

	# vignette (red when low on health)
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = VIGNETTE_SHADER
	var vig := ColorRect.new()
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig.material = _vignette_mat
	_ui.add_child(vig)

	# top-left: health, dodge, keys
	var tl := VBoxContainer.new()
	tl.position = Vector2(18, 14)
	tl.custom_minimum_size = Vector2(280, 0)
	_ui.add_child(tl)
	_level_label = _label(tl, "LEVEL %d / %d  -  %s" % [level_idx + 1, LevelsScript.LAST + 1, lv["name"]], 17, lv["banner"])
	_coin_label = _label(tl, "COINS 0", 19, Color(1.0, 0.85, 0.3))
	_hp_label = _label(tl, "HP 100 / 100", 22)
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(260, 16)
	_hp_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.8, 0.12, 0.16)
	fill.set_corner_radius_all(4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(4)
	_hp_bar.add_theme_stylebox_override("fill", fill)
	_hp_bar.add_theme_stylebox_override("background", bg)
	tl.add_child(_hp_bar)
	_dodge_bar = ProgressBar.new()
	_dodge_bar.custom_minimum_size = Vector2(260, 7)
	_dodge_bar.show_percentage = false
	tl.add_child(_dodge_bar)
	_ammo_label = _label(tl, "ARROWS 0 / 0", 16, Color(0.8, 0.9, 1.0))
	var keys_row := HBoxContainer.new()
	keys_row.add_theme_constant_override("separation", 8)
	tl.add_child(keys_row)
	_label(keys_row, "KEYS", 16, Color(0.8, 0.8, 0.85))
	_key_bronze = ColorRect.new()
	_key_bronze.custom_minimum_size = Vector2(26, 16)
	_key_bronze.color = Color(0.25, 0.18, 0.12)
	keys_row.add_child(_key_bronze)
	_key_gold = ColorRect.new()
	_key_gold.custom_minimum_size = Vector2(26, 16)
	_key_gold.color = Color(0.25, 0.22, 0.1)
	keys_row.add_child(_key_gold)

	# objective + room name (top center)
	_objective = _label(_ui, "", 18, Color(1.0, 0.85, 0.4))
	_objective.position = Vector2(330, 14)
	_objective.custom_minimum_size = Vector2(500, 0)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_room_label = _label(_ui, "", 15, Color(0.75, 0.78, 0.9))
	_room_label.position = Vector2(330, 62)
	_room_label.custom_minimum_size = Vector2(500, 0)
	_room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# minimap (top-right)
	var mm := Control.new()
	mm.set_script(MinimapScript)
	mm.set("game", self)
	mm.set("dungeon", dungeon)
	mm.position = Vector2(1000, 22)
	_ui.add_child(mm)

	# hint + toast + big banner
	_hint = _label(_ui, "", 20, Color(1, 1, 1))
	_hint.position = Vector2(276, 560)
	_hint.custom_minimum_size = Vector2(600, 0)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast = _label(_ui, "", 26, Color(1.0, 0.9, 0.5))
	_toast.position = Vector2(176, 110)
	_toast.custom_minimum_size = Vector2(800, 0)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	_banner = _label(_ui, "", 54, Color(1, 1, 1))
	_banner.position = Vector2(76, 250)
	_banner.custom_minimum_size = Vector2(1000, 0)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0

	var help := _label(_ui, "WASD move   C sneak   SPACE / left click sword   F / right click bow   SHIFT roll   R restart   ESC menu", 13, Color(0.7, 0.7, 0.75))
	help.position = Vector2(18, 622)

	_build_end_panel()
	_refresh_objective()


func _build_end_panel() -> void:
	_end_panel = PanelContainer.new()
	_end_panel.add_theme_stylebox_override("panel", _panel_style())
	_end_panel.set_anchors_preset(Control.PRESET_CENTER)
	_end_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_end_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_end_panel.custom_minimum_size = Vector2(420, 0)
	_end_panel.hide()
	_ui.add_child(_end_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_end_panel.add_child(box)
	_end_title = _label(box, "", 44)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_body = _label(box, "", 20, Color(0.85, 0.85, 0.9))
	_end_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_btn = Button.new()
	_end_btn.text = "Retry (R)"
	_end_btn.custom_minimum_size = Vector2(220, 48)
	_end_btn.pressed.connect(_restart)
	box.add_child(_end_btn)
	_menu_btn = Button.new()
	_menu_btn.text = "Menu (Esc)"
	_menu_btn.custom_minimum_size = Vector2(220, 42)
	_menu_btn.pressed.connect(_to_menu)
	box.add_child(_menu_btn)


func _build_title_panel() -> void:
	var holder := ColorRect.new()
	holder.color = Color(0, 0, 0.02, 0.8)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.hide()
	_ui.add_child(holder)
	_title_panel = holder
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title := _label(box, "DUNGEON SNEAK", 60, Color(0.95, 0.75, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label(box, "Fight through FIVE levels of danger. Take the guards from behind.\nFind the bronze and gold keys. End every boss.", 20, Color(0.85, 0.85, 0.9))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ctl := _label(box, "WASD / Arrows  -  move\nC or Ctrl  -  sneak (quiet, harder to see)\nSPACE  -  sword  (from behind = instant silent kill)\nSHIFT  -  roll (dodge)\nR  -  restart level    N / B  -  skip to next / previous level\n\nGuards see inside the yellow cone. Walls and crates hide you.\nHearts heal. Locked doors open when you carry the right key.", 17, Color(0.78, 0.8, 0.88))
	ctl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var btn := Button.new()
	btn.text = "START"
	btn.custom_minimum_size = Vector2(240, 54)
	btn.pressed.connect(_begin)
	box.add_child(btn)
	btn.call_deferred("grab_focus")


func _begin() -> void:
	get_tree().paused = false
	Audio.play("click", -4.0)
	_show_banner("LEVEL %d  -  %s" % [level_idx + 1, lv["name"]], lv["banner"])


# ------------------------------------------------------------------ events (called via groups too)
func toast(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


func show_hint(text: String) -> void:
	_hint.text = text
	_hint_timer = 0.15


func on_key(kind: String) -> void:
	toast("%s key found!" % kind.capitalize())
	_refresh_keys()
	_refresh_objective()


func on_alert() -> void:
	alerts += 1


func shake(amount: float) -> void:
	_shake_strength = maxf(_shake_strength, amount)


func _show_banner(text: String, col: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", col)
	if _banner_tween:
		_banner_tween.kill()
	_banner.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_interval(1.1)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)


func _on_guard_died(guard: Node2D, stealth: bool) -> void:
	kills += 1
	if stealth:
		stealth_kills += 1
	if bool(guard.get("is_boss")):
		finished = true
		Audio.play("wave_complete", -2.0, 0.0)
		for e in get_tree().get_nodes_in_group("enemies"):
			if bool(e.get("is_minion")):
				e.take_damage(999, e.global_position, 0.0)
		var stars: int = 1
		if alerts <= 8:
			stars += 1
		if alerts <= 3:
			stars += 1
		var bonus: int = 40 * stars * (level_idx + 1)
		SaveScript.coins += bonus
		SaveScript.record_clear(level_idx, elapsed, stars, LevelsScript.LAST)
		await get_tree().create_timer(1.6).timeout
		var star_text: String = "*".repeat(stars) + "-".repeat(3 - stars)
		var body := "Stars  %s\nTime  %s\nGuards defeated  %d   (silent: %d)\nTimes spotted  %d\nBonus coins  +%d" \
				% [star_text, _fmt_time(elapsed), kills, stealth_kills, alerts, bonus]
		if level_idx < LevelsScript.LAST:
			Engine.set_meta("level", level_idx + 1)
			var nxt: Dictionary = LevelsScript.LEVELS[level_idx + 1]
			_end_btn.text = "Next level (R)"
			_show_end("LEVEL %d CLEAR" % (level_idx + 1), body + "\n\nUnlocked: %s" % nxt["name"], lv["banner"])
		else:
			Engine.set_meta("level", 0)
			_end_btn.text = "Play again (R)"
			_show_end("YOU WON THE GAME", body + "\n\nAll levels cleared! Spend your coins in the shop.", Color(0.95, 0.8, 0.3))


func _on_player_died() -> void:
	finished = true
	SaveScript.save()
	await get_tree().create_timer(1.3).timeout
	_end_btn.text = "Retry level (R)"
	_show_end("YOU DIED", "Level %d - %s\nYour coins are kept. Buy better gear in the shop!" % [level_idx + 1, lv["name"]], Color(0.85, 0.12, 0.12))


func _show_end(title: String, body: String, col: Color) -> void:
	_end_title.text = title
	_end_title.add_theme_color_override("font_color", col)
	_end_body.text = body
	_end_panel.show()


func _on_health_changed(current: int, maximum: int) -> void:
	_hp_label.text = "HP %d / %d" % [current, maximum]
	_hp_bar.max_value = maximum
	var tw := create_tween()
	tw.tween_property(_hp_bar, "value", float(current), 0.15)
	if _last_hp >= 0 and current < _last_hp:
		shake(8.0)
	_last_hp = current


func _fmt_time(t: float) -> String:
	return "%02d:%02d" % [int(t) / 60, int(t) % 60]


# ------------------------------------------------------------------ rooms / objective
func _enter_room(id: String, silent: bool = false) -> void:
	current_room = id
	if _weather != null:
		_weather.position = dungeon.room_center(id)
	var first: bool = not visited.has(id)
	visited[id] = true
	_room_label.text = "%s   |   %s" % [lv["name"], dungeon.room_name(id)]
	if first and not silent:
		if id == "F":
			var bb: Dictionary = lv["boss"]
			_show_banner("BOSS: %s" % bb["name"], Color(1.0, 0.35, 0.3))
		else:
			_show_banner(dungeon.room_name(id).to_upper(), Color(0.9, 0.9, 1.0))
	_refresh_objective()


func _refresh_keys() -> void:
	_key_bronze.color = Color(1.0, 0.6, 0.25) if player.keys.has("bronze") else Color(0.25, 0.18, 0.12)
	_key_gold.color = Color(1.0, 0.85, 0.2) if player.keys.has("gold") else Color(0.25, 0.22, 0.1)


func _refresh_objective() -> void:
	if player == null:
		return
	var boss_info: Dictionary = lv["boss"]
	var boss_name: String = String(boss_info["name"])
	if player.keys.has("gold"):
		_objective.text = "Open the gold door in the %s and defeat %s" % [dungeon.room_name("D"), boss_name]
	elif player.keys.has("bronze"):
		_objective.text = "Open the bronze door between the %s and the %s. Find the GOLD key in the %s" % [dungeon.room_name("B"), dungeon.room_name("D"), dungeon.room_name("E")]
	else:
		_objective.text = "Find the BRONZE key in the %s" % dungeon.room_name("C")


# ------------------------------------------------------------------ per frame
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		_restart()
		return
	if Input.is_action_just_pressed("menu"):
		_to_menu()
		return
	_pulse += delta
	if not finished and not get_tree().paused:
		elapsed += delta

	_hint_timer -= delta
	if _hint_timer <= 0.0:
		_hint.text = ""

	_dodge_bar.value = player.dodge_ready_ratio() * 100.0
	_coin_label.text = "COINS  %d" % SaveScript.coins
	_ammo_label.text = "ARROWS  %d / %d" % [player.ammo, player.max_ammo]

	var room: String = dungeon.room_at(player.global_position)
	if room != "" and room != current_room:
		_enter_room(room)
	var target: Vector2 = dungeon.room_center(current_room)
	camera.position = target
	if _shake_strength > 0.01:
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength
		_shake_strength = move_toward(_shake_strength, 0.0, 40.0 * delta)
	else:
		_shake_strength = 0.0
		camera.offset = Vector2.ZERO

	var hp: int = player.health
	var hp_max: int = player.max_health
	var low: bool = hp <= int(hp_max * 0.3) and not player.is_dead
	if low:
		var k: float = 0.5 + 0.5 * sin(_pulse * 6.0)
		_vignette_mat.set_shader_parameter("tint", Color(0.8, 0.0, 0.0, 1.0))
		_vignette_mat.set_shader_parameter("strength", 0.55 + 0.35 * k)
	else:
		_vignette_mat.set_shader_parameter("tint", Color(0.0, 0.0, 0.0, 1.0))
		_vignette_mat.set_shader_parameter("strength", 0.6)


func _to_menu() -> void:
	SaveScript.save()
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Menu.tscn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveScript.save()


func _restart() -> void:
	SaveScript.save()
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()
