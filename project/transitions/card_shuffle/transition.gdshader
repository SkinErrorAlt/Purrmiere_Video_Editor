shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int cards : hint_range(3, 12) = 8;
uniform float fan : hint_range(0.0, 1.0) = 0.46;
uniform float turn : hint_range(0.0, 45.0) = 16.0;
uniform float shrink : hint_range(0.3, 1.0) = 0.52;
uniform int flips : hint_range(0, 12) = 3;
uniform float frames : hint_range(0.0, 1.0) = 0.6;
uniform float shadow : hint_range(0.0, 1.0) = 0.6;
uniform vec4 back : source_color = vec4(0.16, 0.2, 0.35, 1.0);
uniform vec4 backdrop : source_color = vec4(0.04, 0.04, 0.05, 1.0);
uniform sampler2D back_picture : source_color, hint_default_transparent, filter_linear, repeat_disable;
uniform sampler2D face_picture : source_color, hint_default_transparent, filter_linear, repeat_disable;
uniform float face_share : hint_range(0.0, 1.0) = 0.5;

vec4 cs_pass(vec2 uv, float p, float dir) {
	float n = float(clamp(cards, 3, 12));
	float a = smoothstep(0.08, 0.46, p);
	float b = smoothstep(0.46, 0.84, p);
	float c = smoothstep(0.76, 1.0, p);
	float spread = a * (1.0 - b);
	float opened = max(a - c, 0.0);
	vec2 ar = vec2(tr_ratio(), 1.0);
	vec4 col = backdrop;
	float rad = 0.11 * opened;
	float bw = 0.055 * opened;
	vec3 ivory = vec3(0.95, 0.94, 0.9);
	for (int t = 0; t < 12; t++) {
		if (float(t) >= n) {
			break;
		}
		float jf = dir < 0.5 ? float(t) : n - 1.0 - float(t);
		float hz = tr_hash(vec2(jf, 4.7) + seed);
		float side = mod(jf + floor(hz * 1.7), 2.0) < 1.0 ? -1.0 : 1.0;
		float kk = (jf - (n - 1.0) * 0.5) / max(n - 1.0, 1.0);
		float inh = clamp(abs(kk) * 2.0, 0.0, 1.0);
		float hop = sin(spread * TR_PI) * (0.3 + 0.7 * hz);
		vec2 off = vec2(side * fan * (0.3 + 0.7 * inh), -fan * 0.22 * hop) * spread;
		off += vec2(kk * fan * 0.4, kk * fan * 0.12) * opened;
		float ang = radians(turn) * ((side * 0.8 + kk * 0.9) * spread + kk * 0.35 * opened);
		float sc = mix(1.0, clamp(shrink, 0.3, 1.0), opened);
		float ft = jf < float(flips) ? smoothstep(0.0, 1.0, clamp((p - 0.18 - 0.02 * jf) / 0.45, 0.0, 1.0)) : 0.0;
		float cf = cos(ft * TR_PI * 2.0);
		vec2 d = (uv - vec2(0.5) - off) * ar;
		float cg = cos(-ang);
		float sg = sin(-ang);
		vec2 r = vec2(cg * d.x - sg * d.y, sg * d.x + cg * d.y) / max(sc, 0.0001);
		r.x /= max(abs(cf), 0.06);
		vec2 src = vec2(0.5) + r / ar;
		vec2 q = (src - vec2(0.5)) * 2.0;
		vec2 ee = abs(q) - vec2(1.0 - rad);
		float dd = min(max(ee.x, ee.y), 0.0) + length(max(ee, vec2(0.0))) - rad;
		float sq = 0.014;
		float cov = 1.0 - smoothstep(-sq, sq, dd);
		if (cov <= 0.0) {
			continue;
		}
		float tt = jf / max(n - 1.0, 1.0);
		float blendk = mix(step(0.5, tt), tt, clamp(frames, 0.0, 1.0));
		vec2 ssrc = clamp(src, vec2(0.0), vec2(1.0));
		vec4 face = mix(to_clamped(ssrc), from_clamped(ssrc), blendk);
		vec4 own_face = texture(face_picture, ssrc);
		float middle = 1.0 - step(face_share * 0.5, abs(tt - 0.5));
		if (own_face.a > 0.0 && middle > 0.5 && jf > 0.5 && jf < n - 1.5) {
			face = vec4(mix(face.rgb, own_face.rgb / max(own_face.a, 0.0001), own_face.a), 1.0);
		}
		if (cf < 0.0) {
			vec4 own_back = texture(back_picture, vec2(1.0 - ssrc.x, ssrc.y));
			face = back;
			face.rgb = mix(face.rgb, own_back.rgb / max(own_back.a, 0.0001), own_back.a);
			face.rgb *= mix(0.86, 1.08, src.y);
		}
		float inner = 1.0 - smoothstep(-bw - sq, -bw + sq, dd);
		vec4 shown = face;
		shown.rgb = mix(ivory, face.rgb, bw > 0.0 ? inner : 1.0);
		shown.rgb *= mix(1.0, 0.84 + 0.3 * (1.0 - inh), opened * 0.85);
		vec2 shq = q - vec2(0.07, 0.07);
		vec2 se = abs(shq) - vec2(1.0 - rad);
		float sdd = min(max(se.x, se.y), 0.0) + length(max(se, vec2(0.0))) - rad;
		float shw = (1.0 - smoothstep(-0.03, 0.14, sdd)) * shadow * opened * 0.6;
		col.rgb *= 1.0 - shw * (1.0 - cov);
		col = mix(col, shown, cov);
	}
	return col;
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float sw = smoothstep(0.44, 0.5, p);
	if (sw <= 0.0) {
		return cs_pass(uv, p, 0.0);
	}
	if (sw >= 1.0) {
		return cs_pass(uv, p, 1.0);
	}
	return mix(cs_pass(uv, p, 0.0), cs_pass(uv, p, 1.0), sw);
}

void fragment() {
	COLOR = transition(UV);
}
