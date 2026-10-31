shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float damage : hint_range(0.0, 1.0) = 0.8;
uniform float tracking : hint_range(0.0, 1.0) = 0.7;
uniform float jitter : hint_range(0.0, 1.0) = 0.5;
uniform float chroma_bleed : hint_range(0.0, 1.0) = 0.7;
uniform float noise : hint_range(0.0, 1.0) = 0.5;
uniform float colour_loss : hint_range(0.0, 1.0) = 0.4;

const vec3 VHS_LUMA = vec3(0.299, 0.587, 0.114);

vec4 vhs_pic(vec2 uv, float m) {
	if (m <= 0.0) {
		return from_at(uv);
	}
	if (m >= 1.0) {
		return to_at(uv);
	}
	return mix(from_at(uv), to_at(uv), m);
}

vec4 transition(vec2 uv) {
	float p = progress;
	float e = max(sin(TR_PI * p), 0.0);
	float env = e * e * (3.0 - 2.0 * e) * damage;
	vec2 seq = frame_px / max(px_scale, 0.0001);
	float lines = seq.y * 0.5;
	float yl = uv.y * lines;
	float line = floor(yl);
	float fi = floor(p * max(duration, 0.05) * 30.0);
	float hb = max((0.03 + 0.12 * e) * (0.35 + 0.65 * tracking), 0.001);
	float yb = 1.2 - 1.4 * p;
	float dband = abs(uv.y - yb) + (tr_hash(vec2(line, fi + 1.7)) - 0.5) * hb * 0.5;
	float bw = (1.0 - smoothstep(hb * 0.3, hb, dband)) * env * tracking;
	float burst = (1.0 - smoothstep(0.015, 0.07, abs(p - 0.5))) * damage * step(0.0001, env);
	bw = max(bw, burst * (0.45 + 0.35 * tr_noise(vec2(line / 9.0, fi * 2.3 + 4.0))));
	float jb = tr_noise(vec2(line / 13.0, fi * 3.17 + 0.5)) - 0.5;
	float jl = tr_hash(vec2(line, fi + 11.0)) - 0.5;
	float chunk = floor(line / 23.0);
	float tear = step(0.86, tr_hash(vec2(chunk, fi + 5.0))) * (tr_hash(vec2(chunk, fi + 9.0)) - 0.5);
	float shift = env * jitter * (jb * 22.0 + jl * 2.5 + tear * 50.0);
	float bs = tr_noise(vec2(line / 3.0, fi * 5.3 + 2.0));
	shift += bw * (bs * 50.0 + 10.0);
	float hs = clamp((yl - (lines - 7.0)) / 7.0, 0.0, 1.0);
	shift += env * hs * hs * (50.0 + 40.0 * tr_hash(vec2(line, fi + 21.0)));
	vec2 su = uv - vec2(shift / seq.x, 0.0);
	float m = smoothstep(0.485, 0.515, p);
	float lw = env * 1.6 / seq.x;
	vec4 c0 = vhs_pic(su, m);
	vec4 cl = vhs_pic(su - vec2(lw, 0.0), m);
	vec4 cr = vhs_pic(su + vec2(lw, 0.0), m);
	vec4 soft = cl * 0.25 + c0 * 0.5 + cr * 0.25;
	float y = dot(soft.rgb, VHS_LUMA);
	float a = soft.a;
	float cs = env * chroma_bleed * 3.4 / seq.x;
	float delay = env * chroma_bleed * 2.5 / seq.x;
	vec3 chroma = vec3(0.0);
	float wsum = 0.0;
	for (int k = 0; k < 6; k++) {
		float w = exp(-0.45 * float(k));
		vec4 ck = k == 0 && delay <= 0.0 ? c0 : vhs_pic(su - vec2(delay + cs * float(k), 0.0), m);
		chroma += (ck.rgb - vec3(dot(ck.rgb, VHS_LUMA))) * w;
		wsum += w;
	}
	chroma /= wsum;
	chroma *= 1.0 - colour_loss * env * 0.85 - bw * 0.5;
	float px = uv.x * seq.x;
	float n1 = tr_noise(vec2(px / 4.5 + fi * 37.0, line)) - 0.5;
	float n2 = tr_noise(vec2(px / 45.0 + fi * 17.0, line * 0.5)) - 0.5;
	float cl1 = tr_noise(vec2(px / 16.0 + fi * 11.0, floor(line / 2.0))) - 0.5;
	float cl2 = tr_noise(vec2(px / 16.0 + fi * 13.0, floor(line / 2.0) + 57.0)) - 0.5;
	chroma += vec3(cl1 * 0.6, -cl1 * 0.3 - cl2 * 0.3, cl2 * 0.6) * (0.06 * noise * env + 0.05 * bw) * a;
	chroma *= 1.0 - burst * 0.6;
	float dy = (n1 * 0.2 + n2 * 0.1) * noise * env + (n1 * 0.3 + 0.05) * bw;
	dy += hs * env * (tr_noise(vec2(px / 6.0, line + fi * 3.0)) - 0.4) * 0.5;
	y = mix(y, 0.3 * a, burst * 0.35);
	vec3 base = vec3(y) + chroma;
	vec3 noisy = dy >= 0.0 ? base + vec3(dy * a) : base * max(1.0 + dy / max(y, 0.05), 0.0);
	float lh = 1.0 + floor(tr_hash(vec2(floor(line / 3.0), fi + 51.0)) * 2.99);
	float sr = floor(line / lh);
	float sl = 40.0 + 160.0 * tr_hash(vec2(sr, fi + 41.0));
	float sx = px + tr_hash(vec2(sr, fi + 43.0)) * sl;
	float cell = floor(sx / sl);
	float sv = tr_hash(vec2(cell, sr + fi * 7.0));
	float thr = 1.0 - 0.55 * bw - 0.003 * env * tracking;
	float lfr = 0.35 + 0.6 * tr_hash(vec2(cell + 3.0, sr + fi * 5.0));
	float fpos = fract(sx / sl) * sl;
	float soft_end = 4.0 + 6.0 * tr_hash(vec2(cell, sr + 17.0));
	float shape = smoothstep(0.0, soft_end, fpos) * smoothstep(0.0, soft_end * 2.2, lfr * sl - fpos) * (0.75 + 0.25 * tr_noise(vec2(px / 22.0, sr + fi * 9.0)));
	float streak = step(thr, sv) * shape * step(0.0001, env);
	float sb = tr_hash(vec2(cell + 9.0, sr + fi * 3.0));
	vec3 tint_s = mix(vec3(1.0, 0.97, 0.92), vec3(0.9, 0.96, 1.0), tr_hash(vec2(sr, cell + 21.0)));
	vec3 scol = sb < 0.12 ? vec3(0.05) : tint_s * (0.5 + 0.5 * sb);
	float sa2 = streak * 0.95;
	vec3 rgb = mix(noisy, scol * max(a, 0.35), sa2);
	float oa = max(a, sa2 * 0.95);
	float cover = (1.0 - smoothstep(0.03, 0.06, abs(p - 0.5))) * smoothstep(0.0, 0.25, damage) * step(0.0001, env);
	float snow = 0.12 + 0.7 * tr_noise(vec2(px / 3.0 + fi * 31.0, line)) * (0.6 + 0.4 * tr_noise(vec2(px / 60.0 + fi * 7.0, line / 4.0)));
	vec3 snow_c = vec3(snow) * mix(vec3(1.0), tint_s, 0.5);
	snow_c = mix(snow_c, scol, sa2);
	rgb = mix(rgb, snow_c, cover);
	oa = mix(oa, 1.0, cover);
	return vec4(clamp(rgb, vec3(0.0), vec3(oa)), oa);
}

void fragment() {
	COLOR = transition(UV);
}
