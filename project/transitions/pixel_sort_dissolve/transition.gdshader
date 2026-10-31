shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 2;
uniform float low : hint_range(0.0, 1.0) = 0.25;
uniform float high : hint_range(0.0, 1.0) = 0.9;
uniform float max_length : hint_range(20.0, 800.0) = 320.0;
uniform int mode = 0;
uniform int curve = 1;

const vec3 PS_LUMA = vec3(0.299, 0.587, 0.114);

vec4 ps_pic(vec2 uv, float m) {
	vec2 q = clamp(uv, vec2(0.0), vec2(1.0));
	if (m <= 0.0) {
		return texture(from_tex, q);
	}
	if (m >= 1.0) {
		return texture(to_tex, q);
	}
	return mix(texture(from_tex, q), texture(to_tex, q), m);
}

bool ps_in(vec4 c, float lo, float hi) {
	float l = dot(c.rgb, PS_LUMA);
	return l > lo && l <= hi;
}

vec4 transition(vec2 uv) {
	float p = progress;
	float pe = tr_ease(p, curve == 1 ? 3 : 0);
	float e = max(sin(TR_PI * p), 0.0);
	float env = e * e * (3.0 - 2.0 * e);
	vec2 seq = frame_px / max(px_scale, 0.0001);
	bool horizontal = direction < 2;
	float along_len = horizontal ? seq.x : seq.y;
	vec2 step_uv = horizontal ? vec2(1.0 / seq.x, 0.0) : vec2(0.0, 1.0 / seq.y);
	float a = horizontal ? uv.x * seq.x : uv.y * seq.y;
	if (direction == 1 || direction == 3) {
		step_uv = -step_uv;
		a = along_len - a;
	}
	float row = horizontal ? floor(uv.y * seq.y) : floor(uv.x * seq.x);
	float lo = mix(high, min(low, high), env);
	float hi = high;
	if (mode == 1) {
		float line = pe * along_len;
		vec2 at_line = uv + step_uv * (line - a);
		if (a < line) {
			return to_at(uv);
		}
		vec4 src = texture(to_tex, clamp(at_line, vec2(0.0), vec2(1.0)));
		float l = dot(src.rgb, PS_LUMA);
		float span = max(hi - min(low, hi), 0.001);
		float reach = max_length * env * clamp((l - min(low, hi)) / span, 0.0, 1.0) * (0.6 + 0.4 * tr_hash(vec2(row, 3.0)));
		if (l > min(low, hi) && l <= hi && a - line < reach) {
			float fadeout = 1.0 - smoothstep(0.7, 1.0, (a - line) / max(reach, 0.001));
			return mix(from_at(uv), src, fadeout);
		}
		return from_at(uv);
	}
	float m = smoothstep(0.42, 0.58, p);
	vec4 here = ps_pic(uv, m);
	if (!(here.a >= 0.0) || !ps_in(here, lo, hi) || env <= 0.0) {
		if (m <= 0.0) {
			return from_at(uv);
		}
		if (m >= 1.0) {
			return to_at(uv);
		}
		return mix(from_at(uv), to_at(uv), m);
	}
	float L = max_length;
	float off = tr_hash(vec2(row, 17.0)) * L;
	float cs = floor((a + off) / L) * L - off;
	float ce = cs + L;
	cs = max(cs, 0.0);
	ce = min(ce, along_len);
	float st = (ce - cs) / 24.0;
	float ka = floor((a - cs) / st);
	vec4 cmin = here;
	vec4 cmax = here;
	float lmin = 2.0;
	float lmax = -1.0;
	float good = a;
	float bad = cs - 1.0;
	for (int i = 0; i < 25; i++) {
		float x = cs + (ka - float(i) + 0.5) * st;
		if (x < cs) {
			break;
		}
		if (x >= a) {
			continue;
		}
		vec4 c = ps_pic(uv + step_uv * (x - a), m);
		if (!ps_in(c, lo, hi)) {
			bad = x;
			break;
		}
		good = x;
		float l = dot(c.rgb, PS_LUMA);
		if (l < lmin) {
			lmin = l;
			cmin = c;
		}
		if (l > lmax) {
			lmax = l;
			cmax = c;
		}
	}
	float rs = cs;
	if (bad >= cs) {
		for (int k = 0; k < 6; k++) {
			float mid = 0.5 * (good + bad);
			if (ps_in(ps_pic(uv + step_uv * (mid - a), m), lo, hi)) {
				good = mid;
			} else {
				bad = mid;
			}
		}
		rs = good;
	}
	good = a;
	bad = ce + 1.0;
	for (int i = 0; i < 25; i++) {
		float x = cs + (ka + float(i) + 0.5) * st;
		if (x > ce) {
			break;
		}
		if (x < a) {
			continue;
		}
		vec4 c = ps_pic(uv + step_uv * (x - a), m);
		if (!ps_in(c, lo, hi)) {
			bad = x;
			break;
		}
		good = x;
		float l = dot(c.rgb, PS_LUMA);
		if (l < lmin) {
			lmin = l;
			cmin = c;
		}
		if (l > lmax) {
			lmax = l;
			cmax = c;
		}
	}
	float re = ce;
	if (bad <= ce) {
		for (int k = 0; k < 6; k++) {
			float mid = 0.5 * (good + bad);
			if (ps_in(ps_pic(uv + step_uv * (mid - a), m), lo, hi)) {
				good = mid;
			} else {
				bad = mid;
			}
		}
		re = good;
	}
	if (lmax < 0.0) {
		cmin = here;
		cmax = here;
	}
	float t = clamp((a - rs) / max(re - rs, 0.0001), 0.0, 1.0);
	vec4 sorted = mix(cmin, cmax, t);
	float grow = smoothstep(0.0, 0.25, env);
	return mix(here, sorted, grow);
}

void fragment() {
	COLOR = transition(UV);
}
