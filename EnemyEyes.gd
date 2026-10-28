extends Node2D
## EnemyEyes.gd — child of EnemyArt. Drawn with an additive, unshaded material so the eyes
## glow in the dark (and bloom when HDR 2D glow is on). Created in code by EnemyArt.gd.


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var art = get_parent()
	var c: Color = art.eye_color()
	draw_set_transform(Vector2.ZERO, art.get_angle(), Vector2.ONE)
	for side in [-1.0, 1.0]:
		var p := Vector2(18.5, 4.0 * side)
		draw_circle(p, 5.5, Color(c.r, c.g, c.b, 0.18))
		draw_circle(p, 3.0, Color(c.r, c.g, c.b, 0.9))
		draw_circle(p, 1.2, Color(2.2, 2.2, 2.2, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
