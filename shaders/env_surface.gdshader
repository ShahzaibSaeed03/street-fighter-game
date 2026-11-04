shader_type spatial;
// World-space PBR. Floor and wall use different textures and a big value gap
// so the wall separates from the ground. Wall tops catch a bright rim.
render_mode diffuse_burley;

uniform sampler2D albedo : source_color, repeat_enable;
uniform sampler2D detail : source_color, repeat_enable;
uniform sampler2D rough_tex : hint_roughness_r, repeat_enable;
uniform sampler2D normal_tex : hint_normal, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float uv_scale = 0.22;
uniform float detail_mix : hint_range(0.0, 1.0) = 0.32;
uniform float wet_strength : hint_range(0.0, 1.0) = 0.15;
uniform float value : hint_range(0.05, 2.0) = 1.0;
uniform float top_rim : hint_range(0.0, 1.0) = 0.0;
uniform vec3 rim_color : source_color = vec3(1.0, 0.78, 0.45);
uniform float vein : hint_range(0.0, 1.0) = 0.0;
uniform vec3 vein_color : source_color = vec3(0.45, 0.25, 0.9);

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
	vec3 col = mix(base, wear, stain * detail_mix) * tint * value;
	float h = clamp(wpos.y / 3.6, 0.0, 1.0);
	float foot = (1.0 - smoothstep(0.0, 0.28, wpos.y)) * top_rim;
	col *= mix(1.0, 0.28, foot);
	float rim = smoothstep(0.72, 0.9, h) * top_rim * (1.0 - up_facing);
	col = mix(col, rim_color, rim);
	float rough = texture(rough_tex, uv).r;
	float wet = smoothstep(0.62, 0.9, stain);
	ALBEDO = col;
	ROUGHNESS = mix(rough, 0.16, wet * wet_strength);
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = 0.65;
	float along = wpos.x * 0.41 + wpos.z * 0.27;
	float wander = sin(along * 3.1) * 0.12;
	float band = abs(fract(wpos.y * 0.48 + wander) - 0.5);
	float thin = 1.0 - smoothstep(0.008, 0.028, band);
	float band2 = abs(fract(along * 0.62 + wpos.y * 0.04) - 0.5);
	float thin2 = 1.0 - smoothstep(0.006, 0.02, band2);
	col *= mix(1.0, 0.42, thin2 * top_rim);
	EMISSION = vein_color * max(thin, thin2) * vein;
}
