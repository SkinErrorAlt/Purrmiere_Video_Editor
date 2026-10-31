shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float amount : hint_range(0.0, 1.0) = 0.7;
uniform float detail : hint_range(0.0, 1.0) = 0.3;
uniform float skin_hue : hint_range(0.0, 360.0) = 22.0;
uniform float skin_width : hint_range(5.0, 120.0) = 40.0;
uniform bool show_mask = false;

vec3 rgb_to_hsv(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float d = mx - mn;
	float h = 0.0;
	if (d > 0.00001) {
		if (mx == c.r) {
			h = mod((c.g - c.b) / d, 6.0);
		} else if (mx == c.g) {
			h = (c.b - c.r) / d + 2.0;
		} else {
			h = (c.r - c.g) / d + 4.0;
		}
	}
	float s = mx > 0.00001 ? d / mx : 0.0;
	return vec3(h * 60.0, s, mx);
}

float skin_mask(vec3 rgb) {
	vec3 hsv = rgb_to_hsv(clamp(rgb, 0.0, 1.0));
	float dh = abs(hsv.x - mod(skin_hue, 360.0));
	dh = min(dh, 360.0 - dh);
	float half_w = max(skin_width * 0.5, 1.0);
	float hue_w = 1.0 - smoothstep(half_w * 0.6, half_w + 8.0, dh);
	float sat_w = smoothstep(0.06, 0.16, hsv.y) * (1.0 - smoothstep(0.7, 0.9, hsv.y));
	float val_w = smoothstep(0.12, 0.28, hsv.z);
	return hue_w * sat_w * val_w;
}

void fragment() {
	vec4 o = texture(effect_tex, UV);
	float a = o.a;
	vec3 rgb = a > 0.0001 ? o.rgb / a : vec3(0.0);
	vec4 sm = texture(TEXTURE, UV);
	vec3 srgb = sm.a > 0.0001 ? sm.rgb / sm.a : rgb;
	float m = skin_mask(srgb);
	vec3 smooth_rgb = srgb + (rgb - srgb) * clamp(detail, 0.0, 1.0);
	vec3 outc = mix(rgb, smooth_rgb, m * clamp(amount, 0.0, 1.0));
	if (show_mask) {
		outc = vec3(m);
	}
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
