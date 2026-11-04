shader_type spatial;
// Dark basalt crust, glowing cracks, solid dark rim. Never a white blob.
render_mode diffuse_burley, cull_back;

uniform vec3 crust : source_color = vec3(0.05, 0.02, 0.015);
uniform vec3 hot : source_color = vec3(0.85, 0.48, 0.08);
uniform float glow : hint_range(0.0, 1.5) = 0.72;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	// local_pos is the unscaled mesh (~1.4 m). Instance scale must not turn the pool into a dark slab.
	vec2 p = local_pos.xz;
	vec2 flow = p * 6.0 + vec2(TIME * 0.18, TIME * 0.06);
	float band = abs(sin(flow.x * 8.0 + sin(flow.y * 5.0 + TIME * 0.7)));
	float molten = 1.0 - smoothstep(0.25, 0.82, band);
	float crack = smoothstep(0.08, 0.4, band);
	float edge = max(abs(p.x), abs(p.y));
	float rim = smoothstep(0.52, 0.82, edge);
	vec3 magma = vec3(0.62, 0.22, 0.04);
	vec3 core = vec3(0.85, 0.48, 0.08);
	vec3 col = mix(crust, magma, molten * (1.0 - rim));
	col = mix(col, core, (1.0 - crack) * (1.0 - rim) * 0.65);
	ALBEDO = col;
	ROUGHNESS = mix(0.28, 0.92, max(rim, 1.0 - molten));
	EMISSION = (core * (1.0 - crack) + magma * molten) * (1.0 - rim) * glow;
}
