shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.1, 3.0) = 0.7;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform int hinge : hint_range(0, 5) = 0;
uniform int opens : hint_range(0, 1) = 0;
uniform float perspective : hint_range(0.0, 1.0) = 0.5;
uniform float shade : hint_range(0.0, 1.0) = 0.5;

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
	bool is_in = false;
	float g = trans_amount(is_in);
	vec2 sz = max(tex_size, vec2(1.0));
	float asp = sz.x / sz.y;
	bool vertical = hinge == 3 || hinge == 4 || hinge == 5;
	vec2 s = (UV - 0.5) * 2.0 * vec2(asp, 1.0);
	float ex = asp;
	float ey = 1.0;
	if (vertical) {
		s = s.yx;
		ex = 1.0;
		ey = asp;
	}
	bool double_door = hinge == 0 || hinge == 5;
	float flip = 1.0;
	if (double_door) {
		flip = s.x < 0.0 ? 1.0 : -1.0;
	} else if (hinge == 2 || hinge == 4) {
		flip = -1.0;
	}
	float sx = s.x * flip;
	float h = -ex;
	float w = double_door ? ex : 2.0 * ex;
	float e = g * g * (3.0 - 2.0 * g);
	float th = e * 1.5707963;
	float sigma = opens == 0 ? 1.0 : -1.0;
	float dd = mix(12.0, 2.6, clamp(perspective, 0.0, 1.0)) * max(ex, ey) + (sigma > 0.0 ? w * 0.2 : 0.0);
	float ct = cos(th);
	float sn = sin(th);
	float den = dd * ct + sigma * sx * sn;
	float r = dd * (sx - h) / max(den, 0.00001);
	float zz = -sigma * r * sn;
	float v = s.y * (dd + zz) / dd;
	float fr = fwidth(r);
	float fv = fwidth(v);
	float mr = clamp(min(r, w - r) / max(fr, 0.00001) + 0.5, 0.0, 1.0);
	float mv = clamp((ey - abs(v)) / max(fv, 0.00001) + 0.5, 0.0, 1.0);
	if (g <= 0.0001) {
		COLOR = c;
	} else if (den <= 0.00001 || dd + zz <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		float fx = (h + r) * flip;
		vec2 face = vertical ? vec2(v / asp, fx) : vec2(fx / asp, v);
		vec4 pic = texture(TEXTURE, clamp(face * 0.5 + 0.5, vec2(0.0), vec2(1.0)));
		float lit = 1.0 - clamp(shade, 0.0, 1.0) * sn * (sigma > 0.0 ? 0.55 : 0.8);
		float fade = sigma > 0.0 ? 1.0 : 1.0 - smoothstep(0.8, 1.0, g);
		COLOR = vec4(pic.rgb * lit, pic.a) * mr * mv * fade;
	}
}
