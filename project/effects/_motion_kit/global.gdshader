shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/pixel_motion_blur/flow.gdshaderinc"

const int N = 12;

float median_n(float v[144]) {
	for (int i = 0; i < 73; i++) {
		int m = i;
		for (int j = i + 1; j < 144; j++) {
			if (v[j] < v[m]) {
				m = j;
			}
		}
		float t = v[i];
		v[i] = v[m];
		v[m] = t;
	}
	return 0.5 * (v[71] + v[72]);
}

vec3 solve3(mat3 a, vec3 b, vec3 fallback) {
	float d = determinant(a);
	if (abs(d) < 1e-9) {
		return fallback;
	}
	return inverse(a) * b;
}

void fragment() {
	vec2 fsz = vec2(textureSize(TEXTURE, 0));
	float xs[144];
	float ys[144];
	vec2 pos[144];
	vec2 fl[144];
	for (int j = 0; j < N; j++) {
		for (int i = 0; i < N; i++) {
			int k = j * N + i;
			vec2 uv = (vec2(float(i), float(j)) + 0.5) / float(N);
			vec2 f = flow_fetch(TEXTURE, ivec2(floor(uv * fsz)));
			fl[k] = f;
			pos[k] = uv - 0.5;
			xs[k] = f.x;
			ys[k] = f.y;
		}
	}
	vec2 m = vec2(median_n(xs), median_n(ys));
	vec3 ax = vec3(m.x, 0.0, 0.0);
	vec3 ay = vec3(m.y, 0.0, 0.0);
	for (int it = 0; it < 3; it++) {
		float thr = (it == 0 ? 3.0 : 1.5) + 0.12 * length(m);
		mat3 a = mat3(0.0);
		vec3 bx = vec3(0.0);
		vec3 by = vec3(0.0);
		float n = 0.0;
		for (int k = 0; k < 144; k++) {
			vec3 b3 = vec3(1.0, pos[k].x, pos[k].y);
			vec2 pred = vec2(dot(ax, b3), dot(ay, b3));
			if (length(fl[k] - pred) < thr) {
				a += outerProduct(b3, b3);
				bx += b3 * fl[k].x;
				by += b3 * fl[k].y;
				n += 1.0;
			}
		}
		if (n < 24.0) {
			break;
		}
		ax = solve3(a, bx, ax);
		ay = solve3(a, by, ay);
	}
	vec3 here = vec3(1.0, UV.x - 0.5, UV.y - 0.5);
	COLOR = flow_encode(vec2(dot(ax, here), dot(ay, here)));
}
