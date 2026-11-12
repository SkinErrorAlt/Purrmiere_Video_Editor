shader_type canvas_item;
render_mode blend_disabled;

uniform int direction = 0;

const int STRIPS = 16;
const float BAND_SPAN = 4.0;

float join16(float h, float l) {
	return (floor(h * 255.0 + 0.5) * 256.0 + floor(l * 255.0 + 0.5)) / 65535.0;
}

vec2 split16(float v) {
	float q = clamp(v, 0.0, 1.0) * 65535.0;
	float h = floor(q / 256.0);
	return vec2(h, q - h * 256.0) / 255.0;
}

void fragment() {
	ivec2 ax = direction == 0 ? ivec2(0, 1) : ivec2(1, 0);
	ivec2 across = ivec2(1) - ax;
	vec2 fc = floor(FRAGCOORD.xy);
	int lane = int(dot(fc, vec2(across)));
	if (lane > 0) {
		COLOR = vec4(0.0);
	} else {
		int pos = int(dot(fc, vec2(ax)));
		vec4 full = texelFetch(TEXTURE, ax * pos + across * STRIPS, 0);
		float lum = join16(full.r, full.g);
		float vals[STRIPS];
		int n = 0;
		for (int s = 0; s < STRIPS; s++) {
			vec4 t = texelFetch(TEXTURE, ax * pos + across * s, 0);
			if (t.b > 0.5) {
				vals[n] = join16(t.r, t.g);
				n++;
			}
		}
		if (n > 0) {
			for (int i = 1; i < n; i++) {
				float key = vals[i];
				int j = i - 1;
				while (j >= 0 && vals[j] > key) {
					vals[j + 1] = vals[j];
					j--;
				}
				vals[j + 1] = key;
			}
			lum = (n % 2 == 1) ? vals[n / 2] : 0.5 * (vals[n / 2 - 1] + vals[n / 2]);
		}
		vec2 q = split16(lum);
		COLOR = vec4(q.x, q.y, full.b, full.a);
	}
}
