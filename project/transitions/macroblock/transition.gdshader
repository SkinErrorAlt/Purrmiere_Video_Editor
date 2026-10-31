shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int block = 1;
uniform float amount : hint_range(0.0, 1.0) = 0.7;
uniform float bleed : hint_range(0.0, 1.0) = 0.6;
uniform float smear : hint_range(0.0, 1.0) = 0.5;
uniform float channel_split : hint_range(0.0, 1.0) = 0.0;

vec4 mb_pic(vec2 uv, bool use_to) {
	vec2 q = clamp(uv, vec2(0.0), vec2(1.0));
	return use_to ? texture(to_tex, q) : texture(from_tex, q);
}

void mb_avg(vec2 origin, float bpx, vec2 seq, vec2 local, bool use_to, out vec4 whole, out vec4 part) {
	whole = vec4(0.0);
	part = vec4(0.0);
	vec2 quad = step(vec2(0.5), local);
	for (int j = 0; j < 4; j++) {
		for (int i = 0; i < 4; i++) {
			vec2 f = (vec2(float(i), float(j)) + 0.5) / 4.0;
			vec4 c = mb_pic((origin + f * bpx) / seq, use_to);
			whole += c;
			if (step(vec2(0.5), f) == quad) {
				part += c;
			}
		}
	}
	whole /= 16.0;
	part /= 4.0;
}

vec4 transition(vec2 uv) {
	float p = progress;
	float e = max(sin(TR_PI * p), 0.0);
	float env = e * e * (3.0 - 2.0 * e);
	vec2 seq = frame_px / max(px_scale, 0.0001);
	float bpx = block == 0 ? 8.0 : block == 1 ? 16.0 : 32.0;
	vec2 P = uv * seq;
	vec2 blk = floor(P / bpx);
	vec2 local = fract(P / bpx);
	vec2 origin = blk * bpx;
	float tsw = 0.5 + (tr_noise(blk / vec2(9.0, 5.0) + vec2(77.0, 5.0)) * 0.8 + tr_hash(blk + vec2(7.1, 2.3)) * 0.2 - 0.5) * (0.1 + 0.35 * amount);
	bool cur_to = p >= tsw;
	vec4 here = mb_pic(uv, cur_to);
	if (env <= 0.0) {
		return cur_to ? to_at(uv) : from_at(uv);
	}
	float region = tr_noise(blk / vec2(6.0, 3.5) + vec2(11.0, 3.0));
	float h1 = region * 0.75 + tr_hash(blk + vec2(0.5, 0.5)) * 0.25;
	float h2 = mix(tr_noise(blk / 4.0 + vec2(31.0, 17.0)), tr_hash(blk + vec2(3.3, 9.1)), 0.3);
	bool damaged = h1 < env * amount * 0.95;
	vec4 whole;
	vec4 part;
	mb_avg(origin, bpx, seq, local, cur_to, whole, part);
	float q = env * amount * 0.45;
	vec4 outc = part + (here - part) * (1.0 - q);
	if (damaged) {
		float smear_share = 0.25 + 0.35 * smear;
		if (h2 < 0.55 - smear_share * 0.5) {
			vec4 hold = mb_pic(uv, false);
			vec4 wf;
			vec4 pf;
			vec4 wt;
			vec4 pt;
			mb_avg(origin, bpx, seq, local, false, wf, pf);
			mb_avg(origin, bpx, seq, local, true, wt, pt);
			vec3 lum = vec3(0.299, 0.587, 0.114);
			vec3 chroma_shift = (wt.rgb - vec3(dot(wt.rgb, lum))) - (wf.rgb - vec3(dot(wf.rgb, lum)));
			float dc = dot(wt.rgb, lum) - dot(wf.rgb, lum);
			float b = bleed * (cur_to ? 1.0 : 0.5);
			outc = vec4(hold.rgb + (chroma_shift * 1.2 + vec3(dc * 0.8)) * b * hold.a, hold.a);
		} else if (h2 < 1.0 - smear_share) {
			vec3 lum = vec3(0.299, 0.587, 0.114);
			float yl = dot(part.rgb, lum);
			outc = vec4(vec3(yl) + (whole.rgb - vec3(dot(whole.rgb, lum))), whole.a);
		} else {
			bool right = tr_hash(blk + vec2(8.8, 4.4)) < 0.35;
			if (right) {
				float run = 1.0 + floor(tr_hash(vec2(1.9, blk.y)) * (1.0 + 6.0 * smear));
				float start = floor(blk.x / run) * run * bpx;
				float sx = max(start - 0.5, 0.5);
				outc = mb_pic(vec2(sx, P.y) / seq, cur_to);
			} else {
				float run = 1.0 + floor(tr_hash(vec2(blk.x, 5.7)) * (1.0 + 6.0 * smear));
				float start = floor(blk.y / run) * run * bpx;
				float sy = max(start - 0.5, 0.5);
				outc = mb_pic(vec2(P.x, sy) / seq, cur_to);
			}
		}
		if (channel_split > 0.0) {
			vec2 sh = vec2(channel_split * bpx * 0.5, 0.0) / seq;
			outc.r = mix(outc.r, mb_pic(uv - sh, cur_to).r, 1.0);
			outc.b = mix(outc.b, mb_pic(uv + sh, cur_to).b, 1.0);
		}
	}
	outc.rgb = clamp(outc.rgb, vec3(0.0), vec3(outc.a));
	return outc;
}

void fragment() {
	COLOR = transition(UV);
}
