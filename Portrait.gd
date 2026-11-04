class_name HeroPortrait
extends Control
## Portrait.gd: hero face for menus — prefers baked shaded portrait sprites.

var _hero_id: String = "ayaan"
var hero_id: String:
	get:
		return _hero_id
	set(v):
		_hero_id = v
		_tex = null
		_loaded_id = ""
		queue_redraw()
var _tex: Texture2D = null
var _loaded_id: String = ""


func _normalize_id(id: String) -> String:
	match id:
		"jake", "ayaan":
			return "ayaan"
		"maya", "zara":
			return "zara"
		"marcus", "kabir":
			return "kabir"
		_:
			return "ayaan"


func _ensure_tex() -> void:
	var nid := _normalize_id(_hero_id)
	if nid == _loaded_id and _tex != null:
		return
	_loaded_id = nid
	var path := "res://assets/heroes/%s_portrait.png" % nid
	_tex = load(path) if ResourceLoader.exists(path) else null


func _draw() -> void:
	_ensure_tex()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.10, 0.16))
	if _tex != null:
		var tex_sz := _tex.get_size()
		var s: float = minf(size.x / tex_sz.x, size.y / tex_sz.y)
		var draw_sz := tex_sz * s
		var origin := (size - draw_sz) * 0.5
		draw_texture_rect(_tex, Rect2(origin, draw_sz), false)
		return
	_draw_fallback()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _ell(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * float(i) / 28.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _draw_fallback() -> void:
	var k := minf(size.x, size.y) / 200.0
	var c := size * 0.5
	var skin: Color
	var hair: Color
	var style: String
	var outfit: Color
	match _normalize_id(_hero_id):
		"zara":
			skin = Color(0.62, 0.42, 0.30)
			hair = Color(0.10, 0.06, 0.04)
			style = "long"
			outfit = Color(0.20, 0.55, 0.35)
		"kabir":
			skin = Color(0.52, 0.36, 0.26)
			hair = Color(0.08, 0.06, 0.05)
			style = "buzz"
			outfit = Color(0.15, 0.25, 0.60)
		_:
			skin = Color(0.88, 0.70, 0.55)
			hair = Color(0.32, 0.20, 0.10)
			style = "short"
			outfit = Color(0.66, 0.10, 0.15)
	var face := c + Vector2(0, -k * 8)
	_ell(c + Vector2(0, k * 92), k * 78, k * 44, outfit)
	draw_rect(Rect2(c + Vector2(-k * 17, k * 28), Vector2(k * 34, k * 44)), skin)
	if style == "long":
		_ell(face + Vector2(0, k * 26), k * 56, k * 64, hair)
	_ell(face, k * 46, k * 54, skin)
	if style == "buzz":
		draw_arc(face, k * 46, PI * 1.08, PI * 1.92, 24, hair, k * 12.0)
	elif style == "short":
		_ell(face + Vector2(0, -k * 22), k * 50, k * 30, hair)
	else:
		_ell(face + Vector2(0, -k * 24), k * 50, k * 30, hair)
		_ell(face + Vector2(-k * 40, k * 4), k * 14, k * 40, hair)
		_ell(face + Vector2(k * 40, k * 4), k * 14, k * 40, hair)
	for sx in [-1.0, 1.0]:
		var e := face + Vector2(sx * k * 18.0, k * 2.0)
		_ell(e, k * 9.0, k * 6.0, Color(0.96, 0.96, 0.98))
		draw_circle(e, k * 4.2, Color(0.12, 0.08, 0.06))
		draw_line(e + Vector2(-k * 9, -k * 11), e + Vector2(k * 9, -k * 13 + sx * k * 2), hair, k * 3.0)
	draw_line(face + Vector2(0, k * 8), face + Vector2(-k * 3, k * 22), skin.darkened(0.25), k * 2.5)
	draw_arc(face + Vector2(0, k * 30), k * 14.0, 0.25, PI - 0.25, 14, Color(0.45, 0.18, 0.18), k * 3.0)
