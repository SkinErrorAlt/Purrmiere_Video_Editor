shader_type canvas_item;
render_mode blend_disabled;

uniform float hue_centre : hint_range(0.0, 360.0) = 210.0;
uniform float hue_width : hint_range(0.0, 180.0) = 30.0;
uniform float sat_low : hint_range(0.0, 1.0) = 0.15;
uniform float sat_high : hint_range(0.0, 1.0) = 1.0;
uniform float light_low : hint_range(0.0, 1.0) = 0.1;
uniform float light_high : hint_range(0.0, 1.0) = 0.95;
uniform float softness : hint_range(0.0, 1.0) = 0.25;
uniform bool invert = false;
uniform bool show_mask = false;
uniform float hue_shift : hint_range(-180.0, 180.0) = 0.0;
uniform float saturation : hint_range(0.0, 3.0) = 1.3;
uniform float lightness : hint_range(-1.0, 1.0) = -0.05;
uniform float contrast : hint_range(0.0, 2.0) = 1.0;
uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.6, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

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

float band(float x, float lo, float hi, float soft) {
	float s = max(soft, 0.001);
	return smoothstep(lo - s, lo, x) * (1.0 - smoothstep(hi, hi + s, x));
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	rgb = clamp(rgb, 0.0, 1.0);
	vec3 hsl = rgb_to_hsl(rgb);
	float hue_deg = hsl.x * 360.0;
	float dh = abs(mod(hue_deg - hue_centre + 180.0, 360.0) - 180.0);
	float hue_soft = max(softness * 60.0, 0.5);
	float w_hue = 1.0 - smoothstep(hue_width, hue_width + hue_soft, dh);
	float range_soft = softness * 0.2;
	float w_sat = band(hsl.y, sat_low, sat_high, range_soft);
	float w_light = band(hsl.z, light_low, light_high, range_soft);
	float m = clamp(w_hue * w_sat * w_light, 0.0, 1.0);
	if (invert) {
		m = 1.0 - m;
	}
	if (show_mask) {
		COLOR = vec4(vec3(m) * a, a);
	} else {
		vec3 moved = vec3(fract(hsl.x + hue_shift / 360.0), clamp(hsl.y * saturation, 0.0, 1.0), hsl.z);
		moved.z = clamp((moved.z - 0.5) * contrast + 0.5 + lightness * 0.5, 0.0, 1.0);
		vec3 graded = hsl_to_rgb(moved);
		vec3 tint_n = tint.rgb / max(dot(tint.rgb, LUMA), 0.05);
		vec3 tinted = clamp(vec3(dot(graded, LUMA)) * tint_n, 0.0, 1.0);
		graded = mix(graded, tinted, tint_amount);
		rgb = mix(rgb, graded, m);
		COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
	}
}
