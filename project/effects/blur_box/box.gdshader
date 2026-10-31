shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float size : hint_range(0.0, 100.0) = 3.0;
uniform bool edge = true;
uniform vec2 direction = vec2(1.0, 0.0);

vec4 fetch(sampler2D tex, vec2 uv) {
	if (!edge && (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)) {
		return vec4(0.0);
	}
	return texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
}

void fragment() {
	float half_w = size * px_scale;
	if (half_w < 0.25) {
		COLOR = texture(TEXTURE, UV);
	} else {
		int n = int(min(ceil(half_w), 100.0));
		vec2 px = direction / tex_size;
		vec4 sum = texture(TEXTURE, UV);
		float wsum = 1.0;
		for (int i = 1; i <= 100; i++) {
			if (i > n) {
				break;
			}
			float w = min(half_w - float(i) + 1.0, 1.0);
			sum += fetch(TEXTURE, UV + px * float(i)) * w;
			sum += fetch(TEXTURE, UV - px * float(i)) * w;
			wsum += 2.0 * w;
		}
		COLOR = sum / wsum;
	}
}
