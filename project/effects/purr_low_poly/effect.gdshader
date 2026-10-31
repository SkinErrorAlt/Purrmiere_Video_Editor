shader_type canvas_item;
render_mode blend_disabled;

uniform float cell : hint_range(6.0, 300.0) = 48.0;
uniform float jitter : hint_range(0.0, 1.0) = 0.7;
uniform float shading : hint_range(0.0, 1.0) = 0.5;
uniform float edges : hint_range(0.0, 1.0) = 0.15;
uniform int seed : hint_range(0, 999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

vec2 h22(vec2 p) { vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); q += dot(q, q.yzx + 33.33); return fract((q.xx + q.yz) * q.zy); }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 unp(vec4 c) { return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0); }
vec4 pm(vec3 c, float a) { return vec4(clamp(c, 0.0, 1.0) * a, a); }
vec2 PX(vec2 uv) { return uv * tex_size / max(px_scale, 0.0001); }

vec2 vtx(vec2 g) {
	return g + (h22(g + float(seed) * 1.7) - 0.5) * jitter * 0.8;
}

float cross2(vec2 a, vec2 b) {
	return a.x * b.y - a.y * b.x;
}

void fragment() {
	vec2 P = PX(UV) / cell;
	vec2 base = floor(P);
	vec2 A = vec2(0.0);
	vec2 B = vec2(0.0);
	vec2 C = vec2(0.0);
	float found = 0.0;
	float emin = 9.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = base + vec2(float(i), float(j));
			vec2 v00 = vtx(g);
			vec2 v10 = vtx(g + vec2(1.0, 0.0));
			vec2 v01 = vtx(g + vec2(0.0, 1.0));
			vec2 v11 = vtx(g + vec2(1.0, 1.0));
			for (int t = 0; t < 2; t++) {
				vec2 a = v00;
				vec2 b = t == 0 ? v10 : v11;
				vec2 cc = t == 0 ? v11 : v01;
				float e0 = cross2(b - a, P - a);
				float e1 = cross2(cc - b, P - b);
				float e2 = cross2(a - cc, P - cc);
				if (found < 0.5 && ((e0 >= 0.0 && e1 >= 0.0 && e2 >= 0.0) || (e0 <= 0.0 && e1 <= 0.0 && e2 <= 0.0))) {
					A = a;
					B = b;
					C = cc;
					found = 1.0;
					emin = min(abs(e0) / length(b - a), min(abs(e1) / length(cc - b), abs(e2) / length(a - cc)));
				}
			}
		}
	}
	vec2 k = cell * px_scale / max(tex_size, vec2(1.0));
	vec2 cen = (A + B + C) / 3.0;
	vec4 c = texture(TEXTURE, clamp(cen * k, vec2(0.0), vec2(1.0)));
	vec3 s = unp(c);
	float ha = lum(unp(texture(TEXTURE, clamp(A * k, vec2(0.0), vec2(1.0)))));
	float hb = lum(unp(texture(TEXTURE, clamp(B * k, vec2(0.0), vec2(1.0)))));
	float hc = lum(unp(texture(TEXTURE, clamp(C * k, vec2(0.0), vec2(1.0)))));
	vec3 n = normalize(cross(vec3(B - A, (hb - ha) * 1.5), vec3(C - A, (hc - ha) * 1.5)));
	n *= sign(n.z + 0.0001);
	float lit = dot(n, normalize(vec3(-0.5, -0.6, 0.8)));
	vec3 o = s * mix(1.0, 0.55 + 0.6 * lit, shading);
	o = mix(o, o * 0.7, edges * smoothstep(0.04, 0.0, emin));
	COLOR = pm(o, texture(TEXTURE, UV).a);
}
