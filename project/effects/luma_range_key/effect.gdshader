shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform int measure : hint_range(0, 2) = 0;
uniform float low : hint_range(0.0, 1.0) = 0.15;
uniform float low_softness : hint_range(0.0, 1.0) = 0.1;
uniform float high : hint_range(0.0, 1.0) = 1.0;
uniform float high_softness : hint_range(0.0, 1.0) = 0.0;
uniform bool key_range = false;
uniform float pre_blur : hint_range(0.0, 10.0) = 0.0;
uniform float matte_gamma : hint_range(0.2, 5.0) = 1.0;
uniform bool show_matte = false;

const vec2 RING[8] = vec2[8](vec2(1.0, 0.0), vec2(0.7071, 0.7071), vec2(0.0, 1.0), vec2(-0.7071, 0.7071), vec2(-1.0, 0.0), vec2(-0.7071, -0.7071), vec2(0.0, -1.0), vec2(0.7071, -0.7071));

vec3 straight(vec4 c) {
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
}

float level_of(vec3 c) {
	if (measure == 1) {
		return max(c.r, max(c.g, c.b));
	}
	if (measure == 2) {
		return (c.r + c.g + c.b) / 3.0;
	}
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

float ramp(float x) {
	float t = clamp(x, 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = straight(c);
	float l = level_of(rgb);
	float reach = pre_blur * max(px_scale, 0.0001);
	if (reach > 0.25) {
		vec2 step_uv = vec2(reach) / max(tex_size, vec2(1.0));
		float sum = l * 2.0;
		for (int i = 0; i < 8; i++) {
			sum += level_of(straight(texture(TEXTURE, clamp(UV + RING[i] * step_uv, vec2(0.0), vec2(1.0)))));
			sum += level_of(straight(texture(TEXTURE, clamp(UV + RING[i] * step_uv * 0.5, vec2(0.0), vec2(1.0)))));
		}
		l = sum / 18.0;
	}
	float below = low_softness > 0.0005 ? ramp((l - (low - low_softness)) / low_softness) : step(low, l);
	float above = high_softness > 0.0005 ? 1.0 - ramp((l - high) / high_softness) : 1.0 - step(high + 0.00001, l);
	float keep = below * above;
	if (key_range) {
		keep = 1.0 - keep;
	}
	float m = pow(clamp(keep, 0.0, 1.0), matte_gamma);
	float a = c.a * m;
	if (show_matte) {
		COLOR = vec4(vec3(a), 1.0);
	} else {
		COLOR = vec4(rgb * a, a);
	}
}
