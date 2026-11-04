shader_type spatial;
// Glossy fresnel puddle. gl_compatibility has no screen-space reflections,
// so the highlight is the fog color, not a reflection of the room.
render_mode diffuse_burley;

uniform vec3 deep : source_color = vec3(0.1, 0.26, 0.18);
uniform vec3 glaze : source_color = vec3(0.72, 0.95, 0.78);

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float ripple = 0.5 + 0.5 * sin(UV.x * 18.0 + TIME * 1.4) * sin(UV.y * 14.0 - TIME);
	ALBEDO = mix(deep, glaze, 0.32 + fres * 0.4);
	ROUGHNESS = mix(0.06, 0.2, ripple);
	METALLIC = 0.18;
	SPECULAR = 0.75;
	EMISSION = glaze * fres * (0.28 + 0.12 * ripple);
}
