shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float amount : hint_range(0.0, 60.0) = 6.0;
uniform float scale : hint_range(4.0, 400.0) = 50.0;
uniform float speed : hint_range(0.0, 5.0) = 1.0;
uniform float rise : hint_range(0.0, 5.0) = 1.0;
uniform float mask_bottom : hint_range(0.0, 1.0) = 0.6;
uniform int seed : hint_range(0, 9999) = 0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float shimmer(vec2 p, float t, float s) {
	float n = value_noise(p * vec2(1.0, 1.6) + vec2(s, t * 0.7)) - 0.5;
	n += (value_noise(p * vec2(2.3, 3.1) + vec2(s + 19.1, -t * 1.1)) - 0.5) * 0.5;
	return n;
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 pix = UV * size / ps;
	vec2 p = pix / max(scale, 1.0);
	p.y += clip_time * rise;
	float t = clip_time * speed;
	float s = float(seed) * 0.713;
	float nx = shimmer(p, t, s);
	float ny = shimmer(p + vec2(37.2, 11.9), t, s + 5.3);
	float m = mix(1.0, smoothstep(0.0, 1.0, UV.y), clamp(mask_bottom, 0.0, 1.0));
	vec2 off = vec2(nx, ny * 0.5) * 2.0 * amount * ps * m / size;
	COLOR = texture(TEXTURE, clamp(UV + off, vec2(0.0), vec2(1.0)));
}
