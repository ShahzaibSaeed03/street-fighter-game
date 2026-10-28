shader_type canvas_item;
// Screen-edge darkening. GameManager tints it red when the player is low on health.

uniform float strength : hint_range(0.0, 1.0) = 0.55;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = dot(uv, uv) * 1.6;
	float a = smoothstep(0.12, 0.85, d) * strength;
	COLOR = vec4(tint.rgb, a);
}
