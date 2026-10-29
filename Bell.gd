extends Node2D
## Bell.gd — a bell. Stand next to it and press E to ring it. Every guard close enough hears it and
## walks over to look at the bell. A few charges per level, with a short cooldown between rings.
## Created by Dungeon.gd: set the position, then add_child().

const Fx := preload("res://Fx.gd")
const RANGE := 60.0          # how close you must stand to ring it
const COOLDOWN := 10.0       # seconds between rings
const HEAR := 700.0          # guards this close (pixels) hear the bell

var charges: int = 3
var _cd: float = 0.0
var _swing: float = 0.0
var _t: float = 0.0
var _near_t: float = 0.0


func _ready() -> void:
	z_index = 2


func _process(delta: float) -> void:
	_t += delta
	_cd = maxf(_cd - delta, 0.0)
	_swing = maxf(_swing - delta * 2.0, 0.0)
	queue_redraw()
	if charges <= 0 or _cd > 0.0:
		return
	var p = get_tree().get_first_node_in_group("player")
	if p == null or bool(p.get("is_dead")):
		return
	var pos: Vector2 = p.global_position
	if global_position.distance_to(pos) > RANGE:
		_near_t = 0.0
		return
	_near_t += delta
	var touch: bool = TouchControls.is_touch
	get_tree().call_group("game_manager", "show_hint", "Stand here to ring the bell" if touch else "Press E to ring the bell")
	# phones have no E button: standing next to the bell for a moment rings it
	if Input.is_action_just_pressed("interact") or (touch and _near_t > 0.8):
		_near_t = 0.0
		_ring()


func _ring() -> void:
	charges -= 1
	_cd = COOLDOWN
	_swing = 1.0
	Missions.add("bells")
	Audio.play("gate", -2.0, 0.0)
	get_tree().call_group("game_manager", "shake", 4.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_method("hear_noise") and global_position.distance_to(e.global_position) < HEAR:
			e.hear_noise(global_position)
	get_tree().call_group("game_manager", "toast", "The bell rings!  (%d left)" % charges)
	Fx.burst(get_tree().current_scene, global_position, Color(1.0, 0.85, 0.4), 12, 180.0, 0.5, 3.0, 120.0, Vector2.UP, true)


func _draw() -> void:
	var sw: float = sin(_swing * 6.0) * 0.4 * _swing
	var c: Color = Color(0.85, 0.65, 0.25) if charges > 0 else Color(0.4, 0.35, 0.3)
	draw_circle(Vector2(0.0, 16.0), 14.0, Color(0, 0, 0, 0.25))            # shadow
	draw_rect(Rect2(-16.0, -26.0, 32.0, 6.0), Color(0.3, 0.22, 0.12))       # frame
	# the bell itself swings from its top when rung
	draw_set_transform(Vector2(0.0, -20.0), sw, Vector2.ONE)
	draw_circle(Vector2(0.0, 4.0), 12.0, c)
	draw_rect(Rect2(-14.0, 4.0, 28.0, 12.0), c)
	draw_circle(Vector2(0.0, 20.0), 3.0, Color(0.25, 0.18, 0.1))           # clapper
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if charges > 0:
		draw_string(ThemeDB.fallback_font, Vector2(-5.0, -34.0), str(charges), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(1.0, 0.9, 0.6))
