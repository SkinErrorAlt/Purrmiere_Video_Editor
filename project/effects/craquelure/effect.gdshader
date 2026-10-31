shader_type canvas_item;
render_mode blend_disabled;

uniform float crack_spacing : hint_range(2.0, 100.0) = 15.0;
uniform float crack_depth : hint_range(0.0, 10.0) = 6.0;
uniform float crack_brightness : hint_range(0.0, 10.0) = 9.0;
uniform float light_angle : hint_range(-180.0, 180.0) = 135.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

vec2 h22(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float border(vec2 x, vec2 so) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	vec2 mg = vec2(0.0);
	vec2 mr = vec2(0.0);
	float md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + 0.1 + h22(n + g + so) * 0.8 - f;
			float d = dot(r, r);
			if (d < md) {
				md = d;
				mr = r;
				mg = g;
			}
		}
	}
	md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = mg + vec2(float(i), float(j));
			vec2 r = g + 0.1 + h22(n + g + so) * 0.8 - f;
			vec2 dr = r - mr;
			if (dot(dr, dr) > 0.00001) {
				md = min(md, dot(0.5 * (mr + r), normalize(dr)));
			}
		}
	}
	return md;
}

vec3 unp(vec4 c) {
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
}

float height_at(sampler2D tex, vec2 P, vec2 uv, float cell, float half_crack, float bevel, vec2 so) {
	float l = dot(unp(texture(tex, clamp(uv, vec2(0.0), vec2(1.0)))), vec3(0.2126, 0.7152, 0.0722));
	vec2 w = vec2(vn(P / (cell * 1.7) + so), vn(P / (cell * 1.7) + so + 17.0)) - 0.5;
	vec2 q = P / cell + w * 0.55 + vec2(l - 0.5) * 0.35;
	float d = border(q, so) * cell;
	float rim = smoothstep(half_crack, half_crack + bevel, d);
	return rim * (1.0 + clamp(d / cell, 0.0, 0.5) * 0.6) + l * 0.35;
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float fs = float(seed);
	vec2 so = vec2(mod(fs * 12.9898, 997.0), mod(fs * 78.233, 991.0));
	vec2 P = UV * dims / ps;
	float cell = max(crack_spacing, 1.0) * 2.0;
	float depth = clamp(crack_depth, 0.0, 10.0) / 10.0;
	float half_crack = 0.35 + depth * 0.5;
	float bevel = 1.2 + depth * 1.6;
	vec2 e = vec2(ps) / dims;
	float h0 = height_at(TEXTURE, P, UV, cell, half_crack, bevel, so);
	float hx = height_at(TEXTURE, P + vec2(1.0, 0.0), UV + vec2(e.x, 0.0), cell, half_crack, bevel, so);
	float hy = height_at(TEXTURE, P + vec2(0.0, 1.0), UV + vec2(0.0, e.y), cell, half_crack, bevel, so);
	vec2 wq = vec2(vn(P / (cell * 1.7) + so), vn(P / (cell * 1.7) + so + 17.0)) - 0.5;
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = unp(c);
	float l = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	float dc = border(P / cell + wq * 0.55 + vec2(l - 0.5) * 0.35, so) * cell;
	float relief = depth * 1.4;
	vec3 n = normalize(vec3(-(hx - h0) * relief, -(hy - h0) * relief, 1.0));
	float an = radians(light_angle);
	vec3 L = normalize(vec3(cos(an), -sin(an), 1.1));
	float shade = dot(n, L) / L.z;
	float bright = clamp(crack_brightness, 0.0, 10.0) / 10.0;
	vec3 col = rgb * mix(0.82, 1.06, bright) * clamp(shade, 0.3, 1.6);
	float cm = 1.0 - smoothstep(half_crack - 0.45, half_crack + 0.55, dc);
	vec3 crack = rgb * mix(0.08, 0.55, bright);
	col = mix(col, crack, cm * mix(0.4, 1.0, depth));
	COLOR = vec4(clamp(col, 0.0, 1.0) * a, a);
}
