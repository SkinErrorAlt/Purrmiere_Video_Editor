shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D source_tex : filter_linear, repeat_disable;
uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform int guide_from : hint_range(0, 2) = 0;
uniform float size : hint_range(1.0, 30.0) = 8.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform bool show_matte = false;

const float LO = -8.0;
const float SPAN = 17.0;
const vec2 RING[8] = vec2[8](vec2(1.0, 0.0), vec2(0.7071, 0.7071), vec2(0.0, 1.0), vec2(-0.7071, 0.7071), vec2(-1.0, 0.0), vec2(-0.7071, -0.7071), vec2(0.0, -1.0), vec2(0.7071, -0.7071));

float unpack16(vec2 p) {
	return (p.x + p.y / 255.0) * SPAN + LO;
}

vec3 straight(vec4 c) {
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
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

void fragment() {
	vec2 size_px = max(tex_size, vec2(1.0));
	float stride = max(size * max(px_scale, 0.0001) / 4.0, 1.0);
	float s_a = 0.0;
	float s_b = 0.0;
	for (int y = -4; y <= 4; y++) {
		for (int x = -4; x <= 4; x++) {
			vec4 t = texture(TEXTURE, clamp(UV + vec2(float(x), float(y)) * stride / size_px, vec2(0.0), vec2(1.0)));
			s_a += unpack16(t.rg);
			s_b += unpack16(t.ba);
		}
	}
	vec4 src = texture(source_tex, UV);
	vec3 src_rgb = straight(src);
	float i = guide_of(src_rgb);
	float q = clamp((s_a / 81.0 * i + s_b / 81.0 - 0.03) / 0.94, 0.0, 1.0);
	vec4 orig = texture(effect_tex, UV);
	float oa = clamp(mix(orig.a, q, strength), 0.0, 1.0);
	vec3 rgb = straight(orig);
	if (orig.a < 0.5) {
		vec3 sum = vec3(0.0);
		float w = 0.0;
		for (int k = 0; k < 8; k++) {
			vec4 n1 = texture(effect_tex, clamp(UV + RING[k] * 2.0 * max(px_scale, 0.0001) / size_px, vec2(0.0), vec2(1.0)));
			vec4 n2 = texture(effect_tex, clamp(UV + RING[k] * 4.0 * max(px_scale, 0.0001) / size_px, vec2(0.0), vec2(1.0)));
			sum += n1.rgb + n2.rgb;
			w += n1.a + n2.a;
		}
		vec3 near = w > 0.0001 ? clamp(sum / w, 0.0, 1.0) : src_rgb;
		if (guide_from == 0) {
			near.g = min(near.g, (near.r + near.b) * 0.5);
		} else if (guide_from == 1) {
			near.b = min(near.b, (near.r + near.g) * 0.5);
		}
		rgb = mix(near, rgb, clamp(orig.a * 2.0, 0.0, 1.0));
	}
	if (show_matte) {
		COLOR = vec4(vec3(oa), 1.0);
	} else {
		COLOR = vec4(rgb * oa, oa);
	}
}
