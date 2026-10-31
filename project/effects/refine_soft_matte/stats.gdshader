shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D source_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform int guide_from : hint_range(0, 2) = 0;
uniform float size : hint_range(1.0, 30.0) = 8.0;
uniform float detail : hint_range(0.0, 1.0) = 0.8;

const float LO = -8.0;
const float SPAN = 17.0;

vec2 pack16(float v) {
	float x = clamp(v, 0.0, 1.0) * 255.0;
	float hi = floor(x);
	return vec2(hi / 255.0, x - hi);
}

float guide_of(vec3 rgb) {
	if (guide_from == 0) {
		return 0.5 + 0.5 * (rgb.g - max(rgb.r, rgb.b));
	}
	if (guide_from == 1) {
		return 0.5 + 0.5 * (rgb.b - max(rgb.r, rgb.g));
	}
	return dot(rgb, vec3(0.2126, 0.7152, 0.0722));
}

float guide(vec2 uv) {
	vec4 c = texture(source_tex, uv);
	vec3 rgb = c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
	return guide_of(rgb);
}

void fragment() {
	vec2 size_px = max(tex_size, vec2(1.0));
	float stride = max(size * max(px_scale, 0.0001) / 4.0, 1.0);
	float s_i = 0.0;
	float s_p = 0.0;
	float s_ip = 0.0;
	float s_ii = 0.0;
	for (int y = -4; y <= 4; y++) {
		for (int x = -4; x <= 4; x++) {
			vec2 uv = clamp(UV + vec2(float(x), float(y)) * stride / size_px, vec2(0.0), vec2(1.0));
			float i = guide(uv);
			float p = texture(TEXTURE, uv).a;
			s_i += i;
			s_p += p;
			s_ip += i * p;
			s_ii += i * i;
		}
	}
	float n = 81.0;
	float m_i = s_i / n;
	float m_p = s_p / n;
	float cov = s_ip / n - m_i * m_p;
	float var_i = max(s_ii / n - m_i * m_i, 0.0);
	float eps = pow(10.0, -1.0 - 3.0 * clamp(detail, 0.0, 1.0));
	float a = clamp(cov / (var_i + eps), -8.0, 8.0);
	float b = clamp(m_p - a * m_i, -8.0, 9.0);
	COLOR = vec4(pack16((a - LO) / SPAN), pack16((b - LO) / SPAN));
}
