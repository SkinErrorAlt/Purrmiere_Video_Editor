shader_type canvas_item;
render_mode blend_disabled;

uniform int toning : hint_range(0, 2) = 0;
uniform float tone_amount : hint_range(0.0, 1.0) = 0.8;
uniform float grain : hint_range(0.0, 1.0) = 0.3;
uniform float scratches : hint_range(0.0, 1.0) = 0.4;
uniform float dust : hint_range(0.0, 1.0) = 0.4;
uniform float weave : hint_range(0.0, 1.0) = 0.3;
uniform float flicker : hint_range(0.0, 1.0) = 0.3;
uniform float vignette : hint_range(0.0, 1.0) = 0.5;
uniform float frame_rate : hint_range(12.0, 30.0) = 18.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 seed_offset(int s) {
	float f = float(s);
	return vec2(mod(f * 12.9898, 997.0), mod(f * 78.233, 991.0));
}

float noise1(float x, float salt, vec2 so) {
	float i = floor(x);
	float f = x - i;
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash12(vec2(i, salt) + so), hash12(vec2(i + 1.0, salt) + so), f);
}

vec3 sepia_tone(float l) {
	vec3 dark = vec3(0.1, 0.06, 0.03);
	vec3 mid = vec3(0.62, 0.48, 0.32);
	vec3 light = vec3(1.0, 0.95, 0.83);
	return l < 0.5 ? mix(dark, mid, l * 2.0) : mix(mid, light, (l - 0.5) * 2.0);
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	vec2 so = seed_offset(seed);
	float ps = max(px_scale, 0.0001);
	float frame = floor(max(clip_time, 0.0) * clamp(frame_rate, 1.0, 60.0));
	float fs = mod(frame, 1009.0);
	vec2 wv = vec2(noise1(frame * 0.35, 1.0, so), noise1(frame * 0.35, 2.0, so)) - 0.5;
	wv += (vec2(hash12(vec2(fs, 3.0) + so), hash12(vec2(fs, 4.0) + so)) - 0.5) * 0.35;
	vec2 shift_px = wv * vec2(2.5, 6.0) * weave * ps;
	vec2 uv = clamp(UV + shift_px / dims, vec2(0.0), vec2(1.0));
	vec4 c = texture(TEXTURE, uv);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	if (toning == 0) {
		rgb = mix(rgb, sepia_tone(clamp(luma, 0.0, 1.0)), tone_amount);
	} else if (toning == 1) {
		rgb = mix(rgb, vec3(luma), tone_amount);
	}
	float fl = 1.0 + (hash12(vec2(fs, 7.0) + so) - 0.5) * 0.3 * flicker + (noise1(frame * 0.2, 8.0, so) - 0.5) * 0.25 * flicker;
	rgb *= fl;
	vec2 gp = floor(UV * dims / max(1.2 * ps, 1.0));
	float gn = hash12(gp + vec2(fs * 13.1, fs * 7.7) + so) + hash12(gp * 1.37 + vec2(fs * 3.3, fs * 5.9) + so) - 1.0;
	rgb += gn * grain * 0.2 * (0.35 + 2.6 * luma * (1.0 - luma));
	for (int k = 0; k < 4; k++) {
		float kk = float(k);
		float life = 8.0 + 8.0 * hash12(vec2(kk, 31.0) + so);
		float seg = floor(frame / life + hash12(vec2(kk, 37.0) + so));
		float segm = mod(seg, 1013.0);
		float show = step(hash12(vec2(segm, kk + 41.0) + so), scratches * 0.8) * step(0.12, hash12(vec2(fs, kk + 43.0) + so));
		float x = hash12(vec2(segm, kk + 47.0) + so) + sin(frame * 0.3 + kk * 1.7) * 0.003;
		float w = (1.0 + 1.5 * hash12(vec2(segm, kk + 53.0) + so)) * ps;
		float d_px = abs(UV.x - x) * dims.x;
		float broken = smoothstep(0.25, 0.45, noise1(UV.y * 7.0 + segm * 3.1, kk + 59.0, so));
		float line = (1.0 - smoothstep(w * 0.5, w * 0.5 + 1.0, d_px)) * show * broken;
		if (hash12(vec2(segm, kk + 61.0) + so) > 0.5) {
			rgb = mix(rgb, vec3(0.95, 0.93, 0.88), line * 0.7);
		} else {
			rgb *= 1.0 - line * 0.6;
		}
	}
	float cell_px = max(48.0 * ps, 8.0);
	vec2 cp = UV * dims / cell_px;
	vec2 cell = floor(cp);
	float speck = hash12(cell + vec2(fs * 1.7, fs * 2.3) + so);
	if (speck < dust * 0.05) {
		vec2 centre = cell + 0.25 + 0.5 * vec2(hash12(cell + vec2(fs, 71.0) + so), hash12(cell + vec2(fs, 73.0) + so));
		vec2 dv = (cp - centre) * cell_px;
		float r = (1.0 + 4.0 * hash12(cell + vec2(fs, 79.0) + so)) * ps;
		float ang = length(dv) > 0.001 ? atan(dv.y, dv.x) : 0.0;
		float r_eff = r * (0.7 + 0.3 * sin(ang * 3.0 + speck * 60.0));
		float cover = 1.0 - smoothstep(r_eff - 0.7, r_eff + 0.7, length(dv));
		float bright = step(0.75, hash12(cell + vec2(fs, 83.0) + so));
		rgb = mix(rgb, mix(vec3(0.04, 0.03, 0.02), vec3(0.95, 0.93, 0.88), bright), cover * 0.9);
	}
	float vd = length(UV - 0.5) * 1.4142136;
	rgb *= 1.0 - vignette * smoothstep(0.35, 1.05, vd) * 0.85;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
