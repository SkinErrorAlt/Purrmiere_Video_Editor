shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float px_scale = 1.0;
#define px_out (px_scale * 32.0)
uniform float block_size : hint_range(4.0, 48.0) = 16.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform bool drop_frames = true;

vec3 unpm(vec4 c) {
	return c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
}

vec3 rgb2ycc(vec3 c) {
	float y = dot(c, vec3(0.299, 0.587, 0.114));
	return vec3(y, (c.b - y) * 0.564, (c.r - y) * 0.713);
}

vec3 ycc2rgb(vec3 c) {
	float r = c.x + 1.403 * c.z;
	float b = c.x + 1.773 * c.y;
	float g = (c.x - 0.299 * r - 0.114 * b) / 0.587;
	return vec3(r, g, b);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 frame_at(int age, vec2 uv) {
	vec4 n = texture(effect_tex, uv);
	return unpm(age == 0 ? n : history_frame(age, uv, n));
}

void fragment() {
	vec2 uv_px = fwidth(UV);
	vec4 src = texture(effect_tex, UV);
	vec4 b = texelFetch(TEXTURE, ivec2(0, 0), 0);
	float q = mix(1.0, b.r, strength);
	int age = drop_frames ? int(floor(b.g * 63.0 + 0.5)) : 0;
	if (q > 0.985 && age == 0) {
		COLOR = src;
	} else {
		vec2 px = uv_px;
		float a = max(src.a, 0.0001);
		vec3 orig = frame_at(age, UV);
		if (q > 0.985) {
			COLOR = vec4(orig * a, a);
		} else {
			float bs = max(block_size * px_out, 2.0);
			vec2 bsz = bs * px;
			vec2 cell = floor(UV / bsz);
			vec2 o = cell * bsz;
			vec2 f = (UV - o) / bsz;
			vec3 m = vec3(0.0);
			vec3 qd[4];
			for (int i = 0; i < 4; i++) {
				qd[i] = vec3(0.0);
			}
			for (int j = 0; j < 4; j++) {
				for (int i = 0; i < 4; i++) {
					vec3 c = rgb2ycc(frame_at(age, o + (vec2(float(i), float(j)) + 0.5) / 4.0 * bsz));
					m += c;
					qd[(j / 2) * 2 + (i / 2)] += c;
				}
			}
			m /= 16.0;
			for (int i = 0; i < 4; i++) {
				qd[i] /= 4.0;
			}
			vec3 gx = ((qd[1] + qd[3]) - (qd[0] + qd[2])) * 0.5;
			vec3 gy = ((qd[2] + qd[3]) - (qd[0] + qd[1])) * 0.5;
			float busy = clamp((length(gx.x) + length(gy.x)) * 4.0, 0.0, 1.0);
			float qb = clamp(q - busy * 0.25 * (1.0 - q) + (hash12(cell + 7.0) - 0.5) * 0.12, 0.0, 1.0);
			vec2 csz = bsz * 2.0;
			vec2 co = floor(UV / csz) * csz;
			vec2 cm = vec2(0.0);
			for (int j = 0; j < 3; j++) {
				for (int i = 0; i < 3; i++) {
					cm += rgb2ycc(frame_at(age, co + (vec2(float(i), float(j)) + 0.5) / 3.0 * csz)).yz;
				}
			}
			cm /= 9.0;
			vec3 c0 = rgb2ycc(orig);
			vec3 dc = m;
			vec3 slope = m + gx * (f.x - 0.5) * 2.0 + gy * (f.y - 0.5) * 2.0;
			float qstep = mix(0.16, 0.012, qb);
			vec3 fine = slope + floor((c0 - slope) / qstep + 0.5) * qstep;
			vec3 y;
			if (qb < 0.35) {
				y = mix(dc, slope, smoothstep(0.15, 0.35, qb));
			} else {
				y = mix(slope, fine, smoothstep(0.35, 0.75, qb));
				y = mix(y, c0, smoothstep(0.75, 1.0, qb));
			}
			vec2 chroma = mix(cm, mix(m.yz, c0.yz, smoothstep(0.5, 1.0, qb)), smoothstep(0.2, 0.9, qb));
			y.yz = chroma;
			vec3 outc = clamp(ycc2rgb(y), 0.0, 1.0);
			COLOR = vec4(outc * a, a);
		}
	}
}
