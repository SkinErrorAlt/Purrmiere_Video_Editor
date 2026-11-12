shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"

uniform float echo_time : hint_range(0.01, 1.0) = 0.067;
uniform int echoes : hint_range(1, 16) = 6;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform float decay : hint_range(0.0, 1.0) = 0.7;
uniform int operator = 0;
uniform vec4 tint : source_color = vec4(0.45, 0.7, 1.0, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;

vec4 tinted(vec4 c, float age01) {
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	float lum = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 coloured = tint.rgb * (0.35 + 0.95 * lum);
	rgb = mix(rgb, coloured, tint_amount * (0.35 + 0.65 * age01));
	return vec4(clamp(rgb, 0.0, 1.0) * c.a, c.a);
}

void fragment() {
	vec4 now = texture(TEXTURE, UV);
	float step_frames = max(echo_time * history_fps, 0.0);
	float w0 = intensity;
	vec4 out_c = operator <= 2 ? now * w0 : now;
	float wsum = w0;
	float w = intensity;
	for (int i = 1; i <= 16; i++) {
		if (i > echoes) {
			break;
		}
		w *= decay;
		float age = step_frames * float(i);
		if (age > float(history_count) + 0.001 || history_count == 0) {
			break;
		}
		vec4 h = tinted(history_between(age, UV, now), float(i) / float(max(echoes, 1)));
		if (operator == 0) {
			out_c += h * w;
			wsum += w;
		} else if (operator == 1) {
			out_c += h * w;
		} else if (operator == 2) {
			vec4 e = clamp(h * w, 0.0, 1.0);
			out_c = 1.0 - (1.0 - out_c) * (1.0 - e);
		} else if (operator == 3) {
			out_c = max(out_c, h * w);
		} else if (operator == 4) {
			vec4 e = mix(vec4(1.0), h, w);
			out_c = min(out_c, e);
		} else if (operator == 5) {
			vec4 e = h * w;
			out_c = out_c + (1.0 - out_c.a) * e;
		} else {
			vec4 e = h * w;
			out_c = e + (1.0 - e.a) * out_c;
		}
	}
	if (operator == 0) {
		out_c = wsum > 0.0001 ? out_c / wsum : now;
	}
	out_c = clamp(out_c, 0.0, 1.0);
	out_c.rgb = min(out_c.rgb, vec3(out_c.a));
	COLOR = out_c;
}
