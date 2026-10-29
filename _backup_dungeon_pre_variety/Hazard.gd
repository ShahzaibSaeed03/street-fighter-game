extends Node2D
## Hazard.gd — floor dangers. kind "spikes": retract, warn, then stab (one hit per stab).
## kind "pool": lava / void rift that burns while you stand in it. Rolling does not help in pools
## for long, so walk around them. Created by Dungeon.gd.

const Fx := preload("res://Fx.gd")

var kind: String = "spikes"
var size: Vector2 = Vector2(60.0, 60.0)
var color: Color = Color(0.9, 0.3, 0.1)
var damage: int = 12
var phase: float = 0.0

const CYCLE := 3.2
const WARN_AT := 1.9
const UP_AT := 2.4

var _t: float = 0.0
var _player: Node2D
var _tick: float = 0.0
var _hit_this_stab: bool = false
var _stab: float = 0.0     # 0 = hidden, 1 = fully out


func _ready() -> void:
	z_index = 1
	material = Fx.unshaded_material()
	_t = phase
	var light := PointLight2D.new()
	light.texture = Fx.light_texture()
	light.texture_scale = maxf(size.x, size.y) / 150.0 + 0.3
	light.color = Color(minf(color.r, 1.0), minf(color.g, 1.0), minf(color.b, 1.0))
	light.energy = 0.7 if kind == "pool" else 0.0
	if kind == "pool" and color.r < 0.9 and color.g < 0.9:
		light.energy = 0.45
	add_child(light)


func _inside() -> bool:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return false
	var d: Vector2 = (_player.global_position - global_position).abs()
	return d.x < size.x * 0.5 + 6.0 and d.y < size.y * 0.5 + 6.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _player != null and bool(_player.is_dead):
		return
	if kind == "sand":
		if _inside():
			_player.slow_timer = 0.25
		return
	if kind == "pool":
		_tick -= delta
		if _tick <= 0.0 and _inside():
			if _player.take_damage(damage):
				_tick = 0.55
		return
	# spikes
	var c: float = fposmod(_t, CYCLE)
	if c < WARN_AT:
		_stab = move_toward(_stab, 0.0, delta * 6.0)
		_hit_this_stab = false
	elif c < UP_AT:
		_stab = 0.22 + 0.06 * sin(_t * 40.0)
	else:
		_stab = move_toward(_stab, 1.0, delta * 14.0)
		if not _hit_this_stab and _stab > 0.6 and _inside():
			if _player.take_damage(damage):
				_hit_this_stab = true
				Fx.burst(get_tree().current_scene, global_position, color, 8, 140.0, 0.3, 3.0)


func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	if kind == "sand":
		draw_rect(r.grow(4.0), Color(0.12, 0.08, 0.04))
		draw_rect(r, Color(color.r * 0.55, color.g * 0.5, color.b * 0.4))
		for ring in 4:
			var rr: float = (0.22 + float(ring) * 0.2) * minf(size.x, size.y)
			draw_arc(Vector2.ZERO, rr, _t * 0.6 + float(ring), _t * 0.6 + float(ring) + 4.2, 18, Color(0.15, 0.1, 0.05, 0.6), 3.0)
		draw_rect(r.grow(4.0), Color(0.55, 0.4, 0.2, 0.7), false, 2.0)
		return
	if kind == "pool":
		var p: float = 0.5 + 0.5 * sin(_t * 2.5)
		draw_rect(r.grow(5.0), Color(0.03, 0.02, 0.03))
		draw_rect(r, Color(color.r * (0.6 + 0.3 * p), color.g * (0.6 + 0.3 * p), color.b * (0.6 + 0.3 * p)))
		draw_rect(r.grow(-8.0), Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, 0.9))
		for i in 5:
			var s: float = float(i) * 1.7
			var bp := Vector2(sin(_t * 0.9 + s) * size.x * 0.32, cos(_t * 0.7 + s * 1.3) * size.y * 0.28)
			draw_circle(bp, 5.0 + 3.0 * sin(_t * 3.0 + s), Color(2.0, 1.6, 1.2, 0.55))
		draw_rect(r.grow(5.0), Color(color.r * 1.8, color.g * 1.8, color.b * 1.8, 0.8), false, 2.0)
		return
	# spikes
	draw_rect(r, Color(0.08, 0.08, 0.1))
	draw_rect(r.grow(-3.0), Color(0.16, 0.16, 0.19))
	var cols: int = maxi(2, int(size.x / 22.0))
	var rows: int = maxi(2, int(size.y / 22.0))
	var warn: bool = fposmod(_t, CYCLE) >= WARN_AT and fposmod(_t, CYCLE) < UP_AT
	for iy in rows:
		for ix in cols:
			var cp := Vector2(r.position.x + (float(ix) + 0.5) * size.x / float(cols),
					r.position.y + (float(iy) + 0.5) * size.y / float(rows))
			draw_circle(cp, 3.5, Color(0, 0, 0, 0.7))
			if _stab > 0.02:
				var h: float = 15.0 * _stab
				var col: Color = Color(1.0, 0.35, 0.3) if warn else color
				draw_colored_polygon(PackedVector2Array([cp + Vector2(-5.0, 3.0), cp + Vector2(5.0, 3.0), cp + Vector2(0.0, 3.0 - h)]), col)
	if warn:
		draw_rect(r, Color(1.0, 0.2, 0.15, 0.55), false, 2.0)
