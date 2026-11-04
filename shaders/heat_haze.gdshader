shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

void fragment() {
	vec2 uv = UV * vec2(3.0, 2.0) + vec2(TIME * 0.15, TIME * 0.35);
	float n = sin(uv.x * 9.0) * sin(uv.y * 7.0 + TIME);
	ALBEDO = vec3(0.55, 0.22, 0.05);
	ALPHA = clamp(0.05 + 0.07 * n, 0.0, 0.16);
}
