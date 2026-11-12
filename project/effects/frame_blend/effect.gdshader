shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"

uniform int frames : hint_range(2, 31) = 6;
uniform int spacing : hint_range(1, 4) = 1;
uniform int weighting = 0;

float weight_of(int i, int n) {
	float f = float(i) / float(max(n - 1, 1));
	if (weighting == 1) {
		return 1.0 - f * 0.85;
	}
	if (weighting == 2) {
		return exp(-f * 3.0);
	}
	return 1.0;
}

void fragment() {
	vec4 now = texture(TEXTURE, UV);
	int n = clamp(frames, 2, 31);
	vec4 sum = now * weight_of(0, n);
	float wsum = weight_of(0, n);
	for (int i = 1; i < 31; i++) {
		if (i >= n) {
			break;
		}
		int age = i * max(spacing, 1);
		if (age > history_count) {
			break;
		}
		float w = weight_of(i, n);
		sum += history_frame(age, UV, now) * w;
		wsum += w;
	}
	COLOR = sum / max(wsum, 0.0001);
}
