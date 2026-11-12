shader_type canvas_item;
render_mode blend_disabled;

uniform float grain : hint_range(1.0, 12.0) = 3.0;
uniform float clumping : hint_range(0.0, 1.0) = 0.6;
uniform float softness : hint_range(0.0, 1.0) = 0.72;
uniform float exposure : hint_range(-2.0, 2.0) = 0.2;
uniform float colour : hint_range(0.0, 1.5) = 1.0;
uniform float carbon : hint_range(0.0, 1.0) = 0.5;
uniform float falloff : hint_range(0.0, 1.0) = 0.35;
uniform int seed : hint_range(0, 999) = 7;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

const vec3 DYE_R = vec3(0.95, 0.28, 0.12);
const vec3 DYE_G = vec3(0.2, 0.5, 0.1);
const vec3 DYE_B = vec3(0.24, 0.17, 0.86);
const float GAIN = 1.75;

float h12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

vec2 h22(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.103, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 lin_at(sampler2D tex, vec2 uv) {
	vec4 c = texture(tex, uv);
	vec3 rgb = c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
	return pow(rgb, vec3(2.2));
}

vec3 weights(vec2 g, vec2 off) {
	float k = clumping * 5.5;
	vec3 n = vec3(vn(g * 0.33 + off), vn(g * 0.33 + off + vec2(41.0, 17.0)), vn(g * 0.33 + off + vec2(-23.0, 59.0))) * 0.45;
	n += vec3(vn(g * 0.13 + off * 0.7), vn(g * 0.13 + off * 0.7 + vec2(3.0, 71.0)), vn(g * 0.13 + off * 0.7 + vec2(-61.0, 9.0))) * 0.35;
	n += vec3(vn(g * 0.045 + off * 0.5), vn(g * 0.045 + off * 0.5 + vec2(13.0, 7.0)), vn(g * 0.045 + off * 0.5 + vec2(5.0, -31.0))) * 0.2;
	vec3 w = exp(k * (n - 0.5));
	return w / (w.x + w.y + w.z);
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float alpha = src.a;
	vec2 size = max(tex_size, vec2(1.0));
	vec2 texel = 1.0 / size;
	float ps = max(px_scale, 0.0001);
	vec2 P = UV * size / ps;
	vec2 off = vec2(float(seed) * 3.17, float(seed) * 1.93);
	float gs = max(grain, 0.5);
	vec2 g = P / gs;
	vec2 base = floor(g);
	float d1 = 9.0;
	float d2 = 9.0;
	vec2 id = base;
	vec2 site = base;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 n = base + vec2(float(i), float(j));
			vec2 pt = n + 0.5 + (h22(n + off) - 0.5) * 0.92;
			vec2 dv = g - pt;
			float d = dot(dv, dv) * mix(0.8, 1.25, h12(n + off * 1.7));
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = n;
				site = pt;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	float edge = sqrt(d2) - sqrt(d1);
	float blur_r = gs * (0.6 + softness * 1.4) * ps;
	vec3 lin = lin_at(TEXTURE, UV) * 0.2;
	vec3 wide = vec3(0.0);
	for (int i = 0; i < 6; i++) {
		float a = float(i) * 1.0471976 + 0.4;
		vec2 dir = vec2(cos(a), sin(a)) * texel;
		lin += lin_at(TEXTURE, UV + dir * blur_r * 0.6) * 0.0867;
		lin += lin_at(TEXTURE, UV + vec2(-dir.y, dir.x) * blur_r * 1.3) * 0.0467;
		wide += lin_at(TEXTURE, UV + dir * blur_r * 4.0);
	}
	wide /= 6.0;
	lin += max(wide - 0.45, vec3(0.0)) * 0.35 * (0.4 + softness);
	lin *= exp2(exposure);
	float y = dot(lin, vec3(0.2126, 0.7152, 0.0722));
	lin = max(mix(vec3(y), lin, colour), vec3(0.0));
	vec3 band = vec3(dot(lin, vec3(0.8, 0.18, 0.02)), dot(lin, vec3(0.06, 0.82, 0.12)), dot(lin, vec3(0.02, 0.2, 0.78)));
	vec3 cr = min(DYE_R * band.x * GAIN, vec3(1.0));
	vec3 cg = min(DYE_G * band.y * GAIN, vec3(1.0));
	vec3 cb = min(DYE_B * band.z * GAIN, vec3(1.0));
	vec3 w = weights(site, off);
	float r = h12(id + off * 2.3 + vec2(7.0, 3.0));
	vec3 grain_col = r < w.x ? cr : (r < w.x + w.y ? cg : cb);
	vec3 local = cr * w.x + cg * w.y + cb * w.z;
	float gap = 1.0 - smoothstep(0.03, 0.16 + carbon * 0.1, edge);
	vec3 mosaic = grain_col * (1.0 - carbon * gap * 0.9);
	vec3 smooth_col = local * (1.0 - carbon * 0.22);
	vec3 col = mix(mosaic, smooth_col, softness * 0.82);
	vec2 c = (UV - 0.5) * vec2(1.0, size.y / size.x) * 2.0;
	float fall = 1.0 - falloff * 0.65 * smoothstep(0.35, 1.15, length(c));
	float plate = 1.0 - falloff * 0.12 * (vn(P * 0.003 + off) - 0.5);
	col *= fall * plate;
	col = pow(max(col, vec3(0.0)), vec3(1.0 / 2.2));
	COLOR = vec4(clamp(col, 0.0, 1.0) * alpha, alpha);
}
