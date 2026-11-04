shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

uniform vec3 shaft_color : source_color = vec3(1.0, 0.72, 0.35);

void fragment() {
	float fade = smoothstep(0.0, 0.22, UV.y) * (1.0 - smoothstep(0.25, 0.95, UV.y));
	float side = smoothstep(0.0, 0.48, UV.x) * smoothstep(1.0, 0.52, UV.x);
	ALBEDO = shaft_color;
	ALPHA = 0.04 * fade * side;
}
