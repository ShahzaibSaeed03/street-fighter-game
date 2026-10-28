class_name TouchControls
extends CanvasLayer
## On-screen controls for phones and tablets.
## Left stick moves; right stick aims the bow; buttons: SWORD, BOW, ROLL, SNEAK, DECOY, II (menu).
## Movement and buttons press the same input actions the keyboard uses, so Player.gd
## needs no change for them. The aim stick is the only new path: it sets aim_dir and
## aim_active, which Player._shoot() reads.
## Smoothing: sticks use a radial deadzone with a soft response curve, the knob eases back
## to centre, the aim direction turns smoothly toward the thumb, and buttons animate when pressed.
## Buttons show an icon (sword, bow, eye, roll arrow, bullseye, pause) with a small label.
## Hidden on desktop unless FORCE_SHOW is true (useful for testing with a mouse).

const FORCE_SHOW := false
const STICK_R := 88.0
const BUTTON_R := 40.0
const AIM_MIN := 0.2
const DEADZONE := 0.12
const AIM_TURN_SPEED := 18.0
const KNOB_EASE := 26.0

static var is_touch := false
static var aim_active := false
static var aim_dir := Vector2.RIGHT
static var decoy_tap := false


## Player calls this once per frame; true only on the frame the DECOY button was tapped.
static func consume_decoy() -> bool:
	var v := decoy_tap
	decoy_tap = false
	return v


static func set_action(action: String, strength: float) -> void:
	if strength > 0.02:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_touch = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	visible = is_touch or FORCE_SHOW
	if not visible:
		return
	# Positions are in the 1152x648 design space (canvas_items stretch).
	_add(Pad.new("move", Vector2(150, 500), STICK_R))
	_add(Pad.new("aim", Vector2(930, 500), STICK_R))
	_add(Pad.new("button", Vector2(1085, 430), BUTTON_R, "attack", "SWORD"))
	_add(Pad.new("button", Vector2(1000, 320), BUTTON_R, "shoot", "BOW"))
	_add(Pad.new("button", Vector2(1100, 300), 34.0, "sneak", "SNEAK"))
	_add(Pad.new("button", Vector2(1085, 575), 36.0, "dodge", "ROLL"))
	_add(Pad.new("button", Vector2(1000, 230), 32.0, "decoy", "DECOY"))
	_add(Pad.new("button", Vector2(1100, 32), 24.0, "menu", "II"))


func _add(pad: Pad) -> void:
	add_child(pad)


