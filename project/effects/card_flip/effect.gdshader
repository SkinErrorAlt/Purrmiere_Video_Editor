shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.05, 3.0) = 0.45;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int axis : hint_range(0, 1) = 0;
uniform bool reverse = false;
uniform float perspective : hint_range(0.0, 1.0) = 0.5;
uniform float shade : hint_range(0.0, 1.0) = 0.5;
uniform float shrink : hint_range(0.0, 0.8) = 0.15;

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
		float asp = sz.x / sz.y;
		vec2 s = (UV - 0.5) * 2.0 * vec2(asp, 1.0);
		float ex = asp;
		float ey = 1.0;
		if (axis == 1) {
			s = s.yx;
			ex = 1.0;
			ey = asp;
		}
		float e = g * g * (3.0 - 2.0 * g);
		float th = e * 1.5707963 * (is_in ? -1.0 : 1.0) * (reverse ? -1.0 : 1.0);
		float k = 1.0 - clamp(shrink, 0.0, 0.8) * sin(e * 3.1415926 * 0.5);
		s /= max(k, 0.05);
		float dd = mix(14.0, 2.4, clamp(perspective, 0.0, 1.0)) * max(ex, ey);
		float ct = cos(th);
		float sn = sin(th);
		float den = ct * dd - s.x * sn;
		vec4 o = vec4(0.0);
		if (den > 0.00001) {
			float ux = s.x * dd / den;
			float uy = s.y * (dd + ux * sn) / dd;
			vec2 u = vec2(ux, uy);
			vec2 edge_px = (vec2(ex, ey) - abs(u)) * 0.5 * sz.y / max(k, 0.05) * vec2(max(ct, 0.02), 1.0);
			float m = clamp(min(edge_px.x, edge_px.y) / max(ps, 0.5) + 0.5, 0.0, 1.0);
			if (m > 0.0) {
				vec2 uv_src = axis == 1 ? vec2(u.y / asp, u.x) * 0.5 + 0.5 : vec2(u.x / asp, u.y) * 0.5 + 0.5;
				vec4 pic = texture(TEXTURE, clamp(uv_src, vec2(0.0), vec2(1.0)));
				float side = clamp(ux / ex, -1.0, 1.0) * sign(sn);
				float lit = 1.0 - clamp(shade, 0.0, 1.0) * ((1.0 - ct) * 0.75 + 0.25 * max(side, 0.0) * (1.0 - ct));
				o = vec4(pic.rgb * lit, pic.a) * m;
			}
		}
		COLOR = o;
	}
}
