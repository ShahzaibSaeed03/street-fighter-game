extends Node2D
## PowerUp.gd — a glowing orb. "haste": faster for a few seconds. "quiet": quieter steps for a few seconds.
## Created by Dungeon.gd: set kind BEFORE add_child().

const Fx := preload("res://Fx.gd")

var kind: String = "haste"
var _t: float = 0.0
var _taken: bool = false


func _color() -> Color:
	return Color(0.4, 1.4, 1.6) if kind == "haste" else Color(0.7, 0.6, 1.5)


func _ready() -> void:
	z_index = 3
	material = Fx.unshaded_material()


func _process(delta: float) -> void:
	if _taken:
		return
	_t += delta
	queue_redraw()
	var p = get_tree().get_first_node_in_group("player")
	if p == null or bool(p.get("is_dead")):
		return
	var pos: Vector2 = p.global_position
	if global_position.distance_to(pos) < 36.0:
		_taken = true
		p.call("grant_powerup", kind)
		Missions.add("powerups")
		var msg: String = "Haste! Faster for 6 seconds" if kind == "haste" else "Quiet steps for 8 seconds"
		get_tree().call_group("game_manager", "toast", msg)
		Audio.play("coin", -1.0, 0.02)
		queue_free()


func _draw() -> void:
	var c: Color = _color()
	var bob: float = sin(_t * 3.0) * 3.0
	draw_circle(Vector2(0.0, 14.0), 9.0, Color(0, 0, 0, 0.25))
	draw_circle(Vector2(0.0, bob), 20.0, Color(c.r, c.g, c.b, 0.18))
	draw_circle(Vector2(0.0, bob), 9.0, c)
	draw_circle(Vector2(-3.0, bob - 3.0), 3.0, Color(1, 1, 1, 0.8))
