shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.05, 3.0) = 0.45;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform int around : hint_range(0, 1) = 0;
uniform vec4 line_colour : source_color = vec4(0.86, 0.93, 1.0, 1.0);
uniform float glow : hint_range(0.0, 1.0) = 0.6;

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

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	bool is_in = true;
	float g = trans_amount(is_in);
	if (g <= 0.0001) {
		COLOR = c;
	} else {
		vec2 sz = max(tex_size, vec2(1.0));
		float ps = max(px_scale, 0.0001);
		vec2 ctr = clamp(centre, vec2(0.0), vec2(1.0));
		float e1 = smoothstep(0.0, 0.5, g);
		float e2 = smoothstep(0.5, 0.84, g);
		float e3 = smoothstep(0.84, 1.0, g);
		float min_h = max(2.0 * ps / sz.y, 0.0005);
		float min_w = max(3.0 * ps / sz.x, 0.0005);
		float sy = mix(1.0, min_h, e1 * e1 * (3.0 - 2.0 * e1));
		float sx = mix(1.0, min_w, e2 * e2) * (1.0 + 0.06 * e1 * (1.0 - e2));
		vec2 s = vec2(sx, sy);
		vec2 lo = ctr - ctr * s;
		vec2 hi = ctr + (vec2(1.0) - ctr) * s;
		vec2 mid = (lo + hi) * 0.5;
		vec2 half_px = (hi - lo) * 0.5 * sz;
		vec2 dpx = abs(UV - mid) * sz - half_px;
		float outside = length(max(dpx, vec2(0.0)));
		float m = clamp(1.0 - outside / max(ps, 0.5), 0.0, 1.0);
		vec2 q = clamp(ctr + (UV - ctr) / s, vec2(0.0), vec2(1.0));
		vec4 pic = texture(TEXTURE, q);
		vec3 rgb = pic.a > 0.0001 ? pic.rgb / pic.a : vec3(0.0);
		float whiten = smoothstep(0.3, 0.62, g);
		vec3 col = mix(rgb * (1.0 + 1.8 * e1), line_colour.rgb * 1.2, whiten);
		float pa = mix(pic.a, 1.0, whiten) * m * (1.0 - e3);
		float reach = (10.0 + 30.0 * glow) * ps;
		float gl = clamp(glow, 0.0, 1.0) * exp(-outside / reach) * smoothstep(0.15, 0.55, g) * (1.0 - e3 * 0.85) * (1.0 - m);
		vec3 light = line_colour.rgb * gl;
		if (around == 0) {
			vec3 o = clamp(col, 0.0, 1.0) * pa + light * (1.0 - pa);
			COLOR = vec4(clamp(o, 0.0, 1.0), 1.0);
		} else {
			float la = clamp(gl, 0.0, 1.0);
			float oa = pa + la * (1.0 - pa);
			vec3 o = clamp(col, 0.0, 1.0) * pa + line_colour.rgb * la * (1.0 - pa);
			COLOR = vec4(clamp(o, vec3(0.0), vec3(oa)), oa);
		}
	}
}
