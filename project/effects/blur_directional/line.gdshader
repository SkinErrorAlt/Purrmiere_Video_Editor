shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform float length : hint_range(0.0, 200.0) = 8.0;
uniform int kernel = 0;
uniform bool edge = true;
uniform int stage = 0;

float weight_at(float u) {
	if (kernel == 1) {
		return 1.0;
	}
	if (kernel == 2) {
		return max(1.0 - abs(u), 0.0);
	}
	return exp(-3.2 * u * u);
}

vec4 fetch(sampler2D tex, vec2 uv) {
	if (!edge && (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)) {
		return vec4(0.0);
	}
	return texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
}

void fragment() {
	float len = length * px_scale;
	if (len < 0.5) {
		COLOR = texture(TEXTURE, UV);
	} else {
		float a = radians(angle);
		vec2 dir = vec2(cos(a), sin(a)) / tex_size;
		float k = max(ceil(len / 48.0), 1.0);
		float s1 = len / k;
		vec4 sum = vec4(0.0);
		float wsum = 0.0;
		if (stage == 0) {
			int n = int(clamp(2.0 * s1, 8.0, 96.0));
			for (int i = 0; i < 96; i++) {
				if (i >= n) {
					break;
				}
				float u = ((float(i) + 0.5) / float(n)) * 2.0 - 1.0;
				float w = weight_at(u);
				sum += fetch(TEXTURE, UV + dir * u * s1) * w;
				wsum += w;
			}
		} else {
			int kk = int(k);
			for (int i = 0; i < 8; i++) {
				if (i >= kk) {
					break;
				}
				float off = (float(i) - (k - 1.0) * 0.5) * 2.0 * s1;
				float w = weight_at(off / max(len, 0.001));
				sum += fetch(TEXTURE, UV + dir * off) * w;
				wsum += w;
			}
		}
		COLOR = sum / max(wsum, 0.0001);
	}
}
