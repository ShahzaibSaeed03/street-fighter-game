extends CPUParticles2D
## Weather.gd — ambient particles that suit the level: dust, fireflies, sand, embers, snow, motes.
## Game.gd moves it to the centre of the current room.

const Fx := preload("res://Fx.gd")


func configure(kind: String) -> void:
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emission_rect_extents = Vector2(580.0, 330.0)
	local_coords = false
	z_index = 8
	spread = 180.0
	gravity = Vector2.ZERO
	var ramp := Gradient.new()
	match kind:
		"fireflies":
			amount = 36
			lifetime = 7.0
			initial_velocity_min = 6.0
			initial_velocity_max = 22.0
			scale_amount_min = 1.6
			scale_amount_max = 3.0
			ramp.set_color(0, Color(1.6, 2.0, 0.5, 0.0))
			ramp.add_point(0.3, Color(1.6, 2.0, 0.5, 0.9))
			ramp.set_color(1, Color(1.6, 2.0, 0.5, 0.0))
			material = Fx.glow_material()
		"sand":
			amount = 140
			lifetime = 3.2
			direction = Vector2(1.0, 0.12)
			spread = 8.0
			initial_velocity_min = 170.0
			initial_velocity_max = 280.0
			scale_amount_min = 1.0
			scale_amount_max = 2.2
			ramp.set_color(0, Color(0.95, 0.78, 0.5, 0.0))
			ramp.add_point(0.2, Color(0.95, 0.78, 0.5, 0.35))
			ramp.set_color(1, Color(0.95, 0.78, 0.5, 0.0))
			material = Fx.unshaded_material()
		"embers":
			amount = 70
			lifetime = 4.0
			direction = Vector2(0.0, -1.0)
			spread = 25.0
			initial_velocity_min = 25.0
			initial_velocity_max = 70.0
			gravity = Vector2(0.0, -6.0)
			scale_amount_min = 1.4
			scale_amount_max = 3.0
			ramp.set_color(0, Color(2.2, 0.9, 0.2, 0.9))
			ramp.set_color(1, Color(1.5, 0.3, 0.05, 0.0))
			material = Fx.glow_material()
		"snow":
			amount = 130
			lifetime = 6.5
			direction = Vector2(0.25, 1.0)
			spread = 14.0
			initial_velocity_min = 35.0
			initial_velocity_max = 80.0
			scale_amount_min = 1.4
			scale_amount_max = 3.2
			ramp.set_color(0, Color(1, 1, 1, 0.0))
			ramp.add_point(0.15, Color(1, 1, 1, 0.75))
			ramp.set_color(1, Color(1, 1, 1, 0.0))
			material = Fx.unshaded_material()
		"ash":
			amount = 90
			lifetime = 7.0
			direction = Vector2(0.3, 1.0)
			spread = 20.0
			initial_velocity_min = 14.0
			initial_velocity_max = 40.0
			scale_amount_min = 1.2
			scale_amount_max = 2.8
			ramp.set_color(0, Color(0.7, 0.68, 0.66, 0.0))
			ramp.add_point(0.2, Color(0.7, 0.68, 0.66, 0.5))
			ramp.set_color(1, Color(0.7, 0.68, 0.66, 0.0))
			material = Fx.unshaded_material()
		"spores":
			amount = 55
			lifetime = 8.0
			initial_velocity_min = 4.0
			initial_velocity_max = 16.0
			gravity = Vector2(0.0, -3.0)
			scale_amount_min = 1.6
			scale_amount_max = 3.6
			ramp.set_color(0, Color(0.6, 1.6, 0.5, 0.0))
			ramp.add_point(0.4, Color(0.6, 1.6, 0.5, 0.7))
			ramp.set_color(1, Color(0.6, 1.6, 0.5, 0.0))
			material = Fx.glow_material()
		"sparks":
			amount = 60
			lifetime = 1.6
			initial_velocity_min = 80.0
			initial_velocity_max = 200.0
			gravity = Vector2(0.0, 120.0)
			scale_amount_min = 1.0
			scale_amount_max = 2.4
			ramp.set_color(0, Color(2.4, 1.6, 0.5, 1.0))
			ramp.set_color(1, Color(1.6, 0.4, 0.1, 0.0))
			material = Fx.glow_material()
		"bubbles":
			amount = 50
			lifetime = 6.0
			direction = Vector2(0.0, -1.0)
			spread = 12.0
			initial_velocity_min = 20.0
			initial_velocity_max = 50.0
			scale_amount_min = 1.6
			scale_amount_max = 4.0
			ramp.set_color(0, Color(0.6, 1.3, 1.7, 0.0))
			ramp.add_point(0.3, Color(0.6, 1.3, 1.7, 0.6))
			ramp.set_color(1, Color(0.6, 1.3, 1.7, 0.0))
			material = Fx.glow_material()
		"petals":
			amount = 45
			lifetime = 7.0
			direction = Vector2(0.4, 1.0)
			spread = 25.0
			initial_velocity_min = 15.0
			initial_velocity_max = 40.0
			scale_amount_min = 2.0
			scale_amount_max = 3.6
			ramp.set_color(0, Color(1.0, 0.7, 0.8, 0.0))
			ramp.add_point(0.2, Color(1.0, 0.7, 0.8, 0.8))
			ramp.set_color(1, Color(1.0, 0.7, 0.8, 0.0))
			material = Fx.unshaded_material()
		"motes":
			amount = 50
			lifetime = 8.0
			initial_velocity_min = 5.0
			initial_velocity_max = 18.0
			gravity = Vector2(0.0, -4.0)
			scale_amount_min = 1.4
			scale_amount_max = 3.0
			ramp.set_color(0, Color(1.4, 0.5, 2.0, 0.0))
			ramp.add_point(0.4, Color(1.4, 0.5, 2.0, 0.8))
			ramp.set_color(1, Color(1.4, 0.5, 2.0, 0.0))
			material = Fx.glow_material()
		_:  # dust
			amount = 40
			lifetime = 9.0
			direction = Vector2(1.0, 0.2)
			spread = 60.0
			initial_velocity_min = 5.0
			initial_velocity_max = 14.0
			scale_amount_min = 1.0
			scale_amount_max = 2.0
			ramp.set_color(0, Color(0.85, 0.85, 0.95, 0.0))
			ramp.add_point(0.3, Color(0.85, 0.85, 0.95, 0.22))
			ramp.set_color(1, Color(0.85, 0.85, 0.95, 0.0))
			material = Fx.unshaded_material()
	color_ramp = ramp
	preprocess = lifetime
	emitting = true
