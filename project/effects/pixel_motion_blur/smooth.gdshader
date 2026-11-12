shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/pixel_motion_blur/flow.gdshaderinc"

float med9(float v[9]) {
	for (int i = 0; i < 5; i++) {
		int m = i;
		for (int j = i + 1; j < 9; j++) {
			if (v[j] < v[m]) {
				m = j;
			}
		}
		float t = v[i];
		v[i] = v[m];
		v[m] = t;
	}
	return v[4];
}

void fragment() {
	ivec2 p = ivec2(floor(UV * vec2(textureSize(TEXTURE, 0))));
	float xs[9];
	float ys[9];
	int k = 0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 f = flow_fetch(TEXTURE, p + ivec2(i, j));
			xs[k] = f.x;
			ys[k] = f.y;
			k++;
		}
	}
	COLOR = flow_encode(vec2(med9(xs), med9(ys)));
}
