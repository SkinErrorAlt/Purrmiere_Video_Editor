shader_type canvas_item;
render_mode blend_disabled;

uniform float stroke_length : hint_range(1.0, 50.0) = 4.0;
uniform float dark_intensity : hint_range(0.0, 50.0) = 20.0;
uniform float light_intensity : hint_range(0.0, 50.0) = 10.0;
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

vec3 unp(vec4 c) {
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
}

float lum(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

float lum_at(sampler2D tex, vec2 uv) {
	return lum(unp(texture(tex, clamp(uv, vec2(0.0), vec2(1.0)))));
}

float dog(sampler2D tex, vec2 uv, vec2 r) {
	float here = lum_at(tex, uv);
	float m = lum_at(tex, uv + vec2(r.x, 0.0)) + lum_at(tex, uv - vec2(r.x, 0.0)) + lum_at(tex, uv + vec2(0.0, r.y)) + lum_at(tex, uv - vec2(0.0, r.y));
	m += lum_at(tex, uv + r * 0.7071) + lum_at(tex, uv - r * 0.7071) + lum_at(tex, uv + vec2(r.x, -r.y) * 0.7071) + lum_at(tex, uv + vec2(-r.x, r.y) * 0.7071);
	return m / 8.0 - here;
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float len = max(stroke_length, 1.0);
	float fs = float(seed);
	vec2 so = vec2(mod(fs * 12.9898, 997.0), mod(fs * 78.233, 991.0));
	vec2 P = UV * dims / ps;
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 col = unp(c);
	float l = lum(col);
	vec2 dir = vec2(0.7071, 0.7071);
	vec2 nrm = vec2(-dir.y, dir.x);
	vec2 r = vec2(1.6 * ps) / dims;
	vec2 st = dir * len * ps / dims / 4.0;
	float d = 0.0;
	for (int i = -2; i <= 2; i++) {
		d += max(dog(TEXTURE, UV + st * float(i), r), 0.0) * (i == 0 ? 2.0 : 1.0);
	}
	d /= 6.0;
	float dk = dark_intensity / 20.0;
	float lk = light_intensity / 10.0;
	float ink = smoothstep(0.004, 0.035, d) * clamp(dk, 0.0, 2.5) * 0.85;
	float along = dot(P, dir);
	float across = dot(P, nrm);
	float lane = floor(across / 2.0);
	float lf = fract(across / 2.0);
	float dash = vn(vec2(along / (len * 1.5), lane * 3.1) + so);
	float hatch = smoothstep(0.4, 0.55, dash) * (1.0 - smoothstep(0.3, 0.6, abs(lf - 0.5) * 2.0));
	float shadow = smoothstep(0.75, 0.1, l);
	float lines = clamp(ink + hatch * shadow * clamp(dk, 0.0, 2.5) * 0.6, 0.0, 0.97);
	col = mix(col, vec3(1.0), smoothstep(0.45, 1.0, l) * clamp(lk, 0.0, 5.0) * 0.22);
	col *= 1.0 - shadow * clamp(dk, 0.0, 2.5) * 0.35;
	col = (col - 0.5) * (1.0 + clamp(dk, 0.0, 2.5) * 0.15) + 0.5;
	col = mix(col, vec3(0.02, 0.02, 0.03), lines);
	COLOR = vec4(clamp(col, 0.0, 1.0) * a, a);
}
