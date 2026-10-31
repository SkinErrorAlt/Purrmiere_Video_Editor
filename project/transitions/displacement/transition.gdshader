shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float strength : hint_range(0.0, 1.0) = 0.5;
uniform int source = 0;
uniform int axes = 0;
uniform int source_y = 2;
uniform float strength_y : hint_range(0.0, 1.0) = 0.5;
uniform float scale : hint_range(0.5, 20.0) = 3.0;
uniform int detail : hint_range(1, 5) = 3;
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform float softness : hint_range(0.0, 40.0) = 4.0;
uniform int curve = 0;

float noise_field(vec2 q, float salt) {
	float v = 0.0;
	float amp = 0.5;
	float total = 0.0;
	q += vec2(salt * 13.7, salt * 5.3);
	for (int i = 0; i < 5; i++) {
		if (i >= detail) {
			break;
		}
		v += amp * tr_noise(q);
		total += amp;
		q = q * 2.03 + vec2(17.1, 9.7);
		amp *= 0.5;
	}
	return v / max(total, 0.0001);
}

float luma(vec4 c) {
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	return dot(rgb, vec3(0.2126, 0.7152, 0.0722)) * c.a;
}

float picture_field(vec2 uv, bool use_from) {
	vec2 r = softness * px_scale / frame_px;
	float s = 0.0;
	s += luma(use_from ? from_mirrored(uv) : to_mirrored(uv)) * 0.4;
	s += luma(use_from ? from_mirrored(uv + vec2(r.x, 0.0)) : to_mirrored(uv + vec2(r.x, 0.0))) * 0.15;
	s += luma(use_from ? from_mirrored(uv - vec2(r.x, 0.0)) : to_mirrored(uv - vec2(r.x, 0.0))) * 0.15;
	s += luma(use_from ? from_mirrored(uv + vec2(0.0, r.y)) : to_mirrored(uv + vec2(0.0, r.y))) * 0.15;
	s += luma(use_from ? from_mirrored(uv - vec2(0.0, r.y)) : to_mirrored(uv - vec2(0.0, r.y))) * 0.15;
	return s;
}

float map_value(int kind, vec2 uv, float salt) {
	if (kind == 1) {
		return picture_field(uv, true);
	} else if (kind == 2) {
		return picture_field(uv, false);
	}
	return noise_field(tr_world(uv) * scale, salt);
}

vec4 transition(vec2 uv) {
	float p = curve == 1 ? tr_ease(progress, 3) : progress;
	vec2 d;
	if (axes == 1) {
		float mx = (map_value(source, uv, 0.0) - 0.5) * 2.0;
		float my = (map_value(source_y, uv, 1.0) - 0.5) * 2.0;
		d = vec2(mx * strength / tr_ratio(), -my * strength_y);
	} else {
		float n = (map_value(source, uv, 0.0) - 0.5) * 2.0;
		float a = radians(angle);
		d = n * strength * vec2(cos(a) / tr_ratio(), -sin(a));
	}
	float env = pow(sin(TR_PI * clamp(progress, 0.0, 1.0)), 5.0) * 0.5;
	vec4 a_col = from_mirrored(uv + env * d);
	vec4 b_col = to_mirrored(uv - env * d);
	return mix(a_col, b_col, smoothstep(0.15, 0.85, p));
}

void fragment() {
	COLOR = transition(UV);
}
