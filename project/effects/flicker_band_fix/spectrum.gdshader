shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float band_size : hint_range(16.0, 270.0) = 160.0;
uniform int direction = 0;

const int STRIPS = 16;
const float BAND_SPAN = 4.0;
const float TWO_PI = 6.28318530718;

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
	vec2 out_size = max(floor(1.0 / max(fwidth(UV), vec2(0.000001)) + 0.5), vec2(1.0));
	vec2 cell = floor(UV * out_size);
	int flat_i = int(cell.x * out_size.y + cell.y);
	int k = flat_i / STRIPS;
	int s = flat_i - k * STRIPS;
	float cands = floor(out_size.x * out_size.y / float(STRIPS));
	float count = dot(tex_size, vec2(ax));
	float tmin = max(8.0 * px_scale, 3.0);
	float tmax = clamp(band_size * px_scale, tmin + 1.0, count * 0.25);
	if (float(k) >= cands) {
		COLOR = vec4(0.5, 0.0, 0.5, 0.0);
	} else {
		float per = mix(tmin, tmax, float(k) / max(cands - 1.0, 1.0));
		float xr = 0.0;
		float xi = 0.0;
		int n = int(count);
		float step_a = TWO_PI / per;
		float step_h = TWO_PI / count;
		for (int y = 0; y < n; y++) {
			float hann = 0.5 - 0.5 * cos(step_h * (float(y) + 0.5));
			float ph = step_a * float(y);
			vec4 t = texelFetch(TEXTURE, ax * y + across * s, 0);
			float v = (join16(t.r, t.g) - 0.5) * BAND_SPAN * t.b * hann;
			xr += v * cos(ph);
			xi += v * sin(ph);
		}
		float norm = 1.0 / max(count * 0.5, 1.0);
		vec2 r16 = split16(xr * norm * 0.5 + 0.5);
		vec2 i16 = split16(xi * norm * 0.5 + 0.5);
		COLOR = vec4(r16.x, r16.y, i16.x, i16.y);
	}
}
