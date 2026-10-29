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
const STICK_R := 92.0
const BUTTON_R := 44.0
const AIM_MIN := 0.2
const DEADZONE := 0.12
const AIM_TURN_SPEED := 18.0
const KNOB_EASE := 26.0

static var is_touch := false
static var aim_active := false
static var aim_dir := Vector2.RIGHT
static var decoy_tap := false
static var aim_fire := false          # set when the aim stick is released after a real aim: fire!
static var _aim_fire_t := 0.0
const AIM_FIRE_MIN := 0.45


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
	visible = is_touch or FORCE_SHOW or Tuning.FORCE_MOBILE
	if not visible:
		return
	# Design positions are in the 1152x648 space. On a wider or taller screen (stretch aspect
	# "expand") _layout() moves the right-hand controls to the real right edge and the bottom
	# ones to the real bottom. The move stick is a floating stick: it appears where the thumb lands.
	_add(Pad.new("move", Vector2(160, 500), STICK_R))
	_add(Pad.new("aim", Vector2(930, 500), STICK_R))
	_add(Pad.new("button", Vector2(1085, 430), BUTTON_R, "attack", "SWORD"))
	_add(Pad.new("button", Vector2(1000, 320), BUTTON_R, "shoot", "AUTO BOW"))
	_add(Pad.new("button", Vector2(1100, 300), 34.0, "sneak", "SNEAK"))
	_add(Pad.new("button", Vector2(1085, 575), 36.0, "dodge", "ROLL"))
	_add(Pad.new("button", Vector2(1000, 208), 32.0, "decoy", "DECOY"))
	_add(Pad.new("button", Vector2(905, 34), 24.0, "menu", "II"))
	get_viewport().size_changed.connect(_layout)
	_layout()


var _pads: Array = []
var _shown := true


func _add(pad: Pad) -> void:
	add_child(pad)
	_pads.append(pad)


func _layout() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var ex: float = vs.x - 1152.0
	var ey: float = vs.y - 648.0
	for pad in _pads:
		var c: Vector2 = pad.design_center
		if c.x > 576.0:
			c.x += ex
		if c.y > 324.0:
			c.y += ey
		pad.place(c, vs)


## Hide the controls while the game is paused or over, so they never block the end / perk buttons.
func _process(delta: float) -> void:
	if _aim_fire_t > 0.0:
		_aim_fire_t -= delta
		if _aim_fire_t <= 0.0:
			aim_fire = false
	if _pads.is_empty():
		return
	var gm := get_tree().get_first_node_in_group("game_manager")
	var show_now: bool = not get_tree().paused and not (gm != null and bool(gm.get("finished")))
	if show_now == _shown:
		return
	_shown = show_now
	for pad in _pads:
		if not show_now and pad._idx != -2:
			pad._end()
		pad.visible = show_now


## One on-screen control: a stick (mode "move" or "aim") or a press-and-hold button.
class Pad extends Control:
	var mode := ""
	var action := ""
	var label := ""
	var _idx := -2  # touch index holding this pad; -2 = free, -1 = mouse (desktop testing)
	var _knob := Vector2.ZERO          # drawn knob position (eased)
	var _knob_target := Vector2.ZERO   # where the thumb actually is
	var _aim_target := Vector2.RIGHT   # aim direction the thumb asks for
	var _aim_peak := 0.0               # aim stick: furthest the thumb went this touch (0..1)
	var _press_t := 0.0                # 0..1 press animation for buttons
	var design_center := Vector2.ZERO  # where this pad sits in the 1152x648 design space
	var _home := Vector2.ZERO          # move stick: resting centre (local coords)
	var _origin := Vector2.ZERO        # move stick: current centre (local coords), follows the thumb

	func _init(p_mode: String, center: Vector2, radius: float, p_action := "", p_label := "") -> void:
		mode = p_mode
		action = p_action
		label = p_label
		size = Vector2.ONE * radius * 2.0
		design_center = center
		position = center - size * 0.5
		mouse_filter = Control.MOUSE_FILTER_STOP

	func place(c: Vector2, vs: Vector2) -> void:
		if mode == "move":
			# The whole lower-left of the screen is the stick.
			position = Vector2(0.0, vs.y * 0.3)
			size = Vector2(minf(vs.x * 0.42, 560.0), vs.y - position.y)
			_home = c - position
			if _idx == -2:
				_origin = _home
		else:
			position = c - size * 0.5
		queue_redraw()

	func _clamp_origin(p: Vector2) -> Vector2:
		var m := TouchControls.STICK_R + 6.0
		return Vector2(clampf(p.x, m, maxf(size.x - m, m)), clampf(p.y, m, maxf(size.y - m, m)))

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
				_aim_peak = 0.0
			elif mode == "move":
				_origin = _clamp_origin(p)
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
		if mode == "move":
			r = TouchControls.STICK_R
			v = p - _origin
			if v.length() > r:   # thumb ran past the ring: drag the ring along with it
				_origin = _clamp_origin(_origin + v.normalized() * (v.length() - r))
				v = p - _origin
		if v.length() > r:
			v = v.normalized() * r
		_knob_target = v / r
		var dir := _shape(v / r)
		if mode == "move":
			TouchControls.set_action("move_left", maxf(-dir.x, 0.0))
			TouchControls.set_action("move_right", maxf(dir.x, 0.0))
			TouchControls.set_action("move_up", maxf(-dir.y, 0.0))
			TouchControls.set_action("move_down", maxf(dir.y, 0.0))
		elif mode == "aim" and (v / r).length() > TouchControls.AIM_MIN:
			_aim_peak = maxf(_aim_peak, (v / r).length())
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
				_origin = _home
			"aim":
				TouchControls.aim_active = false
				if _aim_peak >= TouchControls.AIM_FIRE_MIN:
					TouchControls.aim_fire = true      # release = shoot (locks onto the nearest enemy)
					TouchControls._aim_fire_t = 0.45
				_aim_peak = 0.0
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
			if mode == "move":
				c = _origin
				r = TouchControls.STICK_R
			draw_circle(c, r, Color(0.1, 0.1, 0.14, 0.3))
			draw_arc(c, r, 0.0, TAU, 48, Color(0.9, 0.9, 1.0, 0.35), 2.0)
			if mode == "aim":
				var af := ThemeDB.fallback_font
				var aw: float = af.get_string_size("AIM", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
				draw_string(af, c + Vector2(-aw * 0.5, r + 20.0), "AIM", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.7))
				draw_arc(c, r * 1.12, -PI * 0.5 - 0.6, -PI * 0.5 + 0.6, 12, Color(1.0, 0.8, 0.4, 0.5 if held else 0.25), 3.0)
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
