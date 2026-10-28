extends Node2D
## Arrow.gd — an arrow shot by the player. Flies straight, stops on walls and props.
## Hitting an enemy that has NOT noticed you does 2.5x damage (sneak shot).

const Fx := preload("res://Fx.gd")

var velocity: Vector2 = Vector2.RIGHT * 600.0
var damage: int = 14
var pierce: int = 0
var color: Color = Color(1.4, 1.3, 1.0)
var life: float = 1.3

var _hit: Array = []


func _ready() -> void:
	z_index = 6
	material = Fx.unshaded_material()
	rotation = velocity.angle()
	if color.r > 1.5 or color.g > 1.5 or color.b > 1.5:
		var light := PointLight2D.new()
		light.texture = Fx.light_texture()
		light.texture_scale = 0.6
		light.color = Color(minf(color.r, 1.0), minf(color.g, 1.0), minf(color.b, 1.0))
		light.energy = 0.8
		add_child(light)


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var from: Vector2 = global_position
	var to: Vector2 = from + velocity * delta
	var q := PhysicsRayQueryParameters2D.create(from, to, 12)
	if not get_world_2d().direct_space_state.intersect_ray(q).is_empty():
		Fx.burst(get_tree().current_scene, from, Color(0.8, 0.75, 0.6), 5, 90.0, 0.25, 2.5)
		queue_free()
		return
	global_position = to
	var dir: Vector2 = velocity.normalized()
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or _hit.has(e):
			continue
		var reach: float = 30.0 if bool(e.get("is_boss")) else 22.0
		if global_position.distance_to(e.global_position) > reach:
			continue
		_hit.append(e)
		var mult: float = 1.0
		if int(e.get("state")) != 2:
			mult = 2.5
			get_tree().call_group("game_manager", "toast", "Sneak shot!")
		e.take_damage(int(float(damage) * mult), global_position - dir * 12.0, 200.0)
		if pierce <= 0:
			queue_free()
			return
		pierce -= 1


func _draw() -> void:
	draw_line(Vector2(-22.0, 0.0), Vector2(6.0, 0.0), Color(0.55, 0.4, 0.22), 2.4)
	draw_colored_polygon(PackedVector2Array([Vector2(6, -3.5), Vector2(15, 0), Vector2(6, 3.5)]), color)
	draw_line(Vector2(-22.0, 0.0), Vector2(-26.0, -4.0), Color(0.9, 0.9, 0.9, 0.9), 1.6)
	draw_line(Vector2(-22.0, 0.0), Vector2(-26.0, 4.0), Color(0.9, 0.9, 0.9, 0.9), 1.6)
	if color.r > 1.5 or color.g > 1.5 or color.b > 1.5:
		draw_line(Vector2(-30.0, 0.0), Vector2(4.0, 0.0), Color(color, 0.35), 5.0)
