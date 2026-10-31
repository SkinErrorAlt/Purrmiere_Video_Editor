shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D hue_vs_hue : filter_linear, repeat_disable;
uniform sampler2D hue_vs_sat : filter_linear, repeat_disable;
uniform sampler2D hue_vs_lum : filter_linear, repeat_disable;
uniform sampler2D lum_vs_sat : filter_linear, repeat_disable;
uniform sampler2D sat_vs_sat : filter_linear, repeat_disable;
uniform bool keep_brightness = true;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float lut(sampler2D t, float x) {
	return texture(t, vec2(clamp(x, 0.0, 1.0) * (255.0 / 256.0) + 0.5 / 256.0, 0.5)).r;
}

float centred(sampler2D t, float x) {
	float d = lut(t, x) - 0.5;
	return abs(d) < 0.003 ? 0.0 : d;
}

vec3 rgb_to_hsl(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float l = (mx + mn) * 0.5;
	float d = mx - mn;
	float h = 0.0;
	float s = 0.0;
	if (d > 0.00001) {
		s = d / max(1.0 - abs(2.0 * l - 1.0), 0.00001);
		if (mx == c.r) {
			h = mod((c.g - c.b) / d, 6.0);
		} else if (mx == c.g) {
			h = (c.b - c.r) / d + 2.0;
		} else {
			h = (c.r - c.g) / d + 4.0;
		}
		h /= 6.0;
	}
	return vec3(h, clamp(s, 0.0, 1.0), l);
}

vec3 hsl_to_rgb(vec3 hsl) {
	vec3 k = mod(vec3(0.0, 8.0, 4.0) + hsl.x * 12.0, 12.0);
	float amp = hsl.y * min(hsl.z, 1.0 - hsl.z);
	return vec3(hsl.z) - amp * max(vec3(-1.0), min(min(k - 3.0, 9.0 - k), vec3(1.0)));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	rgb = clamp(rgb, 0.0, 1.0);
	vec3 hsl = rgb_to_hsl(rgb);
	float y0 = dot(rgb, LUMA);
	float h = hsl.x;
	float turn = centred(hue_vs_hue, h);
	float sat_mul = (1.0 + 2.0 * centred(hue_vs_sat, h)) * (1.0 + 2.0 * centred(sat_vs_sat, hsl.y)) * (1.0 + 2.0 * centred(lum_vs_sat, y0));
	float lum_shift = centred(hue_vs_lum, h);
	vec3 moved = hsl_to_rgb(vec3(fract(h + turn), clamp(hsl.y * sat_mul, 0.0, 1.0), hsl.z));
	if (keep_brightness) {
		moved += vec3(y0 - dot(moved, LUMA));
	}
	float chroma = max(rgb.r, max(rgb.g, rgb.b)) - min(rgb.r, min(rgb.g, rgb.b));
	moved += vec3(lum_shift * smoothstep(0.02, 0.25, chroma));
	COLOR = vec4(clamp(moved, 0.0, 1.0) * a, a);
}
