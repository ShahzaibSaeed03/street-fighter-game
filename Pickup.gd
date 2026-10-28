extends Node2D
## Pickup.gd — a glowing heart dropped by enemies. Walk over it to heal.
## It is pulled toward the player when they are close AND hurt; if the player is at full
## health it just waits (and blinks out after LIFETIME seconds). Created in code by Enemy.gd.

const Fx := preload("res://Fx.gd")

const HEAL_AMOUNT := 20
const LIFETIME := 12.0
const PICKUP_RADIUS := 34.0
const MAGNET_RADIUS := 120.0
const MAGNET_SPEED := 260.0

var _age: float = 0.0
var _player: Node2D
var _collected: bool = false
var persistent: bool = false   # room hearts stay until collected
var heal_amount: int = HEAL_AMOUNT


func _ready() -> void:
	z_index = 3
	material = Fx.unshaded_material()  # stays bright in the dark arena
	_player = get_tree().get_first_node_in_group("player") as Node2D
	scale = Vector2(0.2, 0.2)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _collected:
		return
	_age += delta
	if not persistent and _age >= LIFETIME:
		queue_free()
		return

	if is_instance_valid(_player) and not _player.is_dead and _player.health < _player.max_health:
		var d: float = global_position.distance_to(_player.global_position)
		if d < MAGNET_RADIUS:
			global_position = global_position.move_toward(_player.global_position, MAGNET_SPEED * delta)
		if d < PICKUP_RADIUS:
			_collect()
			return
	queue_redraw()


func _collect() -> void:
	_collected = true
	_player.heal(heal_amount)
	Audio.play("heal", -3.0, 0.04)
	var root := get_tree().current_scene
	Fx.burst(root, global_position, Color(0.6, 2.0, 0.9), 14, 200.0, 0.5, 3.0, 180.0, Vector2.UP, true)
	Fx.damage_number(root, _player.global_position, heal_amount, Color(0.45, 1.0, 0.55), "+")
	queue_free()


func _draw() -> void:
	# blink during the last 3 seconds
	if not persistent and _age > LIFETIME - 3.0 and int(_age * 8.0) % 2 == 0:
		return
	var bob := sin(_age * 4.0) * 3.0
	var pulse := 1.0 + sin(_age * 6.0) * 0.08
	var c := Vector2(0.0, bob)

	# ground shadow + soft glow
	draw_circle(Vector2(0.0, 14.0), 8.0, Color(0, 0, 0, 0.25))
	draw_circle(c, 17.0 * pulse, Color(1.0, 0.2, 0.3, 0.16))

	# heart = two lobes + a triangle
	var red := Color(1.6, 0.18, 0.28)
	draw_circle(c + Vector2(-5.0, -3.0), 6.4, red)
	draw_circle(c + Vector2(5.0, -3.0), 6.4, red)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-10.8, -0.5), c + Vector2(10.8, -0.5), c + Vector2(0.0, 12.5)]), red)
	draw_circle(c + Vector2(-6.0, -5.0), 2.2, Color(1, 1, 1, 0.65))  # shine
