shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.05, 3.0) = 1.0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 start = vec2(0.5, 0.55);
uniform vec4 ink_colour : source_color = vec4(0.03, 0.03, 0.05, 1.0);
uniform float rim : hint_range(0.0, 1.0) = 0.5;
uniform float tendrils : hint_range(0.0, 1.0) = 0.6;
uniform float blots : hint_range(0.0, 1.0) = 0.5;
uniform int seed : hint_range(0, 9999) = 0;

float trans_amount(out bool is_in) {
	float d = max(duration, 0.01);
	if (when == 3) {
		is_in = false;
		return clamp(progress, 0.0, 1.0);
	}
	float a_in = 0.0;
	float a_out = 0.0;
	if (when == 0 || when == 1) {
		a_in = clamp(1.0 - clip_time / d, 0.0, 1.0);
	}
	if (when == 0 || when == 2) {
		a_out = clamp(1.0 - (clip_duration - clip_time) / d, 0.0, 1.0);
	}
	is_in = a_in >= a_out;
	return max(a_in, a_out);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float w = 0.5;
	for (int i = 0; i < 5; i++) {
		s += w * vnoise(p);
		p = p * 2.07 + vec2(11.3, 5.9);
		w *= 0.5;
	}
	return s / 0.97;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	bool is_in = true;
	float g = trans_amount(is_in);
	float s = is_in ? 1.0 - g : g;
	if (s >= 0.9999 && is_in) {
		COLOR = c;
	} else if (s <= 0.0001 && !is_in) {
		COLOR = c;
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		float ps = max(px_scale, 0.0001);
		float asp = sz.x / sz.y;
		vec2 st = clamp(start, vec2(0.0), vec2(1.0));
		vec2 p = vec2((UV.x - st.x) * asp, UV.y - st.y);
		float sd = float(seed) * 3.17 + 1.3;
		float td = clamp(tendrils, 0.0, 1.0);
		vec2 warp = vec2(fbm(p * 2.4 + vec2(sd, 0.0)), fbm(p * 2.4 + vec2(0.0, sd) + 5.2)) - 0.5;
		float fringe = (fbm(p * 14.0 + vec2(sd * 1.7, 3.1)) - 0.5) * 0.14 * td;
		vec2 pw = p + warp * 0.55 * td;
		float f = length(pw) + fringe;
		float far_corner = 0.0;
		far_corner = max(far_corner, length(vec2(-st.x * asp, -st.y)));
		far_corner = max(far_corner, length(vec2((1.0 - st.x) * asp, -st.y)));
		far_corner = max(far_corner, length(vec2(-st.x * asp, 1.0 - st.y)));
		far_corner = max(far_corner, length(vec2((1.0 - st.x) * asp, 1.0 - st.y)));
		float span = far_corner + 0.45;
		for (int i = 0; i < 6; i++) {
			float fi = float(i);
			float h = hash12(vec2(fi * 7.1 + sd, 2.3));
			if (h < clamp(blots, 0.0, 1.0)) {
				vec2 b = vec2(hash12(vec2(fi, sd + 9.1)) * asp, hash12(vec2(sd + 4.4, fi)));
				vec2 bp = vec2(UV.x * asp, UV.y) - b + warp * 0.4 * td;
				float delay = 0.18 + 0.45 * hash12(vec2(fi + 0.5, sd * 0.3));
				float fb = length(bp) * 1.35 + fringe + delay * span;
				f = min(f, fb);
			}
		}
		float t = s * span - 0.1;
		float aa = 1.5 * ps / sz.y;
		float covered = smoothstep(t + aa, t - aa, f);
		float rw = 0.02 + 0.06 * clamp(rim, 0.0, 1.0);
		float vis = is_in ? covered : 1.0 - covered;
		float edge = 0.0;
		if (is_in) {
			edge = smoothstep(t - rw, t - rw * 0.2, f) * covered;
		} else {
			edge = smoothstep(t + rw, t + rw * 0.2, f) * (1.0 - covered);
		}
		edge *= clamp(rim, 0.0, 1.0);
		float a = c.a;
		vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
		vec3 o = mix(rgb, ink_colour.rgb, clamp(edge * 1.2, 0.0, 1.0));
		float oa = mix(a, 1.0, edge) * vis;
		COLOR = vec4(clamp(o, 0.0, 1.0) * oa, oa);
	}
}
