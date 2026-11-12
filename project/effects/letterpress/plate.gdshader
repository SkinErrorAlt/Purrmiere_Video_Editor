shader_type canvas_item;
render_mode blend_disabled;

uniform int plate : hint_range(0, 1) = 0;
uniform float level : hint_range(0.0, 1.0) = 0.42;
uniform float smoothing : hint_range(0.0, 8.0) = 2.0;
uniform float screen : hint_range(3.0, 24.0) = 7.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float tone_at(sampler2D tex, vec2 uv) {
	vec4 c = texture(tex, uv);
	vec3 rgb = c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(1.0);
	float l = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	return mix(1.0, l, clamp(c.a, 0.0, 1.0));
}

void fragment() {
	vec2 texel = 1.0 / max(tex_size, vec2(1.0));
	float r = smoothing * max(px_scale, 0.0001);
	float l = tone_at(TEXTURE, UV) * 0.25;
	l += tone_at(TEXTURE, UV + vec2(r, 0.0) * texel) * 0.125;
	l += tone_at(TEXTURE, UV - vec2(r, 0.0) * texel) * 0.125;
	l += tone_at(TEXTURE, UV + vec2(0.0, r) * texel) * 0.125;
	l += tone_at(TEXTURE, UV - vec2(0.0, r) * texel) * 0.125;
	l += tone_at(TEXTURE, UV + vec2(r, r) * 0.7071 * texel) * 0.0625;
	l += tone_at(TEXTURE, UV + vec2(-r, r) * 0.7071 * texel) * 0.0625;
	l += tone_at(TEXTURE, UV + vec2(r, -r) * 0.7071 * texel) * 0.0625;
	l += tone_at(TEXTURE, UV - vec2(r, r) * 0.7071 * texel) * 0.0625;
	float m = 0.0;
	if (plate == 0) {
		float aa = max(fwidth(l) * 0.75, 0.003);
		m = 1.0 - smoothstep(level - aa, level + aa, l);
	} else {
		float cell = max(screen * max(px_scale, 0.0001), 2.0);
		vec2 p = UV * tex_size / cell;
		vec2 g = vec2(p.x + p.y, p.y - p.x) * 0.70710678;
		vec2 f = fract(g) - 0.5;
		float spot = 0.5 - 0.25 * (cos(6.2831853 * f.x) + cos(6.2831853 * f.y));
		float tone = clamp((1.0 - l - (0.5 - level) * 0.6) * 1.08 - 0.04, 0.0, 1.0);
		float aa = max(fwidth(spot) * 0.75, 0.01);
		m = smoothstep(-aa, aa, tone - spot);
	}
	COLOR = vec4(m, m, m, 1.0);
}
