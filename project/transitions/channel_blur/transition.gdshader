shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float amount : hint_range(0.0, 200.0) = 60.0;
uniform float red : hint_range(0.0, 2.0) = 1.0;
uniform float green : hint_range(0.0, 2.0) = 0.55;
uniform float blue : hint_range(0.0, 2.0) = 0.25;
uniform float offset : hint_range(0.0, 60.0) = 10.0;
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform int curve = 1;

const int FINE = 20;
const float GOLDEN = 2.39996323;

vec4 both_at(vec2 uv, float w, bool need_from, bool need_to) {
	vec2 c = clamp(uv, vec2(0.0), vec2(1.0));
	vec4 v = vec4(0.0);
	if (need_from) {
		v += texture(from_tex, c) * (1.0 - w);
	}
	if (need_to) {
		v += texture(to_tex, c) * w;
	}
	return v;
}

vec4 fine(vec2 pos, float sig, vec2 centre_shift, float w, bool need_from, bool need_to) {
	mat2 turn = mat2(vec2(cos(GOLDEN), sin(GOLDEN)), vec2(-sin(GOLDEN), cos(GOLDEN)));
	vec2 dir = vec2(1.0, 0.0);
	float radius = sig * 2.5;
	vec4 acc = vec4(0.0);
	float tot = 0.0;
	for (int i = 0; i < FINE; i++) {
		float u = (float(i) + 0.5) / float(FINE);
		vec2 o = dir * sqrt(u) * radius;
		float g = exp(-u * 3.125);
		acc += both_at((pos - centre_shift + o) / frame_px, w, need_from, need_to) * g;
		tot += g;
		dir = turn * dir;
	}
	return acc / tot;
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float k = clamp((p - 0.2) / 0.6, 0.0, 1.0);
	float w = curve == 1 ? k * k * (3.0 - 2.0 * k) : k;
	float e = sin(TR_PI * p);
	if (curve == 1) {
		e = e * e * (3.0 - 2.0 * e);
	}
	vec4 a = from_at(uv);
	vec4 b = to_at(uv);
	if (e <= 0.0) {
		return mix(a, b, w);
	}
	float scale = amount * px_scale * e;
	vec3 sig = max(vec3(red, green, blue) * scale * 0.4, vec3(0.05));
	float th = radians(angle);
	vec2 shift = vec2(cos(th), sin(th)) * offset * px_scale * e;
	vec2 sr = shift;
	vec2 sb = -shift;
	bool need_from = w < 1.0;
	bool need_to = w > 0.0;
	vec2 pos = uv * frame_px;
	float reach = max(max(sig.r, sig.g), sig.b) * 2.6 + length(shift);
	float cell = max(4.0, 4.0 * floor(reach / 14.0 + 0.5));
	float quarter = cell * 0.25;
	vec3 use_grid = smoothstep(vec3(cell * 0.3), vec3(cell * 0.55), sig);
	vec3 acc = vec3(0.0);
	vec3 tot = vec3(0.0);
	vec2 al = vec2(0.0);
	if (use_grid.r + use_grid.g + use_grid.b > 0.0) {
		vec2 lo = floor((pos - reach) / cell);
		vec2 hi = floor((pos + reach) / cell);
		vec3 inv = 1.0 / (2.0 * sig * sig);
		for (float j = lo.y; j <= hi.y; j += 1.0) {
			for (float i = lo.x; i <= hi.x; i += 1.0) {
				vec2 c = (vec2(i, j) + 0.5) * cell;
				vec2 dr = pos - c - sr;
				vec2 dg = pos - c;
				vec2 db = pos - c - sb;
				if (dot(dg, dg) > reach * reach) {
					continue;
				}
				vec3 g = exp(-vec3(dot(dr, dr), dot(dg, dg), dot(db, db)) * inv);
				if (g.r + g.g + g.b < 0.0002) {
					continue;
				}
				vec4 v = both_at((c + vec2(-quarter, -quarter)) / frame_px, w, need_from, need_to);
				v += both_at((c + vec2(quarter, -quarter)) / frame_px, w, need_from, need_to);
				v += both_at((c + vec2(-quarter, quarter)) / frame_px, w, need_from, need_to);
				v += both_at((c + vec2(quarter, quarter)) / frame_px, w, need_from, need_to);
				acc += v.rgb * g;
				tot += g * 4.0;
				al += vec2(v.a * g.g, g.g * 4.0);
			}
		}
	}
	vec3 grid = acc / max(tot, vec3(0.000001));
	float grid_a = al.x / max(al.y, 0.000001);
	vec3 rgb = grid;
	float alpha = grid_a;
	if (use_grid.r < 1.0) {
		vec4 f = fine(pos, sig.r, sr, w, need_from, need_to);
		rgb.r = mix(f.r, grid.r, use_grid.r);
	}
	if (use_grid.g < 1.0) {
		vec4 f = fine(pos, sig.g, vec2(0.0), w, need_from, need_to);
		rgb.g = mix(f.g, grid.g, use_grid.g);
		alpha = mix(f.a, grid_a, use_grid.g);
	}
	if (use_grid.b < 1.0) {
		vec4 f = fine(pos, sig.b, sb, w, need_from, need_to);
		rgb.b = mix(f.b, grid.b, use_grid.b);
	}
	alpha = max(alpha, max(rgb.r, max(rgb.g, rgb.b)));
	return vec4(min(rgb, vec3(alpha)), clamp(alpha, 0.0, 1.0));
}

void fragment() {
	COLOR = transition(UV);
}
