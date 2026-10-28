extends Node2D
## Projectile.gd — a glowing bolt shot by archers and bosses. Stops on walls, hurts the player.
## Rolling (dodge) lets it pass through.

const Fx := preload("res://Fx.gd")

var velocity: Vector2 = Vector2.ZERO
var damage: int = 10
var color: Color = Color(2.0, 0.6, 0.2)
var radius: float = 8.0
var life: float = 3.4

var _player: Node2D
var _t: float = 0.0


func _ready() -> void:
	z_index = 6
	material = Fx.glow_material()
	var light := PointLight2D.new()
	light.texture = Fx.light_texture()
	light.texture_scale = 0.55
	light.color = Color(minf(color.r, 1.0), minf(color.g, 1.0), minf(color.b, 1.0))
	light.energy = 0.9
	add_child(light)
	_player = get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var from: Vector2 = global_position
	var to: Vector2 = from + velocity * delta
	var q := PhysicsRayQueryParameters2D.create(from, to, 12)
	if not get_world_2d().direct_space_state.intersect_ray(q).is_empty():
		_pop()
		return
	global_position = to
	if is_instance_valid(_player) and not bool(_player.is_dead):
		if global_position.distance_to(_player.global_position) < radius + 16.0:
			if _player.take_damage(damage):
				_pop()
				return
	queue_redraw()


func _pop() -> void:
	Fx.burst(get_tree().current_scene, global_position, color, 8, 150.0, 0.3, 3.0, 180.0, Vector2.RIGHT, true)
	queue_free()


func _draw() -> void:
	var pulse: float = 1.0 + sin(_t * 18.0) * 0.12
	var dir: Vector2 = velocity.normalized()
	draw_line(-dir * 20.0, Vector2.ZERO, Color(color, 0.35), radius * 0.9)
	draw_circle(Vector2.ZERO, radius * 1.5 * pulse, Color(color, 0.25))
	draw_circle(Vector2.ZERO, radius * pulse, color)
	draw_circle(Vector2.ZERO, radius * 0.45, Color(2.2, 2.2, 2.2, 0.95))
