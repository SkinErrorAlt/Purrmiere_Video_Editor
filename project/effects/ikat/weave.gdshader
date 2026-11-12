shader_type canvas_item;
render_mode blend_disabled;

uniform int dyes = 0;
uniform int bind = 0;
uniform float thread : hint_range(1.5, 16.0) = 4.0;
uniform float feather : hint_range(0.0, 120.0) = 30.0;
uniform float drift : hint_range(0.0, 1.0) = 0.5;
uniform float weave : hint_range(0.0, 1.0) = 0.6;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform sampler2D effect_tex : filter_linear, repeat_disable;

const vec3 DYE[8] = vec3[](
	vec3(0.93, 0.89, 0.8), vec3(0.11, 0.12, 0.2), vec3(0.16, 0.26, 0.5), vec3(0.62, 0.13, 0.12),
	vec3(0.88, 0.62, 0.15), vec3(0.2, 0.38, 0.26), vec3(0.42, 0.18, 0.28), vec3(0.52, 0.66, 0.78)
);

float h12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

vec3 dye_of(sampler2D tex, vec2 uv) {
	vec4 s = texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
	vec3 c = s.rgb / max(s.a, 0.0001);
	if (dyes == 1) {
		vec3 h = rgb2hsv(clamp(c, 0.0, 1.0));
		h.x = floor(h.x * 8.0 + 0.5) / 8.0;
		h.y = clamp(floor(h.y * 3.0 + 0.4) / 3.0 * 1.1, 0.0, 1.0);
		h.z = (floor(h.z * 3.0 + 0.5) + 0.2) / 3.4;
		return hsv2rgb(h);
	}
	vec3 best = DYE[0];
	float bd = 1e9;
	for (int i = 0; i < 8; i++) {
		vec3 d = c - DYE[i];
		float rm = 0.5 * (c.r + DYE[i].r);
		float e = (2.0 + rm) * d.r * d.r + 4.0 * d.g * d.g + (3.0 - rm) * d.b * d.b;
		if (e < bd) {
			bd = e;
			best = DYE[i];
		}
	}
	return best;
}

void fragment() {
	vec4 base = texture(effect_tex, UV);
	vec2 out_size = max(1.0 / max(fwidth(UV), vec2(0.000001)), vec2(1.0));
	float ps = max(px_scale * out_size.x / max(tex_size.x, 1.0), 0.0001);
	vec2 p = UV * out_size / ps;
	vec2 to_uv = ps / out_size;
	vec2 so = vec2(float(seed) * 3.33, float(seed) * 1.77);
	float T = max(thread, 1.0);
	bool weft_bind = bind == 1;
	vec2 a = weft_bind ? p.yx : p;
	float col_id = floor(a.x / T);
	float bundle = floor(col_id / 8.0);
	float fx = fract(a.x / T);
	float off = (h12(vec2(col_id, 1.0) + so) - 0.5) * feather * 0.3;
	off += (h12(vec2(bundle, 2.0) + so) - 0.5) * feather * 0.9;
	off += (vnoise(vec2(col_id * 0.06, 2.0) + so) - 0.5) * feather * 2.0 * drift;
	off += (vnoise(vec2(col_id * 0.03, a.y * 0.003) + so) - 0.5) * feather * 0.8 * drift;
	float stretch = 1.0 + (h12(vec2(col_id, 5.0) + so) - 0.5) * 0.04 * drift;
	vec2 sa = vec2((col_id + 0.5) * T, a.y * stretch + off);
	if (bind == 2) {
		float row_id = floor(a.y / T);
		float off2 = (h12(vec2(row_id, 9.0) + so) - 0.5) * feather * 0.7;
		sa.x += off2;
	}
	vec2 sp = weft_bind ? sa.yx : sa;
	vec2 along = weft_bind ? vec2(feather * 0.12, 0.0) : vec2(0.0, feather * 0.12);
	vec3 c = dye_of(TEXTURE, sp * to_uv) * 0.5 + dye_of(TEXTURE, (sp + along) * to_uv) * 0.25 + dye_of(TEXTURE, (sp - along) * to_uv) * 0.25;
	vec3 cpure = dye_of(TEXTURE, UV);
	float bleedn = vnoise(vec2(col_id, a.y * 0.15) + so);
	c = mix(c, cpure, 0.12 * bleedn);
	float pick = floor(a.y / (T * 0.8));
	float fy = fract(a.y / (T * 0.8));
	float over = mod(col_id + pick, 2.0);
	float xr = fx * 2.0 - 1.0;
	float round_w = sqrt(max(1.0 - xr * xr, 0.0));
	float yr = fy * 2.0 - 1.0;
	float round_f = sqrt(max(1.0 - yr * yr, 0.0));
	vec3 weftc = mix(vec3(0.5, 0.46, 0.4), c, 0.3) * (0.6 + 0.4 * round_f);
	vec3 warp = c * (0.62 + 0.42 * round_w);
	float twist = 0.94 + 0.06 * sin((a.y / T) * 9.0 + fx * 4.0);
	warp *= twist;
	float show_weft = over * smoothstep(0.35, 0.95, abs(xr));
	vec3 cloth = mix(warp, weftc, show_weft * 0.6 * weave);
	cloth = mix(c, cloth, weave);
	cloth *= 0.95 + 0.1 * vnoise(vec2(col_id * 0.31, a.y * 0.02) + so);
	COLOR = vec4(clamp(cloth, 0.0, 1.0) * base.a, base.a);
}
