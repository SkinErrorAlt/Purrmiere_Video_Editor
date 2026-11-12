shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float max_time : hint_range(0.03, 2.0) = 0.6;
uniform int map = 0;
uniform sampler2D picture : filter_linear, repeat_disable, hint_default_black;
uniform bool invert = false;
uniform float contrast : hint_range(0.2, 4.0) = 1.0;
uniform float map_smooth : hint_range(0.0, 40.0) = 6.0;
uniform int steps : hint_range(0, 32) = 0;
uniform vec2 centre = vec2(0.5, 0.5);

float luma(vec4 c) {
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	return dot(rgb, vec3(0.2126, 0.7152, 0.0722)) * c.a;
}

float soft_luma(sampler2D tex, vec2 uv, float radius_px) {
	if (radius_px < 0.5) {
		return luma(texture(tex, uv));
	}
	vec2 px = radius_px / tex_size;
	float sum = 0.0;
	float wsum = 0.0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec2 o = vec2(float(x), float(y)) * 0.5;
			float w = exp(-dot(o, o) * 1.2);
			sum += luma(texture(tex, clamp(uv + o * px, vec2(0.0), vec2(1.0)))) * w;
			wsum += w;
		}
	}
	return sum / wsum;
}

float soft_picture(vec2 uv, float radius_px) {
	if (radius_px < 0.5) {
		return luma(texture(picture, uv));
	}
	vec2 px = radius_px / tex_size;
	float sum = 0.0;
	float wsum = 0.0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec2 o = vec2(float(x), float(y)) * 0.5;
			float w = exp(-dot(o, o) * 1.2);
			sum += luma(texture(picture, clamp(uv + o * px, vec2(0.0), vec2(1.0)))) * w;
			wsum += w;
		}
	}
	return sum / wsum;
}

void fragment() {
	vec4 now = texture(TEXTURE, UV);
	float m = 0.0;
	if (map == 0) {
		m = soft_luma(TEXTURE, UV, map_smooth * px_scale);
	} else if (map == 1) {
		m = UV.x;
	} else if (map == 2) {
		m = UV.y;
	} else if (map == 3) {
		float aspect = tex_size.x / max(tex_size.y, 1.0);
		vec2 d = (UV - centre) * vec2(aspect, 1.0);
		vec2 far_c = max(abs(centre), abs(vec2(1.0) - centre)) * vec2(aspect, 1.0);
		m = clamp(length(d) / max(length(far_c), 0.0001), 0.0, 1.0);
	} else {
		m = soft_picture(UV, map_smooth * px_scale);
	}
	if (invert) {
		m = 1.0 - m;
	}
	m = clamp((m - 0.5) * contrast + 0.5, 0.0, 1.0);
	if (steps > 0) {
		m = floor(m * float(steps) + 0.5) / float(steps);
	}
	float age = m * min(max_time * history_fps, float(history_count));
	COLOR = history_between(age, UV, now);
}
