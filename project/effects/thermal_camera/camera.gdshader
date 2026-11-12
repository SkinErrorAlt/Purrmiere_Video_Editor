shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D heat_tex : filter_linear, repeat_disable;
uniform sampler2D half_tex : filter_linear, repeat_disable;
uniform sampler2D bloom_tex : filter_linear, repeat_disable;
uniform sampler2D quarter_tex : filter_linear, repeat_disable;
uniform bool auto_range = true;
uniform int palette : hint_range(0, 5) = 0;
uniform float level : hint_range(0.0, 1.0) = 0.5;
uniform float span : hint_range(0.1, 1.5) = 0.8;
uniform int sensor : hint_range(80, 640) = 320;
uniform float bloom : hint_range(0.0, 1.0) = 0.4;
uniform float msx : hint_range(0.0, 1.0) = 0.4;
uniform float noise : hint_range(0.0, 1.0) = 0.3;
uniform float stripes : hint_range(0.0, 1.0) = 0.45;
uniform float shutter : hint_range(0.0, 30.0) = 8.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform float time;
uniform float clip_time;
uniform float seq_fps;

const vec3 IRON[9] = vec3[](vec3(0.0, 0.0, 0.04), vec3(0.13, 0.0, 0.4), vec3(0.42, 0.0, 0.57), vec3(0.67, 0.07, 0.5), vec3(0.86, 0.24, 0.25), vec3(0.96, 0.45, 0.05), vec3(1.0, 0.67, 0.0), vec3(1.0, 0.88, 0.3), vec3(1.0, 1.0, 0.85));
const float IRON_T[9] = float[](0.0, 0.13, 0.27, 0.4, 0.52, 0.64, 0.78, 0.9, 1.0);
const vec3 RAIN[9] = vec3[](vec3(0.04, 0.0, 0.2), vec3(0.08, 0.0, 0.6), vec3(0.0, 0.2, 0.95), vec3(0.0, 0.65, 0.95), vec3(0.0, 0.85, 0.35), vec3(0.65, 0.95, 0.0), vec3(1.0, 0.8, 0.0), vec3(1.0, 0.3, 0.0), vec3(1.0, 0.95, 0.95));
const float RAIN_T[9] = float[](0.0, 0.1, 0.24, 0.37, 0.5, 0.62, 0.74, 0.88, 1.0);
const vec3 LAVA[9] = vec3[](vec3(0.0, 0.0, 0.0), vec3(0.04, 0.1, 0.25), vec3(0.03, 0.3, 0.42), vec3(0.15, 0.45, 0.42), vec3(0.55, 0.4, 0.3), vec3(0.85, 0.3, 0.05), vec3(0.98, 0.55, 0.05), vec3(1.0, 0.82, 0.3), vec3(1.0, 1.0, 0.9));
const float LAVA_T[9] = float[](0.0, 0.14, 0.28, 0.4, 0.5, 0.62, 0.75, 0.88, 1.0);
const vec3 ARCT[9] = vec3[](vec3(0.0, 0.0, 0.08), vec3(0.02, 0.08, 0.35), vec3(0.06, 0.25, 0.62), vec3(0.2, 0.5, 0.85), vec3(0.55, 0.75, 0.95), vec3(0.85, 0.75, 0.6), vec3(0.95, 0.65, 0.2), vec3(1.0, 0.82, 0.25), vec3(1.0, 1.0, 0.7));
const float ARCT_T[9] = float[](0.0, 0.14, 0.28, 0.42, 0.55, 0.64, 0.75, 0.88, 1.0);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 ramp(float t) {
	t = clamp(t, 0.0, 1.0);
	if (palette == 1) {
		return vec3(t);
	}
	if (palette == 2) {
		return vec3(1.0 - t);
	}
	vec3 out_c = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float t0 = palette == 0 ? IRON_T[i] : (palette == 3 ? RAIN_T[i] : (palette == 4 ? LAVA_T[i] : ARCT_T[i]));
		float t1 = palette == 0 ? IRON_T[i + 1] : (palette == 3 ? RAIN_T[i + 1] : (palette == 4 ? LAVA_T[i + 1] : ARCT_T[i + 1]));
		vec3 c0 = palette == 0 ? IRON[i] : (palette == 3 ? RAIN[i] : (palette == 4 ? LAVA[i] : ARCT[i]));
		vec3 c1 = palette == 0 ? IRON[i + 1] : (palette == 3 ? RAIN[i + 1] : (palette == 4 ? LAVA[i + 1] : ARCT[i + 1]));
		if (t >= t0 && t <= t1) {
			out_c = mix(c0, c1, (t - t0) / max(t1 - t0, 0.0001));
		}
	}
	return out_c;
}

float half_at(vec2 uv) {
	vec4 h = texture(half_tex, clamp(uv, vec2(0.0), vec2(1.0)));
	return h.a > 0.0001 ? h.r / h.a : 0.0;
}

