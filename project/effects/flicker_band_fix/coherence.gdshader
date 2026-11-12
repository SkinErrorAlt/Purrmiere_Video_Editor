shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);

const int STRIPS = 16;

float join16(float h, float l) {
	return (floor(h * 255.0 + 0.5) * 256.0 + floor(l * 255.0 + 0.5)) / 65535.0;
}

vec2 split16(float v) {
	float q = clamp(v, 0.0, 1.0) * 65535.0;
	float h = floor(q / 256.0);
	return vec2(h, q - h * 256.0) / 255.0;
}

void fragment() {
	int h = int(tex_size.y);
	vec2 cell = floor(UV * tex_size);
	int flat_i = int(cell.x) * h + int(cell.y);
	int cands = int(tex_size.x) * h / STRIPS;
	int k = flat_i;
	if (k >= cands) {
		COLOR = vec4(0.0);
	} else {
		float sr = 0.0;
		float si = 0.0;
		float pw = 0.0;
		for (int s = 0; s < STRIPS; s++) {
			int f = k * STRIPS + s;
			vec4 t = texelFetch(TEXTURE, ivec2(f / h, f % h), 0);
			float xr = join16(t.r, t.g) * 2.0 - 1.0;
			float xi = join16(t.b, t.a) * 2.0 - 1.0;
			sr += xr;
			si += xi;
			pw += xr * xr + xi * xi;
		}
		float coh = (sr * sr + si * si) / max(float(STRIPS) * pw, 0.0000000001);
		float amp = sqrt(sr * sr + si * si) / float(STRIPS);
		float score = clamp((log2(max(coh * amp, 0.000000001)) + 30.0) / 34.0, 0.0, 1.0);
		vec2 s16 = split16(score);
		COLOR = vec4(s16.x, s16.y, coh, 1.0);
	}
}