## One on-screen control: a stick (mode "move" or "aim") or a press-and-hold button.
class Pad extends Control:
	var mode := ""
	var action := ""
	var label := ""
	var _idx := -2  # touch index holding this pad; -2 = free, -1 = mouse (desktop testing)
	var _knob := Vector2.ZERO          # drawn knob position (eased)
	var _knob_target := Vector2.ZERO   # where the thumb actually is
	var _aim_target := Vector2.RIGHT   # aim direction the thumb asks for
	var _press_t := 0.0                # 0..1 press animation for buttons

	func _init(p_mode: String, center: Vector2, radius: float, p_action := "", p_label := "") -> void:
		mode = p_mode
		action = p_action
		label = p_label
		size = Vector2.ONE * radius * 2.0
		position = center - size * 0.5
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _process(delta: float) -> void:
		var held := _idx != -2
		if mode == "button":
			_press_t = move_toward(_press_t, 1.0 if held else 0.0, delta * 9.0)
		else:
			_knob = _knob.lerp(_knob_target, minf(1.0, delta * TouchControls.KNOB_EASE))
			if mode == "aim" and held:
				var a := lerp_angle(TouchControls.aim_dir.angle(), _aim_target.angle(), minf(1.0, delta * TouchControls.AIM_TURN_SPEED))
				TouchControls.aim_dir = Vector2.from_angle(a)
		queue_redraw()

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventScreenTouch:
			if ev.pressed and _idx == -2:
				_idx = ev.index
				_start(ev.position)
			elif not ev.pressed and ev.index == _idx:
				_end()
			accept_event()
		elif ev is InputEventScreenDrag:
			if ev.index == _idx:
				_move(ev.position)
			accept_event()
		elif not TouchControls.is_touch and ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed and _idx == -2:
				_idx = -1
				_start(ev.position)
			elif not ev.pressed and _idx == -1:
				_end()
			accept_event()
		elif not TouchControls.is_touch and ev is InputEventMouseMotion and _idx == -1:
			_move(ev.position)
			accept_event()

	func _start(p: Vector2) -> void:
		if mode == "button":
			_press(true)
		else:
			if mode == "aim":
				TouchControls.aim_active = true
			_move(p)
		queue_redraw()

	## Radial deadzone, then rescale so the stick ramps smoothly from the edge of the dead zone.
	func _shape(raw: Vector2) -> Vector2:
		var len := raw.length()
		if len < TouchControls.DEADZONE:
			return Vector2.ZERO
		var t := (len - TouchControls.DEADZONE) / (1.0 - TouchControls.DEADZONE)
		t = clampf(t, 0.0, 1.0)
		t = t * t * (3.0 - 2.0 * t)   # smoothstep: gentle start, full speed at the rim
		return raw.normalized() * t

	func _move(p: Vector2) -> void:
		if mode == "button":
			return
		var r := size.x * 0.5
		var v := p - size * 0.5
		if v.length() > r:
			v = v.normalized() * r
		_knob_target = v
		var dir := _shape(v / r)
		if mode == "move":
			TouchControls.set_action("move_left", maxf(-dir.x, 0.0))
			TouchControls.set_action("move_right", maxf(dir.x, 0.0))
			TouchControls.set_action("move_up", maxf(-dir.y, 0.0))
			TouchControls.set_action("move_down", maxf(dir.y, 0.0))
		elif mode == "aim" and (v / r).length() > TouchControls.AIM_MIN:
			_aim_target = (v / r).normalized()
			if not TouchControls.aim_active:
				TouchControls.aim_dir = _aim_target
		queue_redraw()

	func _end() -> void:
		_idx = -2
		_knob_target = Vector2.ZERO   # knob eases back in _process
		match mode:
			"move":
				for a in ["move_left", "move_right", "move_up", "move_down"]:
					Input.action_release(a)
			"aim":
				TouchControls.aim_active = false
			"button":
				_press(false)
		queue_redraw()

	func _press(on: bool) -> void:
		if action == "decoy":
			if on:
				TouchControls.decoy_tap = true
			return
		if on:
			Input.action_press(action)
		else:
			Input.action_release(action)

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.5
		if mode == "button":
			_draw_button(c, r)
		else:
			var held := _idx != -2
			draw_circle(c, r, Color(0.1, 0.1, 0.14, 0.3))
			draw_arc(c, r, 0.0, TAU, 48, Color(0.9, 0.9, 1.0, 0.35), 2.0)
			draw_circle(c + _knob * r * 0.9, r * 0.42, Color(0.95, 0.95, 1.0, 0.6 if held else 0.35))

	func _draw_button(c: Vector2, r: float) -> void:
		var pr := r * (1.0 - 0.06 * _press_t)
		draw_circle(c, pr, Color(0.1, 0.1, 0.14, 0.35 + 0.25 * _press_t))
		draw_arc(c, pr, 0.0, TAU, 40, Color(0.9, 0.9, 1.0, 0.6 + 0.3 * _press_t), 2.0)
		_draw_icon(action, c, pr / 40.0, Color(1, 1, 1, 0.92))
		var f := ThemeDB.fallback_font
		var fs := 13
		var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, c + Vector2(-w * 0.5, r + 16.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.75))

	## Icons drawn in code, sized from k (1.0 = a 40 px radius button).
	func _draw_icon(a: String, c: Vector2, k: float, col: Color) -> void:
		match a:
			"attack":   # sword: blade from lower-left to upper-right, guard and grip
				var dir := Vector2(1, -1).normalized()
				var perp := Vector2(1, 1).normalized()
				var base := c + Vector2(-6, 6) * k
				var tip := c + Vector2(14, -14) * k
				draw_colored_polygon(PackedVector2Array([base + perp * 3.4 * k, tip, base - perp * 3.4 * k]), col)
				draw_line(base + perp * 8.0 * k, base - perp * 8.0 * k, col, 3.2 * k)
				draw_line(base - dir * 3.0 * k, base - dir * 9.0 * k, col, 3.6 * k)
			"shoot":    # bow with a nocked arrow
				var bc := c + Vector2(-5, 0) * k
				var rr := 16.0 * k
				draw_arc(bc, rr, -1.2, 1.2, 16, col, 2.4 * k)
				draw_line(bc + Vector2.from_angle(-1.2) * rr, bc + Vector2.from_angle(1.2) * rr, Color(col, 0.6), 1.2 * k)
				draw_line(c + Vector2(-10, 0) * k, c + Vector2(12, 0) * k, col, 2.2 * k)
				draw_colored_polygon(PackedVector2Array([c + Vector2(17, 0) * k, c + Vector2(11, -4) * k, c + Vector2(11, 4) * k]), col)
				draw_line(c + Vector2(-10, 0) * k, c + Vector2(-14, -4) * k, col, 1.6 * k)
				draw_line(c + Vector2(-10, 0) * k, c + Vector2(-14, 4) * k, col, 1.6 * k)
			"sneak":    # eye: hidden / stealth
				var pts := PackedVector2Array()
				for i in 25:
					var t := TAU * float(i) / 24.0
					pts.append(c + Vector2(cos(t) * 16.0 * k, sin(t) * 9.5 * k))
				draw_polyline(pts, col, 2.2 * k)
				draw_circle(c, 4.6 * k, col)
			"dodge":    # roll: curved arrow around the body
				draw_arc(c, 12.0 * k, 0.3, 4.9, 24, col, 2.6 * k)
				var p := c + Vector2.from_angle(4.9) * 12.0 * k
				var n := Vector2.from_angle(4.9)
				var t := n.rotated(PI * 0.5)
				draw_colored_polygon(PackedVector2Array([p + t * 6.0 * k, p - n * 5.0 * k, p - t * 0.5 * k]), col)
			"decoy":    # bullseye: a lure thrown to distract guards
				draw_arc(c, 15.0 * k, 0.0, TAU, 32, col, 2.2 * k)
				draw_arc(c, 8.0 * k, 0.0, TAU, 24, col, 2.2 * k)
				draw_circle(c, 3.2 * k, col)
			"menu":     # pause bars
				draw_rect(Rect2(c + Vector2(-8, -9) * k, Vector2(5, 18) * k), col)
				draw_rect(Rect2(c + Vector2(3, -9) * k, Vector2(5, 18) * k), col)
