shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

uniform vec3 shaft_color : source_color = vec3(1.0, 0.72, 0.35);

void fragment() {
	float fade = smoothstep(0.0, 0.35, UV.y) * smoothstep(1.0, 0.45, UV.y);
	float side = smoothstep(0.0, 0.25, UV.x) * smoothstep(1.0, 0.75, UV.x);
	ALBEDO = shaft_color;
	ALPHA = 0.11 * fade * side;
}
