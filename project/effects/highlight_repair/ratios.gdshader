shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float threshold : hint_range(0.85, 1.0) = 0.97;

vec4 weighted(sampler2D tex, vec2 uv) {
	vec4 c = texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
	vec3 rgb = c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
	float m = max(rgb.r, max(rgb.g, rgb.b));
	float t = clamp(threshold, 0.85, 1.0) - 0.02;
	float clipped = smoothstep(t - 0.04, t, m);
	float w = (1.0 - clipped) * smoothstep(0.2, 0.55, m) * step(0.5, c.a);
	vec3 ratio = m > 0.0001 ? rgb / m : vec3(0.0);
	return vec4(ratio * w, w);
}

void fragment() {
	vec2 px = 1.0 / max(tex_size, vec2(1.0));
	vec4 s = weighted(TEXTURE, UV + px * vec2(-0.5, -0.5));
	s += weighted(TEXTURE, UV + px * vec2(0.5, -0.5));
	s += weighted(TEXTURE, UV + px * vec2(-0.5, 0.5));
	s += weighted(TEXTURE, UV + px * vec2(0.5, 0.5));
	COLOR = s * 0.25;
}
