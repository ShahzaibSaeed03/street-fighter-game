extends Node2D
## Loot.gd — coins and arrow bundles on the floor. They fly toward the hero when close.
## kind: "coin" or "arrows". Placed loot waits forever; dropped loot expires after a while.

const Fx := preload("res://Fx.gd")
const SaveScript := preload("res://Save.gd")

var kind: String = "coin"
var value: int = 5
var persistent: bool = true
var scatter: Vector2 = Vector2.ZERO      # initial pop velocity for dropped loot

var _player: Node2D
var _age: float = 0.0
var _vel: Vector2 = Vector2.ZERO
var _done: bool = false
var _phase: float = randf() * TAU


func _ready() -> void:
	z_index = 3
	material = Fx.unshaded_material()
	_vel = scatter
	_player = get_tree().get_first_node_in_group("player") as Node2D


func _process(delta: float) -> void:
	if _done:
		return
	_age += delta
	if not persistent and _age > 26.0:
		queue_free()
		return
	position += _vel * delta
	_vel = _vel.move_toward(Vector2.ZERO, 520.0 * delta)
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	elif not bool(_player.is_dead):
		var d: float = global_position.distance_to(_player.global_position)
		if kind == "arrows" and int(_player.ammo) >= int(_player.max_ammo):
			d = 9999.0
		if d < 140.0 and _age > 0.25:
			global_position = global_position.move_toward(_player.global_position, (200.0 + (140.0 - d) * 3.0) * delta)
		if d < 30.0 and _age > 0.15:
			_collect()
	queue_redraw()


func _collect() -> void:
	_done = true
	var root := get_tree().current_scene
	if kind == "coin":
		SaveScript.coins += value
		Audio.play("coin", -4.0, 0.08)
		Fx.damage_number(root, global_position, value, Color(1.0, 0.85, 0.25), "+")
		Fx.burst(root, global_position, Color(2.0, 1.6, 0.4), 6, 120.0, 0.3, 2.5, 180.0, Vector2.UP, true)
	else:
		_player.add_ammo(value)
		Audio.play("heal", -8.0, 0.2)
		Fx.damage_number(root, global_position, value, Color(0.8, 0.95, 1.0), "+arrows ")
	queue_free()


func _draw() -> void:
	var bob: float = sin(_age * 4.0 + _phase) * 2.0
	if kind == "coin":
		var w: float = absf(cos(_age * 3.0 + _phase))
		draw_circle(Vector2(0, 10), 7.0, Color(0, 0, 0, 0.25))
		var pts := PackedVector2Array()
		for i in 16:
			var a: float = TAU * float(i) / 16.0
			pts.append(Vector2(cos(a) * 8.0 * maxf(w, 0.25), sin(a) * 8.0 + bob))
		draw_colored_polygon(pts, Color(1.7, 1.25, 0.25))
		var pts2 := PackedVector2Array()
		for i in 16:
			var a2: float = TAU * float(i) / 16.0
			pts2.append(Vector2(cos(a2) * 5.0 * maxf(w, 0.25), sin(a2) * 5.0 + bob))
		draw_colored_polygon(pts2, Color(2.0, 1.7, 0.6))
	else:
		draw_circle(Vector2(0, 10), 9.0, Color(0, 0, 0, 0.25))
		for i in 3:
			var o: float = float(i - 1) * 4.0
			draw_line(Vector2(-10.0, o + bob), Vector2(9.0, o + bob), Color(0.6, 0.45, 0.25), 2.0)
			draw_colored_polygon(PackedVector2Array([Vector2(9, o - 2.5 + bob), Vector2(15, o + bob), Vector2(9, o + 2.5 + bob)]), Color(0.85, 0.9, 1.0))
			draw_line(Vector2(-10.0, o + bob), Vector2(-13.0, o - 2.5 + bob), Color(1, 1, 1, 0.9), 1.3)
		draw_line(Vector2(-4.0, -8.0 + bob), Vector2(-4.0, 8.0 + bob), Color(0.4, 0.28, 0.14), 2.5)
