shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

uniform sampler2D emission_tex : source_color, repeat_enable;

void fragment() {
	vec2 uv = UV * 1.6 + vec2(TIME * 0.02, 0.0);
	float e = max(texture(emission_tex, uv).r, max(texture(emission_tex, uv).g, texture(emission_tex, uv).b));
	float crack = smoothstep(0.42, 0.78, e);
	ALBEDO = vec3(0.08, 0.03, 0.01);
	EMISSION = vec3(0.62, 0.24, 0.05) * crack * 0.55;
	ALPHA = crack * 0.85;
}
