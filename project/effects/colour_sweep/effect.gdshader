shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time = 0.0;
uniform float clip_duration = 1.0;
uniform int when : hint_range(0, 3) = 0;
uniform float duration : hint_range(0.1, 3.0) = 0.6;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float angle : hint_range(-180.0, 180.0) = 90.0;
uniform int bands : hint_range(1, 4) = 3;
uniform vec4 colour_1 : source_color = vec4(0.98, 0.27, 0.42, 1.0);
uniform vec4 colour_2 : source_color = vec4(1.0, 0.78, 0.2, 1.0);
uniform vec4 colour_3 : source_color = vec4(0.16, 0.6, 1.0, 1.0);
uniform vec4 colour_4 : source_color = vec4(0.1, 0.1, 0.14, 1.0);
uniform float slant : hint_range(-60.0, 60.0) = 20.0;
uniform float stagger : hint_range(0.0, 0.9) = 0.45;
uniform float shadow : hint_range(0.0, 1.0) = 0.3;

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

vec3 band_colour(int i) {
	if (i == 0) {
		return colour_1.rgb;
	}
	if (i == 1) {
		return colour_2.rgb;
	}
	if (i == 2) {
		return colour_3.rgb;
	}
	return colour_4.rgb;
}

float ease(float x) {
	x = clamp(x, 0.0, 1.0);
	return x < 0.5 ? 4.0 * x * x * x : 1.0 - pow(-2.0 * x + 2.0, 3.0) * 0.5;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	bool is_in = false;
	float g = trans_amount(is_in);
	vec2 sz = max(tex_size, vec2(1.0));
	float asp = sz.x / sz.y;
	float rad = radians(angle);
	vec2 dir = vec2(sin(rad), -cos(rad));
	vec2 perp = vec2(-dir.y, dir.x);
	float t = tan(radians(clamp(slant, -60.0, 60.0)));
	vec2 axis_v = dir + perp * t;
	vec2 p = (UV - 0.5) * vec2(asp, 1.0);
	float ext = abs(axis_v.x) * asp * 0.5 + abs(axis_v.y) * 0.5;
	float x = dot(p, axis_v) / max(2.0 * ext, 0.0001) + 0.5;
	float fw = max(fwidth(x), 0.00001);
	if (g <= 0.0001) {
		COLOR = c;
	} else {
		int n = clamp(bands, 1, 4);
		float st = clamp(stagger, 0.0, 0.9);
		float nm = max(float(n - 1), 1.0);
		vec4 o = c;
		float shade_w = 0.035;
		for (int i = 0; i < 4; i++) {
			if (i >= n) {
				break;
			}
			float cover = 0.0;
			float edge_d = 0.0;
			if (!is_in) {
				float oi = n == 1 ? 0.0 : st * float(i) / nm;
				float lp = mix(-0.03, 1.03 + shade_w, ease((g - oi) / max(1.0 - st, 0.0001)));
				cover = clamp((lp - x) / fw + 0.5, 0.0, 1.0);
				edge_d = lp - x;
			} else {
				float oi = n == 1 ? 0.0 : st * float(n - 1 - i) / nm;
				float rp = mix(-0.03 - shade_w, 1.03, ease((1.0 - g - oi) / max(1.0 - st, 0.0001)));
				cover = clamp((x - rp) / fw + 0.5, 0.0, 1.0);
				edge_d = x - rp;
			}
			float sh = clamp(shadow, 0.0, 1.0) * 0.5 * (1.0 - smoothstep(0.0, shade_w, -edge_d)) * step(edge_d, 0.0);
			o = vec4(o.rgb * (1.0 - sh), o.a + sh * (1.0 - o.a));
			vec4 b = vec4(clamp(band_colour(i), vec3(0.0), vec3(1.0)), 1.0);
			o = mix(o, b, cover);
		}
		COLOR = o;
	}
}
