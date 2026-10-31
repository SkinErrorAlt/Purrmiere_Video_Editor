shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.1, 3.0) = 0.7;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 through = vec2(0.52, 0.5);
uniform float angle : hint_range(-180.0, 180.0) = 8.0;
uniform float rough : hint_range(0.0, 1.0) = 0.6;
uniform float edge : hint_range(0.0, 40.0) = 9.0;
uniform vec4 paper_colour : source_color = vec4(0.96, 0.95, 0.91, 1.0);
uniform float shadow : hint_range(0.0, 1.0) = 0.5;
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

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash11(i), hash11(i + 1.0), u);
}

float rag(float s, float sd) {
	float r = clamp(rough, 0.0, 1.0);
	float v = (noise1(s * 5.0 + sd) - 0.5) * 0.09;
	v += (noise1(s * 17.0 + sd * 1.7) - 0.5) * 0.035;
	v += (noise1(s * 60.0 + sd * 2.3) - 0.5) * 0.012;
	return v * r;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	bool is_in = false;
	float g = trans_amount(is_in);
	if (g <= 0.0001) {
		COLOR = c;
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		float asp = sz.x / sz.y;
		vec2 av = vec2(asp, 1.0);
		float ps = max(px_scale, 0.0001);
		float px = 1.0 / sz.y;
		float sd = float(seed) * 7.77 + 3.0;
		float rad = radians(angle);
		vec2 tdir = vec2(sin(rad), -cos(rad));
		vec2 nrm = vec2(-tdir.y, tdir.x);
		vec2 p0 = clamp(through, vec2(0.0), vec2(1.0)) * av;
		vec2 x = UV * av;
		float e = g * g * (3.0 - 2.0 * g);
		float em = g * g;
		float ew = max(edge, 0.0) * ps * px * smoothstep(0.0, 0.2, g);
		vec4 o = vec4(0.0);
		float sh_a = 0.0;
		for (int k = 0; k < 2; k++) {
			float h = k == 0 ? -1.0 : 1.0;
			float reach = 0.0;
			reach = max(reach, h * dot(vec2(0.0, 0.0) - p0, nrm));
			reach = max(reach, h * dot(vec2(asp, 0.0) - p0, nrm));
			reach = max(reach, h * dot(vec2(0.0, 1.0) - p0, nrm));
			reach = max(reach, h * dot(vec2(asp, 1.0) - p0, nrm));
			float dist = em * (reach + 0.16);
			float ang = h * 0.12 * e;
			vec2 rel = x - p0 - nrm * h * dist;
			float cn = cos(-ang);
			float sn = sin(-ang);
			vec2 q = p0 + vec2(cn * rel.x - sn * rel.y, sn * rel.x + cn * rel.y);
			float s = dot(q - p0, tdir);
			float d = dot(q - p0, nrm) - rag(s, sd) * (0.35 + 0.65 * min(e * 6.0, 1.0));
			float fw = max(fwidth(d), px * 0.5);
			float inside_frame = step(0.0, q.x) * step(q.x, asp) * step(0.0, q.y) * step(q.y, 1.0);
			float fib = ew * (0.35 + 0.65 * noise1(s * 90.0 + sd * 3.0 + h * 11.0)) + ew * 0.4 * (noise1(s * 13.0 + h * 5.0 + sd) - 0.5);
			float paper = clamp(h * d / fw + 0.5, 0.0, 1.0) * inside_frame;
			float pic_m = clamp((h * d - max(fib, 0.0)) / fw + 0.5, 0.0, 1.0);
			vec4 pic = texture(TEXTURE, clamp(q / av, vec2(0.0), vec2(1.0)));
			float grain = 0.94 + 0.06 * noise1(s * 300.0 + dot(q - p0, nrm) * 211.0);
			vec4 pap = vec4(paper_colour.rgb * grain, 1.0);
			vec4 half_c = mix(pap, pic, pic_m) * paper;
			float out_d = -h * d;
			float soft = 0.035 * (0.3 + 0.7 * e);
			float sh = clamp(shadow, 0.0, 1.0) * 0.55 * (1.0 - smoothstep(0.0, soft, out_d)) * step(0.0, out_d) * inside_frame * min(e * 8.0, 1.0);
			sh_a = max(sh_a, sh);
			o = half_c + o * (1.0 - half_c.a);
		}
		vec4 shade_c = vec4(0.0, 0.0, 0.0, sh_a);
		COLOR = o + shade_c * (1.0 - o.a);
	}
}
