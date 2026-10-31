shader_type canvas_item;
render_mode blend_disabled;

uniform float stroke_length : hint_range(0.0, 20.0) = 12.0;
uniform float spray_radius : hint_range(0.0, 25.0) = 7.0;
uniform int direction : hint_range(0, 3) = 0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec2 spray(vec2 st, float len, vec2 so) {
	vec2 k = vec2(st.x / max(len * 0.8, 1.0), st.y / 1.15);
	vec2 a = vec2(vn(k + so), vn(k + so + vec2(41.3, 17.9)));
	vec2 b = vec2(vn(k * vec2(0.5, 0.45) + so + 7.1), vn(k * vec2(0.5, 0.45) + so + 63.2));
	return (a * 0.7 + b * 0.3 - 0.5) * 2.0;
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 S = dims / ps;
	vec2 P = UV * S;
	vec2 dir = vec2(0.70710678, -0.70710678);
	if (direction == 1) {
		dir = vec2(1.0, 0.0);
	} else if (direction == 2) {
		dir = vec2(0.70710678, 0.70710678);
	} else if (direction == 3) {
		dir = vec2(0.0, 1.0);
	}
	vec2 perp = vec2(-dir.y, dir.x);
	float fs = float(seed);
	vec2 so = vec2(mod(fs * 12.9898, 97.0), mod(fs * 78.233, 91.0));
	float len = max(stroke_length, 0.0);
	float rad = max(spray_radius, 0.0);
	vec4 c0 = texture(TEXTURE, UV);
	float a = c0.a;
	vec4 acc = vec4(0.0);
	float ws = 0.0;
	for (int k = -4; k <= 4; k++) {
		float o = float(k) / 4.0 * len * 0.45;
		vec2 Pk = P + dir * o;
		vec2 st = vec2(dot(Pk, dir), dot(Pk, perp));
		vec2 sp = spray(st, len, so);
		float grain = h12(floor(Pk * ps) + so) - 0.5;
		vec2 disp = dir * sp.x * len * 0.3 + (perp * sp.y + perp * grain * 0.12) * rad;
		float w = 1.0 - abs(float(k)) / 5.0;
		vec4 s = texture(TEXTURE, clamp((Pk + disp) / S, vec2(0.0), vec2(1.0)));
		acc += s * w;
		ws += w;
	}
	acc /= ws;
	vec3 rgb = acc.a > 0.0001 ? clamp(acc.rgb / acc.a, 0.0, 1.0) : (a > 0.0001 ? clamp(c0.rgb / a, 0.0, 1.0) : vec3(0.0));
	COLOR = vec4(rgb * a, a);
}
