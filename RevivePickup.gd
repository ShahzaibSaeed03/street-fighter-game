extends Node2D
## RevivePickup.gd: the one Revive Kit of a level, drawn as a glowing white-red cross.
## Game.gd collects it when the hero walks close. Kept for the whole level (not used up on pickup).

const Fx := preload("res://Fx.gd")

var _t: float = 0.0


func _ready() -> void:
	z_index = 3
	material = Fx.unshaded_material()  # stays bright in the dark arena


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var bob: float = sin(_t * 3.0) * 3.0
	var c := Vector2(0.0, bob)
	draw_circle(c, 20.0 + sin(_t * 4.0) * 2.0, Color(1.0, 0.3, 0.4, 0.22))
	draw_circle(c, 12.0, Color(0.9, 0.1, 0.15, 0.9))
	draw_rect(Rect2(c + Vector2(-8, -2.5), Vector2(16, 5)), Color(1.0, 0.97, 0.97))
	draw_rect(Rect2(c + Vector2(-2.5, -8), Vector2(5, 16)), Color(1.0, 0.97, 0.97))
