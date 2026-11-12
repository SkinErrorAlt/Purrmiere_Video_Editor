shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"

uniform float trail_length : hint_range(0.03, 2.0) = 0.5;
uniform int samples : hint_range(2, 32) = 20;
uniform int mode = 0;
uniform float strength : hint_range(0.0, 2.0) = 1.0;
uniform float fade : hint_range(0.2, 4.0) = 1.4;
uniform float threshold : hint_range(0.0, 0.5) = 0.06;
uniform float softness : hint_range(0.005, 0.5) = 0.12;
uniform vec4 colour : source_color = vec4(1.0, 0.55, 0.2, 1.0);
uniform float colour_amount : hint_range(0.0, 1.0) = 0.0;

vec3 straight(vec4 c) {
	return c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
}

void fragment() {
	vec4 now = texture(TEXTURE, UV);
	vec3 now_rgb = straight(now);
	float reach = min(trail_length * history_fps, float(history_count));
	int n = clamp(samples, 2, 32);
	vec4 lit = vec4(0.0);
	vec4 sum = vec4(0.0);
	float wsum = 0.0;
	vec4 behind = vec4(0.0);
	for (int i = 1; i <= 32; i++) {
		if (i > n || reach <= 0.0) {
			break;
		}
		float f = float(i) / float(n);
		float age = max(f * reach, 1.0);
		vec4 h = history_between(age, UV, now);
		vec3 h_rgb = straight(h);
		float diff = max(max(abs(h_rgb.r - now_rgb.r), abs(h_rgb.g - now_rgb.g)), abs(h_rgb.b - now_rgb.b));
		diff = max(diff * min(h.a, now.a), abs(h.a - now.a));
		float moved = smoothstep(threshold, threshold + softness, diff);
		float w = pow(1.0 - (float(i) - 0.5) / float(n), fade) * strength;
		vec3 tint = mix(vec3(1.0), colour.rgb * 1.6, colour_amount * (0.3 + 0.7 * f));
		vec4 t = vec4(clamp(h_rgb * tint, 0.0, 1.0) * h.a, h.a);
		lit = max(lit, t * w * moved);
		sum += t * w * moved;
		wsum += w * moved;
		vec4 b = t * clamp(w, 0.0, 1.0);
		behind = behind + (1.0 - behind.a) * b * (1.0 - f * 0.15);
	}
	vec4 out_c = now;
	if (mode == 0) {
		out_c = max(now, clamp(lit, 0.0, 1.0));
	} else if (mode == 1) {
		vec4 avg = wsum > 0.0001 ? sum / wsum : now;
		float cover = clamp(wsum / float(n) * 2.0, 0.0, 1.0);
		out_c = mix(now, mix(now, avg, 0.65), cover);
	} else if (mode == 2) {
		vec4 glow = clamp(sum / float(n) * 2.5, 0.0, 1.0);
		out_c = 1.0 - (1.0 - now) * (1.0 - glow);
	} else {
		out_c = now + (1.0 - now.a) * clamp(behind, 0.0, 1.0);
	}
	out_c = clamp(out_c, 0.0, 1.0);
	out_c.rgb = min(out_c.rgb, vec3(out_c.a));
	COLOR = out_c;
}
