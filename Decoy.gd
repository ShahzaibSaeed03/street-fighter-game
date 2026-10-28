extends Node2D
## Thrown noise decoy. It flies a short way, lands with a clink, and draws every
## nearby guard who is not already chasing you to come and check the spot.

const RANGE := 300.0
const FLY_TIME := 0.32
const NOISE_RADIUS := 430.0
const RING_TIME := 1.1

var _vel := Vector2.ZERO
var _t := 0.0
var _landed := false


func setup(from: Vector2, dir: Vector2) -> void:
	global_position = from
	_vel = dir.normalized() * (RANGE / FLY_TIME)


func _physics_process(delta: float) -> void:
	_t += delta
	if not _landed:
		position += _vel * delta
		if _t >= FLY_TIME:
			_landed = true
			_t = 0.0
			_land()
	elif _t >= RING_TIME:
		queue_free()
	queue_redraw()


func _land() -> void:
	Audio.play("click", -2.0, 0.1)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("hear_noise") and global_position.distance_to(e.global_position) < NOISE_RADIUS:
			e.hear_noise(global_position)


func _draw() -> void:
	if not _landed:
		draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.9, 0.5, 0.9))
		return
	var k := clampf(_t / RING_TIME, 0.0, 1.0)
	draw_arc(Vector2.ZERO, 14.0 + k * NOISE_RADIUS * 0.35, 0.0, TAU, 48, Color(1.0, 0.9, 0.5, 0.45 * (1.0 - k)), 2.0)
	draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.85, 0.4, 1.0 - k))
