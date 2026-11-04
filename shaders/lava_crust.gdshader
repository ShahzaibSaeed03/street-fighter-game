shader_type spatial;
// Lava001 (ambientCG) with a slow flow. Edges stay dark. Emission is clamped
// so the pool cannot blow out to white.
render_mode diffuse_burley, cull_disabled;

uniform sampler2D albedo : source_color, repeat_enable;
uniform sampler2D emission_tex : source_color, repeat_enable;
uniform sampler2D normal_tex : hint_normal, repeat_enable;
uniform sampler2D rough_tex : hint_roughness_r, repeat_enable;
uniform float glow : hint_range(0.0, 1.6) = 0.72;

void fragment() {
	vec2 flow = UV * vec2(1.4, 1.0) + vec2(TIME * 0.045, TIME * 0.012);
	vec2 flow_b = UV * vec2(1.9, 1.3) + vec2(-TIME * 0.02, TIME * 0.03);
	vec3 col = texture(albedo, flow).rgb;
	vec3 em = texture(emission_tex, flow).rgb * 0.65 + texture(emission_tex, flow_b).rgb * 0.35;
	em = min(em, vec3(0.72, 0.34, 0.08));
	float edge = smoothstep(0.0, 0.14, min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y)));
	ALBEDO = col * mix(0.18, 0.55, edge);
	ROUGHNESS = mix(0.92, texture(rough_tex, flow).r, edge);
	NORMAL_MAP = texture(normal_tex, flow).rgb;
	NORMAL_MAP_DEPTH = 0.7;
	EMISSION = em * edge * glow;
}
