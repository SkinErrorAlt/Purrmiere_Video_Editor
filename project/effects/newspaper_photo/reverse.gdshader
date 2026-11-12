shader_type canvas_item;
render_mode blend_disabled;

uniform int seed : hint_range(0, 999) = 7;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float dark_at(sampler2D tex, vec2 uv) {
	vec4 c = texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
	vec3 rgb = c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(1.0);
	return (1.0 - dot(rgb, vec3(0.2126, 0.7152, 0.0722))) * clamp(c.a, 0.0, 1.0);
}

void fragment() {
	float s = float(seed);
	vec2 shift = vec2(fract(s * 0.618034) - 0.5, fract(s * 0.414214) - 0.5) * 0.3;
	vec2 q = (vec2(1.0 - UV.x, UV.y) - 0.5) / 1.35 + 0.5 + shift;
	vec2 texel = 1.0 / max(tex_size, vec2(1.0));
	float r = 7.0 * max(px_scale, 0.0001);
	float d = dark_at(TEXTURE, q) * 0.2;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398 + 0.3;
		d += dark_at(TEXTURE, q + vec2(cos(a), sin(a)) * r * texel) * 0.065;
		d += dark_at(TEXTURE, q + vec2(cos(a + 0.39), sin(a + 0.39)) * r * 2.2 * texel) * 0.035;
	}
	COLOR = vec4(d, d, d, 1.0);
}
