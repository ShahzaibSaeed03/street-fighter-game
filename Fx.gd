extends RefCounted
## Fx.gd — static helpers for particles, light textures, floating damage numbers and hit-stop.
## Usage:  const Fx := preload("res://Fx.gd")   then   Fx.burst(...)

static var _light_tex: GradientTexture2D
static var _glow_mat: CanvasItemMaterial
static var _unshaded_mat: CanvasItemMaterial


## Soft radial texture used by every PointLight2D.
static func light_texture() -> GradientTexture2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.45))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 512
		t.height = 512
		_light_tex = t
	return _light_tex


## Additive + unshaded material: sparks / eyes / embers that should glow in the dark.
static func glow_material() -> CanvasItemMaterial:
	if _glow_mat == null:
		_glow_mat = CanvasItemMaterial.new()
		_glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_glow_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _glow_mat


static func unshaded_material() -> CanvasItemMaterial:
	if _unshaded_mat == null:
		_unshaded_mat = CanvasItemMaterial.new()
		_unshaded_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unshaded_mat


## One-shot particle burst. `parent` must be at world origin (the Main node).
## dir + spread_deg describe the cone (spread 180 = full circle). glow = additive spark.
static func burst(parent: Node, pos: Vector2, color: Color, amount: int = 12,
		speed: float = 160.0, lifetime: float = 0.45, size: float = 3.0,
		spread_deg: float = 180.0, dir: Vector2 = Vector2.RIGHT, glow: bool = false) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.direction = dir if dir != Vector2.ZERO else Vector2.RIGHT
	p.spread = spread_deg
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.5
	p.damping_max = speed * 1.1
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = ramp
	p.z_index = 8
	p.position = pos
	if glow:
		p.material = glow_material()
	parent.add_child(p)
	p.emitting = true
	parent.get_tree().create_timer(lifetime + 0.4).timeout.connect(p.queue_free)


## Floating damage number that rises and fades.
static func damage_number(parent: Node, pos: Vector2, amount: int,
		color: Color = Color(1.0, 0.9, 0.4), prefix: String = "") -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var l := Label.new()
	l.text = prefix + str(amount)
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 6)
	l.z_index = 20
	l.material = unshaded_material()
	l.position = pos + Vector2(randf_range(-14.0, 14.0) - 8.0, -38.0)
	parent.add_child(l)
	var t := l.create_tween().set_parallel(true)
	t.tween_property(l, "position:y", l.position.y - 40.0, 0.65).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.3)
	t.chain().tween_callback(l.queue_free)


## Brief slow-motion freeze on impact. Uses a real-time timer so it always recovers.
static func hit_stop(tree: SceneTree, duration: float = 0.045, time_scale: float = 0.06) -> void:
	Engine.time_scale = time_scale
	tree.create_timer(duration, true, false, true).timeout.connect(
		func() -> void: Engine.time_scale = 1.0)
