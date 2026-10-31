shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float tile : hint_range(4.0, 400.0) = 40.0;
uniform float blur : hint_range(0.0, 100.0) = 24.0;
uniform float lines : hint_range(0.0, 1.0) = 0.15;
uniform vec2 direction = vec2(1.0, 0.0);

void fragment() {
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float size = max(tile * ps, 1.0);
	bool across = abs(direction.x) > 0.5;
	float pos = across ? UV.x * sz.x : UV.y * sz.y;
	float lo = floor(pos / size) * size;
	float hi = lo + size;
	vec4 centre = texture(TEXTURE, UV);
	float sigma = blur * ps / 3.0;
	vec4 outc = centre;
	if (sigma >= 0.15) {
		int n = int(min(ceil(3.0 * sigma), 96.0));
		vec4 sum = centre;
		float wsum = 1.0;
		for (int k = 1; k <= 96; k++) {
			if (k > n) {
				break;
			}
			float w = exp(-0.5 * float(k * k) / (sigma * sigma));
			float fwd = pos + float(k);
			float back = pos - float(k);
			if (fwd < hi) {
				sum += texture(TEXTURE, UV + direction * float(k) / sz) * w;
				wsum += w;
			}
			if (back >= lo) {
				sum += texture(TEXTURE, UV - direction * float(k) / sz) * w;
				wsum += w;
			}
		}
		outc = sum / wsum;
	}
	if (!across && lines > 0.0) {
		vec2 p = UV * sz;
		vec2 cell = p - floor(p / size) * size;
		vec2 edge = min(cell, size - cell);
		float d = min(edge.x, edge.y);
		float seam = (1.0 - smoothstep(0.0, max(ps, 0.6), d)) * clamp(lines, 0.0, 1.0);
		outc.rgb *= 1.0 - seam;
	}
	COLOR = outc;
}
