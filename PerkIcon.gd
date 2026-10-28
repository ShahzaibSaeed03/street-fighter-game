class_name PerkIcon
extends Control
## PerkIcon.gd: a small icon for each perk, drawn with shapes (no image files needed).
## Designed on a 48 px grid and scaled to whatever size it is given.

var perk_id: String = ""


## Build an icon for a perk id at px x px. It ignores the mouse, so it can sit on top of buttons.
static func make(id: String, px: float) -> PerkIcon:
	var ic := PerkIcon.new()
	ic.perk_id = id
	ic.custom_minimum_size = Vector2(px, px)
	ic.size = Vector2(px, px)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ic


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var c: Vector2 = size * 0.5
	var k: float = s / 48.0
	draw_circle(c, s * 0.5, Color(0.12, 0.12, 0.18, 0.95))
	draw_arc(c, s * 0.46, 0.0, TAU, 40, Color(0.95, 0.8, 0.35, 0.9), maxf(1.0, 2.0 * k))
	match perk_id:
		"light_feet":
			_icon_feet(c, k)
		"quick_roll":
			_icon_roll(c, k)
		"eagle_eye":
			_icon_eye(c, k)
		"second_wind":
			_icon_heart(c, k)
		"shield_breaker":
			_icon_shield(c, k)
		"iron_skin":
			_icon_plate(c, k)


# Two footprints, one slightly ahead: quiet steps.
func _icon_feet(c: Vector2, k: float) -> void:
	var col := Color(0.85, 0.9, 1.0)
	draw_circle(c + Vector2(-7, 6) * k, 6.5 * k, col)
	draw_circle(c + Vector2(-7, -5) * k, 3.2 * k, col)
	draw_circle(c + Vector2(8, -1) * k, 6.5 * k, col)
	draw_circle(c + Vector2(8, -12) * k, 3.2 * k, col)


# Circular arrow: a roll.
func _icon_roll(c: Vector2, k: float) -> void:
	var col := Color(0.6, 0.9, 1.0)
	draw_arc(c, 12.0 * k, -0.4, PI * 1.45, 28, col, maxf(1.0, 3.0 * k))
	var tip: Vector2 = c + Vector2.from_angle(PI * 1.45) * 12.0 * k
	var dir: Vector2 = Vector2.from_angle(PI * 1.45 + PI / 2.0)
	draw_colored_polygon(PackedVector2Array([tip + dir * 6.0 * k, tip - dir * 6.0 * k, tip + Vector2.from_angle(PI * 1.45) * 7.0 * k]), col)


# Almond-shaped eye with a pupil: sight.
func _icon_eye(c: Vector2, k: float) -> void:
	var pts := PackedVector2Array([
		c + Vector2(-16, 0) * k, c + Vector2(0, -10) * k, c + Vector2(16, 0) * k, c + Vector2(0, 10) * k])
	draw_colored_polygon(pts, Color(0.95, 0.95, 0.9))
	draw_circle(c, 5.0 * k, Color(0.2, 0.5, 0.2))
	draw_circle(c, 2.2 * k, Color(0.05, 0.05, 0.05))
	draw_circle(c + Vector2(-1.5, -1.5) * k, 1.0 * k, Color.WHITE)


# Heart: health.
func _icon_heart(c: Vector2, k: float) -> void:
	var col := Color(1.0, 0.35, 0.4)
	draw_circle(c + Vector2(-6, -3) * k, 6.5 * k, col)
	draw_circle(c + Vector2(6, -3) * k, 6.5 * k, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-12, -1) * k, c + Vector2(12, -1) * k, c + Vector2(0, 13) * k]), col)


# Shield with a crack: the block is broken.
func _icon_shield(c: Vector2, k: float) -> void:
	var pts := PackedVector2Array([
		c + Vector2(-12, -13) * k, c + Vector2(12, -13) * k, c + Vector2(12, 1) * k,
		c + Vector2(0, 14) * k, c + Vector2(-12, 1) * k])
	draw_colored_polygon(pts, Color(0.7, 0.75, 0.85))
	draw_line(c + Vector2(-3, -8) * k, c + Vector2(1, -1) * k, Color(0.2, 0.2, 0.25), maxf(1.0, 2.0 * k))
	draw_line(c + Vector2(1, -1) * k, c + Vector2(-2, 6) * k, Color(0.2, 0.2, 0.25), maxf(1.0, 2.0 * k))


# Armour plate with bands: tougher body.
func _icon_plate(c: Vector2, k: float) -> void:
	var steel := Color(0.75, 0.78, 0.85)
	draw_rect(Rect2(c + Vector2(-11, -12) * k, Vector2(22, 26) * k), steel)
	for y in [-4.0, 3.0]:
		draw_line(c + Vector2(-11, y) * k, c + Vector2(11, y) * k, Color(0.3, 0.32, 0.38), maxf(1.0, 2.0 * k))
	draw_line(c + Vector2(0, -12) * k, c + Vector2(0, 14) * k, Color(0.3, 0.32, 0.38), maxf(1.0, 2.0 * k))