vec2 heat_at(vec2 uv) {
	vec4 h = texture(heat_tex, clamp(uv, vec2(0.0), vec2(1.0)));
	return h.a > 0.0001 ? h.rg / h.a : vec2(0.0);
}

void fragment() {
	vec4 here = texture(heat_tex, UV);
	float a = here.a;
	vec2 full = vec2(textureSize(heat_tex, 0));
	float aspect = full.x / max(full.y, 1.0);
	vec2 grid = vec2(float(sensor), floor(float(sensor) / aspect + 0.5));
	vec2 cell = 1.0 / grid;
	vec2 g = UV * grid - 0.5;
	vec2 gi = floor(g);
	vec2 gf = fract(g);
	float h00 = 0.0;
	float h10 = 0.0;
	float h01 = 0.0;
	float h11 = 0.0;
	for (int k = 0; k < 4; k++) {
		vec2 o = vec2(float(k % 2), float(k / 2));
		vec2 cuv = (gi + o + 0.5) * cell;
		float s = 0.0;
		s += half_at(cuv + cell * vec2(-0.25, -0.25));
		s += half_at(cuv + cell * vec2(0.25, -0.25));
		s += half_at(cuv + cell * vec2(-0.25, 0.25));
		s += half_at(cuv + cell * vec2(0.25, 0.25));
		s *= 0.25;
		vec4 qv = texture(quarter_tex, clamp(cuv, vec2(0.0), vec2(1.0)));
		float qh = qv.a > 0.0001 ? qv.r / qv.a : s;
		s = mix(qh, s, 0.5);
		vec2 sid = gi + o;
		float col_fp = (hash12(vec2(sid.x, 3.0 + float(seed))) - 0.5) * 0.9 + (hash12(vec2(floor(sid.x / 7.0), 9.0 + float(seed))) - 0.5) * 0.5;
		float row_fp = (hash12(vec2(sid.y, 13.0 + float(seed))) - 0.5) * 0.25;
		float frame = floor(time * max(seq_fps, 1.0));
		float pn = hash12(sid + frame * 17.31 + float(seed)) - 0.5;
		float since = shutter > 0.0 ? mod(clip_time, shutter) : 1000.0;
		float drift = shutter > 0.0 ? clamp(since / shutter, 0.0, 1.0) * 0.8 + 0.2 : 1.0;
		s += stripes * drift * (col_fp + row_fp) * 0.06 + noise * pn * 0.035;
		if (k == 0) { h00 = s; }
		if (k == 1) { h10 = s; }
		if (k == 2) { h01 = s; }
		if (k == 3) { h11 = s; }
	}
	vec2 w = gf;
	float heat = mix(mix(h00, h10, w.x), mix(h01, h11, w.x), w.y);
	vec4 bl = texture(bloom_tex, UV);
	float bh = bl.a > 0.0001 ? bl.r / bl.a : 0.0;
	heat += bloom * max(bh - 0.45, 0.0) * 0.7;
	heat = mix(heat, max(heat, bh), bloom * 0.35);
	vec2 r = (UV - 0.5) * vec2(aspect, 1.0);
	heat += 0.035 * (1.0 - dot(r, r) * 1.2);
	if (shutter > 0.0) {
		float since = mod(clip_time, shutter);
		float flag = 1.0 - smoothstep(0.1, 0.16, since);
		if (clip_time < shutter * 0.5) {
			flag = 0.0;
		}
		heat = mix(heat, level + 0.03 * (hash12(floor(UV * grid) + 5.0) - 0.5), flag);
	}
	float lo = level - span * 0.5;
	float width = span;
	if (auto_range) {
		vec3 st = vec3(0.0);
		float sa = 0.0;
		for (int j = 0; j < 4; j++) {
			for (int i = 0; i < 4; i++) {
				vec4 q = texture(TEXTURE, (vec2(float(i), float(j)) + 0.5) / 4.0);
				st += q.rgb;
				sa += q.a;
			}
		}
		float mean = st.r / max(sa, 0.0001);
		float var = max(st.b / max(sa, 0.0001) - mean * mean, 0.0);
		width = max(sqrt(var) * 3.8, 0.1) * span / 0.8;
		lo = mean + (level - 0.5) * 0.5 - width * 0.42;
	}
	float t = (heat - lo) / max(width, 0.001);
	vec3 col = ramp(t);
	vec2 px = 1.0 / full;
	float yc = heat_at(UV).y;
	float yb = (heat_at(UV + px * vec2(2.5, 0.0)).y + heat_at(UV - px * vec2(2.5, 0.0)).y + heat_at(UV + px * vec2(0.0, 2.5)).y + heat_at(UV - px * vec2(0.0, 2.5)).y) * 0.25;
	float dy = yc - yb;
	float hp = clamp(sign(dy) * max(abs(dy) - 0.035, 0.0) * 3.0, -0.3, 0.3);
	col = clamp(col + vec3(hp * msx * 0.5), 0.0, 1.0);
	COLOR = vec4(col * a, a);
}
