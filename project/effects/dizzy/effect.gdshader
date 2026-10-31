shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float amount : hint_range(0.0, 1.0) = 0.6;
uniform float speed : hint_range(0.05, 3.0) = 0.35;
uniform float sway : hint_range(0.0, 20.0) = 4.0;
uniform float double_vision : hint_range(0.0, 1.0) = 0.5;
uniform float blur : hint_range(0.0, 1.0) = 0.4;
uniform float warp : hint_range(0.0, 1.0) = 0.3;
uniform int seed : hint_range(0, 9999) = 0;

vec4 fetch(sampler2D tex, vec2 uv) {
	vec2 m = mod(uv, 2.0);
	return texture(tex, clamp(mix(m, 2.0 - m, step(vec2(1.0), m)), vec2(0.0), vec2(1.0)));
}

vec2 view_uv(vec2 uv, float t, float k, vec2 asp) {
	float s = float(seed) * 1.37;
	float ang = radians(sway) * k * (sin(t + s) * 0.7 + sin(t * 0.63 + 1.7 + s) * 0.3);
	float z = 1.0 + (0.04 + 0.02 * sin(t * 0.8 + s)) * k;
	vec2 drift = k * 0.015 * vec2(sin(t * 0.9 + s), cos(t * 0.7 + s * 2.0));
	vec2 q = (uv - 0.5) * asp;
	float cs = cos(ang);
	float sn = sin(ang);
	q = vec2(cs * q.x - sn * q.y, sn * q.x + cs * q.y) / z + drift;
	vec2 w = clamp(warp, 0.0, 1.0) * k * 0.012 * vec2(sin(q.y * 9.0 + t * 1.3), cos(q.x * 7.0 + t * 1.1));
	return (q + w) / asp + 0.5;
}

vec4 soft(sampler2D tex, vec2 uv, float r, vec2 size) {
	if (r < 0.25) {
		return fetch(tex, uv);
	}
	vec4 sum = fetch(tex, uv) * 2.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * TAU / 8.0;
		sum += fetch(tex, uv + vec2(cos(a), sin(a)) * r / size);
	}
	return sum / 10.0;
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	vec2 asp = vec2(size.x / size.y, 1.0);
	float k = clamp(amount, 0.0, 1.0);
	float t = clip_time * speed * TAU;
	vec2 uv = view_uv(UV, t, k, asp);
	float r = clamp(blur, 0.0, 1.0) * k * 7.0 * max(px_scale, 0.0001) * (0.6 + 0.4 * sin(t * 1.7));
	vec4 main_view = soft(TEXTURE, uv, r, size);
	float dv = clamp(double_vision, 0.0, 1.0) * k;
	vec4 c = main_view;
	if (dv > 0.0) {
		vec2 g = dv * 0.035 * vec2(cos(t * 1.2 + float(seed)), sin(t * 0.9 + float(seed))) * (0.6 + 0.4 * sin(t * 0.5));
		vec4 ghost = soft(TEXTURE, uv + g / asp, r, size);
		c = mix(main_view, ghost, 0.42 * clamp(dv * 2.0, 0.0, 1.0));
	}
	COLOR = c;
}
