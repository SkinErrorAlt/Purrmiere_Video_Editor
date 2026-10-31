shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.05, 3.0) = 0.9;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int strokes : hint_range(2, 8) = 4;
uniform float angle : hint_range(-180.0, 180.0) = 90.0;
uniform float rough : hint_range(0.0, 1.0) = 0.6;
uniform float paint : hint_range(0.0, 1.0) = 0.0;
uniform vec4 paint_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
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

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	bool is_in = true;
	float g = trans_amount(is_in);
	float s = is_in ? 1.0 - g : g;
	if ((is_in && s >= 0.9999) || (!is_in && s <= 0.0001)) {
		COLOR = c;
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		float ps = max(px_scale, 0.0001);
		float rad = radians(angle);
		vec2 dir = vec2(sin(rad), -cos(rad));
		vec2 nrm = vec2(-dir.y, dir.x);
		vec2 pc = UV * sz - 0.5 * sz;
		float ext_d = abs(dir.x) * sz.x + abs(dir.y) * sz.y;
		float ext_n = abs(nrm.x) * sz.x + abs(nrm.y) * sz.y;
		float x = dot(pc, dir) / ext_d + 0.5;
		float y = dot(pc, nrm) / ext_n + 0.5;
		int n = clamp(strokes, 2, 8);
		float nf = float(n);
		float bh = 1.0 / nf;
		float rg = clamp(rough, 0.0, 1.0);
		float sd = float(seed) * 5.3 + 0.7;
		float len_share = min(1.6 / nf, 1.0);
		float gap = (1.0 - len_share) / max(nf - 1.0, 1.0);
		float aa_x = 1.2 * ps / ext_d;
		float aa_y = 1.2 * ps / ext_n;
		float cov = 0.0;
		float tip = 0.0;
		for (int i = 0; i < 8; i++) {
			if (i >= n) {
				break;
			}
			float fi = float(i);
			float yc = (fi + 0.5) * bh;
			float half_w = bh * 0.5 * 1.45;
			float yy = y - yc;
			float xs = (i % 2 == 1) ? 1.0 - x : x;
			float en = (vnoise(vec2(xs * 7.0 + fi * 13.1, sd)) - 0.5) * 0.35 * rg * bh;
			float band = smoothstep(half_w + en + aa_y, half_w + en - aa_y, abs(yy));
			if (band <= 0.0) {
				continue;
			}
			float local = clamp((s - fi * gap) / len_share, 0.0, 1.0);
			float eased = 1.0 - (1.0 - local) * (1.0 - local);
			float head = mix(-0.2, 1.4, eased);
			float across = abs(yy) / half_w;
			float br = vnoise(vec2(xs * 3.0 + fi * 5.7, y * 70.0 * nf + sd));
			float head_n = head - 0.05 * across * across - (br - 0.5) * 0.14 * rg;
			float painted = band * smoothstep(head_n + aa_x, head_n - aa_x, xs);
			float dry = smoothstep(head - 0.25, head - 0.05, xs) * smoothstep(0.55, 0.95, across);
			float dry_gap = step(br, 0.45 * rg) * dry;
			painted *= 1.0 - dry_gap;
			float near_tip = smoothstep(head_n - 0.1, head_n - 0.01, xs) * painted;
			if (painted > cov) {
				tip = near_tip;
			}
			cov = max(cov, painted);
		}
		float vis = is_in ? cov : 1.0 - cov;
		float a = c.a;
		vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
		float pk = clamp(paint, 0.0, 1.0) * tip * (is_in ? 1.0 : 0.0);
		float pk_out = clamp(paint, 0.0, 1.0) * tip * (is_in ? 0.0 : 1.0);
		vec3 o = mix(rgb, paint_colour.rgb, pk);
		float oa = mix(a, 1.0, pk) * vis;
		vec3 prem = clamp(o, 0.0, 1.0) * oa + paint_colour.rgb * pk_out * cov;
		float fa = oa + pk_out * cov * (1.0 - oa);
		COLOR = vec4(clamp(prem, vec3(0.0), vec3(fa)), fa);
	}
}
