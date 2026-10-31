shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float radius = 16.0;
uniform vec2 direction = vec2(1.0, 0.0);

vec2 encode(float v) {
	float x = clamp(v, 0.0, 0.99999) * 255.0;
	return vec2(floor(x) / 255.0, fract(x));
}

vec2 decode(vec4 e) {
	return vec2(e.r * 255.0 + e.g, e.b * 255.0 + e.a) / 255.0;
}

void fragment() {
	vec2 centre = decode(texture(TEXTURE, UV));
	float sigma = max(radius, 0.0) * px_scale * 0.5;
	if (sigma < 0.2) {
		COLOR = vec4(encode(centre.x), encode(centre.y));
	} else {
		int n = int(min(ceil(2.6 * sigma), 120.0));
		vec2 px = direction / tex_size;
		float inv = 0.5 / (sigma * sigma);
		vec2 sum = centre;
		float wsum = 1.0;
		for (int k = 1; k <= 119; k += 2) {
			if (k > n) {
				break;
			}
			float w1 = exp(-float(k * k) * inv);
			float w2 = k + 1 <= n ? exp(-float((k + 1) * (k + 1)) * inv) : 0.0;
			float wp = w1 + w2;
			float off = (float(k) * w1 + float(k + 1) * w2) / wp;
			sum += decode(texture(TEXTURE, UV + px * off)) * wp;
			sum += decode(texture(TEXTURE, UV - px * off)) * wp;
			wsum += 2.0 * wp;
		}
		vec2 m = sum / wsum;
		COLOR = vec4(encode(m.x), encode(m.y));
	}
}
