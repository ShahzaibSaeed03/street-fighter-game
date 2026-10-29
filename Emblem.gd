class_name Emblem
extends RefCounted
## Emblem.gd - the Dungeon Sneak crest: a shield with a watching eye and two crossed swords.
## Emblem.draw(canvas_item, centre, scale, time) draws it from vector shapes (no image files).
## Used by the splash screen and the main menu.

const GOLD := Color(0.96, 0.76, 0.3)
const GOLD_DARK := Color(0.55, 0.38, 0.12)
const STEEL := Color(0.82, 0.86, 0.92)
const STEEL_DARK := Color(0.38, 0.42, 0.52)


static func draw(ci: CanvasItem, c: Vector2, k: float, t: float = 0.0, glow: float = 1.0) -> void:
	# warm glow behind the crest
	for i in 5:
		ci.draw_circle(c, (62.0 + float(i) * 20.0) * k, Color(1.0, 0.62, 0.2, 0.045 * glow))
	# two crossed swords
	for s in [-1.0, 1.0]:
		var sd: float = s
		var d := Vector2(sd * 0.60, -0.80).normalized()   # direction from hilt to tip
		var p := d.rotated(PI * 0.5)
		var hilt: Vector2 = c - d * 52.0 * k
		var tip: Vector2 = c + d * 76.0 * k
		var guard: Vector2 = c - d * 30.0 * k
		ci.draw_colored_polygon(PackedVector2Array([guard + p * 5.5 * k, tip, guard - p * 5.5 * k]), STEEL_DARK)
		ci.draw_colored_polygon(PackedVector2Array([guard + p * 2.6 * k, tip, guard - p * 5.5 * k * 0.1]), STEEL)
		ci.draw_line(guard, tip - d * 6.0 * k, Color(1, 1, 1, 0.55), 1.4 * k)
		ci.draw_line(guard + p * 15.0 * k, guard - p * 15.0 * k, GOLD_DARK, 6.5 * k)
		ci.draw_line(guard + p * 14.0 * k, guard - p * 14.0 * k, GOLD, 4.0 * k)
		ci.draw_line(guard, hilt, Color(0.32, 0.18, 0.1), 6.0 * k)
		ci.draw_circle(hilt - d * 3.0 * k, 5.2 * k, GOLD_DARK)
		ci.draw_circle(hilt - d * 3.0 * k, 3.6 * k, GOLD)
	# shield
	var outline := PackedVector2Array([
		c + Vector2(-36, -42) * k, c + Vector2(0, -50) * k, c + Vector2(36, -42) * k,
		c + Vector2(38, 4) * k, c + Vector2(20, 36) * k, c + Vector2(0, 52) * k,
		c + Vector2(-20, 36) * k, c + Vector2(-38, 4) * k])
	ci.draw_colored_polygon(outline, GOLD_DARK)
	var inner := PackedVector2Array()
	for q in outline:
		inner.append(c + (q - c) * 0.9)
	ci.draw_colored_polygon(inner, GOLD)
	var inner2 := PackedVector2Array()
	for q in outline:
		inner2.append(c + (q - c) * 0.78)
	ci.draw_colored_polygon(inner2, Color(0.09, 0.08, 0.16))
	# upper half of the face a little lighter, for a gentle gradient
	ci.draw_colored_polygon(PackedVector2Array([inner2[0], inner2[1], inner2[2], c + Vector2(29, -6) * k, c + Vector2(-29, -6) * k]), Color(0.14, 0.12, 0.26))
	# the watching eye
	var eye := PackedVector2Array()
	for i in 21:
		var a: float = TAU * float(i) / 20.0
		eye.append(c + Vector2(cos(a) * 24.0, sin(a) * 11.0 * (1.0 - 0.15 * absf(cos(a)))) * k + Vector2(0, -2.0 * k))
	ci.draw_colored_polygon(eye, Color(0.95, 0.93, 0.85))
	ci.draw_polyline(eye, GOLD, 1.8 * k)
	var look: float = sin(t * 1.3) * 5.0
	var ic: Vector2 = c + Vector2(look, -2.0) * k
	var pulse: float = 0.5 + 0.5 * sin(t * 3.0)
	ci.draw_circle(ic, 9.5 * k, Color(0.15, 0.7, 0.35))
	ci.draw_circle(ic, 7.2 * k, Color(0.3 + 0.2 * pulse, 0.95, 0.5))
	ci.draw_colored_polygon(PackedVector2Array([ic + Vector2(0, -8) * k, ic + Vector2(2.2, 0) * k, ic + Vector2(0, 8) * k, ic + Vector2(-2.2, 0) * k]), Color(0.02, 0.05, 0.03))
	ci.draw_circle(ic + Vector2(-3, -3) * k, 1.8 * k, Color(1, 1, 1, 0.9))
	# gem under the eye
	var g: Vector2 = c + Vector2(0, 28) * k
	ci.draw_colored_polygon(PackedVector2Array([g + Vector2(0, -7) * k, g + Vector2(6, 0) * k, g + Vector2(0, 7) * k, g + Vector2(-6, 0) * k]), Color(1.0, 0.35 + 0.2 * pulse, 0.3))
