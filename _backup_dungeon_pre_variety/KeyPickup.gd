extends Node2D
## KeyPickup.gd — a glowing key. Walk over it to pick it up. Kinds: "bronze" | "gold".
## Created by Dungeon.gd: set kind BEFORE add_child().

const Fx := preload("res://Fx.gd")

var kind: String = "bronze"

var _t: float = 0.0
var _player: Node2D
var _taken: bool = false


func _color() -> Color:
	if kind == "gold":
		return Color(1.7, 1.4, 0.35)
	return Color(1.5, 0.85, 0.4)


func _ready() -> void:
	z_index = 3
	material = Fx.unshaded_material()
	var light := PointLight2D.new()
	light.texture = Fx.light_texture()
	light.texture_scale = 0.9
	light.color = _color().clamp(Color(0, 0, 0), Color(1, 1, 1))
	light.energy = 1.1
	add_child(light)
	_player = get_tree().get_first_node_in_group("player") as Node2D


func _process(delta: float) -> void:
	if _taken:
		return
	_t += delta
	queue_redraw()
	if is_instance_valid(_player) and not _player.is_dead \
			and global_position.distance_to(_player.global_position) < 36.0:
		_take()


func _take() -> void:
	_taken = true
	if not _player.keys.has(kind):
		_player.keys.append(kind)
	Audio.play("coin", -1.0, 0.02)
	Fx.burst(get_tree().current_scene, global_position, _color(), 16, 200.0, 0.6, 3.0, 180.0, Vector2.UP, true)
	get_tree().call_group("game_manager", "on_key", kind)
	queue_free()


func _draw() -> void:
	var c: Color = _color()
	var bob: float = sin(_t * 3.0) * 4.0
	var o := Vector2(0.0, bob)
	draw_circle(Vector2(0.0, 14.0), 9.0, Color(0, 0, 0, 0.25))
	draw_circle(o, 22.0 + sin(_t * 5.0) * 2.0, Color(c.r, c.g, c.b, 0.12))
	# key: ring + shaft + teeth
	draw_arc(o + Vector2(-9.0, 0.0), 6.5, 0.0, TAU, 18, c, 3.5)
	draw_line(o + Vector2(-2.5, 0.0), o + Vector2(13.0, 0.0), c, 3.5)
	draw_line(o + Vector2(9.0, 0.0), o + Vector2(9.0, 6.0), c, 3.0)
	draw_line(o + Vector2(13.0, 0.0), o + Vector2(13.0, 5.0), c, 3.0)
