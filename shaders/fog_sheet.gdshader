shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

uniform vec3 fog_tint : source_color = vec3(0.35, 0.7, 0.4);
uniform float alpha_scale : hint_range(0.0, 0.4) = 0.12;

void fragment() {
	vec2 uv = UV * vec2(3.0, 2.0) + vec2(TIME * 0.02, TIME * 0.01);
	float n = 0.5 + 0.5 * sin(uv.x * 8.0 + TIME * 0.3) * sin(uv.y * 6.0 - TIME * 0.2);
	float band = smoothstep(0.15, 0.85, n);
	ALBEDO = fog_tint;
	ALPHA = alpha_scale * band;
}
