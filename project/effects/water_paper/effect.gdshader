shader_type canvas_item;
render_mode blend_disabled;

uniform float fibre_length : hint_range(3.0, 50.0) = 15.0;
uniform float brightness : hint_range(0.0, 100.0) = 60.0;
uniform float contrast : hint_range(0.0, 100.0) = 80.0;
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

float fibre_angle(vec2 p, float fl) {
	return (vn(p / (fl * 2.5)) * 0.7 + vn(p / (fl * 0.9) + 13.0) * 0.3) * 9.0;
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float fl = max(fibre_length, 1.0);
	float fs = float(seed);
	vec2 so = vec2(mod(fs * 12.9898, 997.0), mod(fs * 78.233, 991.0));
	vec2 P = UV * dims / ps + so;
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	float an = fibre_angle(P, fl);
	vec2 dir = vec2(cos(an), sin(an));
	vec2 daub = vec2(vn(P / (fl * 0.7) + 71.0), vn(P / (fl * 0.7) + 93.0)) - 0.5;
	vec2 base = UV + daub * fl * 0.45 * ps / dims;
	vec4 sum = vec4(0.0);
	for (int i = -6; i <= 6; i++) {
		sum += texture(TEXTURE, clamp(base + dir * (float(i) / 12.0) * fl * ps / dims, vec2(0.0), vec2(1.0)));
	}
	sum /= 13.0;
	vec3 col = sum.a > 0.0001 ? clamp(sum.rgb / sum.a, 0.0, 1.0) : (a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0));
	float lic = 0.0;
	vec2 q = P;
	vec2 qd = dir;
	for (int i = 0; i < 8; i++) {
		lic += h12(floor(q * 0.9));
		q += qd * 1.6;
	}
	q = P;
	for (int i = 0; i < 8; i++) {
		q -= qd * 1.6;
		lic += h12(floor(q * 0.9));
	}
	lic /= 16.0;
	float fib = clamp((lic - 0.5) * 3.2, -1.0, 1.0);
	float wet = vn(P / (fl * 1.6) + 5.0);
	col = (col - 0.5) * mix(0.35, 1.45, contrast / 100.0) + 0.5;
	col += (brightness - 50.0) / 100.0 * 0.7;
	col *= 1.0 + fib * 0.2;
	col += (wet - 0.5) * 0.08;
	col = mix(col, vec3(1.0), clamp(fib, 0.0, 1.0) * 0.06);
	COLOR = vec4(clamp(col, 0.0, 1.0) * a, a);
}
