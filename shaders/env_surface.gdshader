shader_type spatial;
// One continuous world-space material. Adjacent tiles share UVs, so the floor
// does not break into a checkerboard. A second map stains wear into the first.
render_mode diffuse_burley;

uniform sampler2D albedo : source_color, repeat_enable;
uniform sampler2D detail : source_color, repeat_enable;
uniform sampler2D rough_tex : hint_roughness_r, repeat_enable;
uniform sampler2D normal_tex : hint_normal, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float uv_scale = 0.22;
uniform float detail_mix : hint_range(0.0, 1.0) = 0.32;
uniform float wet_strength : hint_range(0.0, 1.0) = 0.15;

varying vec3 wpos;
varying float up_facing;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	up_facing = abs((MODEL_MATRIX * vec4(NORMAL, 0.0)).y);
}

void fragment() {
	vec2 floor_uv = wpos.xz * uv_scale;
	vec2 wall_uv = vec2(wpos.x + wpos.z, wpos.y) * uv_scale;
	vec2 uv = mix(wall_uv, floor_uv, step(0.65, up_facing));
	vec3 base = texture(albedo, uv).rgb;
	vec3 wear = texture(detail, uv * 1.37 + vec2(0.17, 0.09)).rgb;
	float stain = smoothstep(0.35, 0.75, wear.r * 0.6 + wear.g * 0.3 + wear.b * 0.1);
	vec3 col = mix(base, wear, stain * detail_mix) * tint;
	float rough = texture(rough_tex, uv).r;
	float wet = smoothstep(0.62, 0.9, stain);
	ALBEDO = col;
	ROUGHNESS = mix(rough, 0.16, wet * wet_strength);
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = 0.55;
}
