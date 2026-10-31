shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float high : hint_range(0.0, 100.0) = 40.0;
uniform float mid : hint_range(0.0, 100.0) = 50.0;
uniform float low : hint_range(0.0, 100.0) = 35.0;
uniform float protect_shadows : hint_range(0.0, 100.0) = 50.0;
uniform float protect_highlights : hint_range(0.0, 100.0) = 50.0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec2 decode(vec4 e) {
	return vec2(e.r * 255.0 + e.g, e.b * 255.0 + e.a) / 255.0;
}

vec2 cubic_decoded(sampler2D tex, vec2 uv) {
	vec2 size = vec2(textureSize(tex, 0));
	vec2 p = uv * size - 0.5;
	vec2 f = fract(p);
	vec2 i = floor(p);
	vec2 f2 = f * f;
	vec2 f3 = f2 * f;
	vec2 w0 = (1.0 - 3.0 * f + 3.0 * f2 - f3) / 6.0;
	vec2 w1 = (4.0 - 6.0 * f2 + 3.0 * f3) / 6.0;
	vec2 w2 = (1.0 + 3.0 * f + 3.0 * f2 - 3.0 * f3) / 6.0;
	vec2 w3 = f3 / 6.0;
	vec2 g0 = w0 + w1;
	vec2 g1 = w2 + w3;
	vec2 h0 = (i - 0.5 + w1 / g0) / size;
	vec2 h1 = (i + 1.5 + w3 / g1) / size;
	vec2 a = decode(texture(tex, vec2(h0.x, h0.y)));
	vec2 b = decode(texture(tex, vec2(h1.x, h0.y)));
	vec2 c = decode(texture(tex, vec2(h0.x, h1.y)));
	vec2 d = decode(texture(tex, vec2(h1.x, h1.y)));
	return g0.y * (g0.x * a + g1.x * b) + g1.y * (g0.x * c + g1.x * d);
}

float soft_limit(float delta, float i) {
	if (delta < 0.0) {
		float ps = clamp(protect_shadows, 0.0, 100.0) / 100.0;
		float room = i * (1.0 - 0.85 * ps * (1.0 - smoothstep(0.04, 0.4, i)));
		if (room < 0.00001) {
			return 0.0;
		}
		return -room * (1.0 - exp(delta / room));
	}
	float ph = clamp(protect_highlights, 0.0, 100.0) / 100.0;
	float room_up = (1.0 - i) * (1.0 - 0.85 * ph * smoothstep(0.6, 0.96, i));
	if (room_up < 0.00001) {
		return 0.0;
	}
	return room_up * (1.0 - exp(-delta / room_up));
}

vec3 apply_luma(vec3 rgb, float i, float delta) {
	if (delta > 0.0) {
		return rgb + delta * (1.0 - rgb) / max(1.0 - i, 0.00001);
	}
	return rgb + delta * rgb / max(i, 0.00001);
}

void fragment() {
	vec4 c = texture(effect_tex, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	float i = dot(rgb, LUMA);
	vec2 ab = cubic_decoded(TEXTURE, UV);
	float base = clamp(ab.x * i + ab.y, 0.0, 1.0);
	float detail = (i - base) * (1.0 - clamp(ab.x, 0.0, 1.0));
	float w_lo = 1.0 - smoothstep(0.12, 0.42, base);
	float w_hi = smoothstep(0.55, 0.85, base);
	float w_mid = max(1.0 - w_lo - w_hi, 0.0);
	float gain = 3.4 * (clamp(high, 0.0, 100.0) * w_hi + clamp(mid, 0.0, 100.0) * w_mid + clamp(low, 0.0, 100.0) * w_lo) / 100.0;
	float delta = soft_limit(gain * detail, i);
	vec3 outc = apply_luma(rgb, i, delta);
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
