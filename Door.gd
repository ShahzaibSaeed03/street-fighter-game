extends StaticBody2D
## Door.gd — a locked door. Walk up with the matching key and it opens by itself.
## Created by Dungeon.gd: set key_id / door_size BEFORE add_child().

const Fx := preload("res://Fx.gd")

var key_id: String = "bronze"
var door_size: Vector2 = Vector2(22.0, 150.0)

var _open: bool = false
var _player: Node2D
var _t: float = 0.0


func _key_color() -> Color:
	if key_id == "gold":
		return Color(1.0, 0.82, 0.25)
	return Color(0.85, 0.5, 0.22)


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	z_index = 2
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = door_size
	cs.shape = rect
	cs.name = "Shape"
	add_child(cs)
	var light := PointLight2D.new()
	light.texture = Fx.light_texture()
	light.texture_scale = 0.7
	light.color = _key_color()
	light.energy = 0.9
	add_child(light)
	_player = get_tree().get_first_node_in_group("player") as Node2D


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _open:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	if global_position.distance_to(_player.global_position) < 125.0:
		if _player.keys.has(key_id):
			_unlock()
		else:
			get_tree().call_group("game_manager", "show_hint", "Locked door - you need the %s key" % key_id.to_upper())


func _unlock() -> void:
	_open = true
	$Shape.set_deferred("disabled", true)
	Audio.play("gate", -2.0, 0.0)
	get_tree().call_group("game_manager", "toast", "Door unlocked!")
	Fx.burst(get_tree().current_scene, global_position, _key_color(), 18, 220.0, 0.6, 3.0, 180.0, Vector2.UP, true)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)


func _draw() -> void:
	var r := Rect2(-door_size * 0.5, door_size)
	var kc: Color = _key_color()
	draw_rect(r, Color(0.14, 0.14, 0.17))
	draw_rect(r.grow(-3.0), Color(0.24, 0.24, 0.29))
	var vertical: bool = door_size.y > door_size.x
	for i in 5:
		var f: float = (float(i) + 0.5) / 5.0
		if vertical:
			var y: float = r.position.y + f * r.size.y
			draw_line(Vector2(r.position.x + 3.0, y), Vector2(r.end.x - 3.0, y), Color(0, 0, 0, 0.45), 2.0)
		else:
			var x: float = r.position.x + f * r.size.x
			draw_line(Vector2(x, r.position.y + 3.0), Vector2(x, r.end.y - 3.0), Color(0, 0, 0, 0.45), 2.0)
	draw_rect(r, kc, false, 3.0)
	# padlock
	var pulse: float = 1.0 + sin(_t * 4.0) * 0.08
	draw_circle(Vector2.ZERO, 13.0 * pulse, Color(kc, 0.25))
	draw_rect(Rect2(Vector2(-8.0, -3.0), Vector2(16.0, 13.0)), kc)
	draw_arc(Vector2(0.0, -3.0), 6.0, PI, TAU, 12, kc, 3.0)
	draw_circle(Vector2(0.0, 3.5), 2.0, Color(0.1, 0.07, 0.03))
