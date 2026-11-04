shader_type spatial;
// Dark basalt crust, glowing cracks, solid dark rim. Never a white blob.
render_mode diffuse_burley, cull_back;

uniform vec3 crust : source_color = vec3(0.05, 0.02, 0.015);
uniform vec3 hot : source_color = vec3(0.62, 0.22, 0.04);
uniform float glow : hint_range(0.0, 1.5) = 0.55;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 uv = local_pos.xz * 3.2 + vec2(TIME * 0.04, TIME * 0.02);
	float n = sin(uv.x * 8.0) * sin(uv.y * 6.0 + TIME * 0.35);
	float crack = smoothstep(0.2, 0.62, n * 0.5 + 0.5);
	float rim = smoothstep(0.42, 0.92, length(local_pos.xz));
	vec3 col = mix(hot, crust, crack);
	col = mix(col, crust * 0.45, rim);
	ALBEDO = col;
	ROUGHNESS = mix(0.45, 0.95, max(crack, rim));
	EMISSION = hot * (1.0 - crack) * (1.0 - rim) * glow;
}
