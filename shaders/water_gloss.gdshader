shader_type spatial;
// Fake reflection from an HDRI panorama. gl_compatibility has no SSR.
render_mode diffuse_burley;

uniform sampler2D normal_tex : hint_normal, repeat_enable;
uniform sampler2D panorama : source_color, hint_default_black;
uniform vec3 deep : source_color = vec3(0.08, 0.2, 0.14);
uniform vec3 glaze : source_color = vec3(0.55, 0.82, 0.62);
uniform float reflect_strength : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec2 uv_a = UV * 2.4 + vec2(TIME * 0.04, TIME * 0.015);
	vec2 uv_b = UV * 3.6 + vec2(-TIME * 0.025, TIME * 0.03);
	vec3 n1 = texture(normal_tex, uv_a).rgb * 2.0 - 1.0;
	vec3 n2 = texture(normal_tex, uv_b).rgb * 2.0 - 1.0;
	vec3 n = normalize(vec3(n1.x + n2.x, n1.y + n2.y, 1.0));
	NORMAL_MAP = normalize(n1 + n2) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.55;
	vec3 view_n = normalize(mix(NORMAL, n, 0.65));
	vec3 r = reflect(-VIEW, view_n);
	float u = atan(r.z, r.x) * 0.1591549 + 0.5;
	float v = asin(clamp(r.y, -1.0, 1.0)) * 0.31831 + 0.5;
	vec3 refl = texture(panorama, vec2(u, v)).rgb;
	refl = refl / (1.0 + refl);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = mix(deep, glaze, 0.28 + fres * 0.35);
	ROUGHNESS = mix(0.08, 0.28, 1.0 - fres);
	METALLIC = 0.08;
	EMISSION = refl * reflect_strength * (0.25 + fres);
}
