shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float skin_hue : hint_range(0.0, 360.0) = 22.0;
uniform float skin_width : hint_range(5.0, 120.0) = 40.0;
uniform bool skin_only = true;

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
	float sat_w = smoothstep(0.08, 0.2, hsv.y) * (1.0 - smoothstep(0.75, 0.95, hsv.y));
	float val_w = smoothstep(0.05, 0.16, hsv.z);
	if (!skin_only) {
		float warm = 1.0 - smoothstep(35.0, 70.0, min(dh, 360.0 - dh));
		return warm * sat_w * val_w;
	}
	return hue_w * sat_w * val_w;
}

vec4 weighted(vec4 c) {
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	float m = skin_mask(rgb) * c.a;
	return vec4(rgb * m, m);
}

void fragment() {
	vec2 px = 0.5 / max(tex_size, vec2(1.0));
	vec4 s = weighted(texture(TEXTURE, UV + vec2(-px.x, -px.y)));
	s += weighted(texture(TEXTURE, UV + vec2(px.x, -px.y)));
	s += weighted(texture(TEXTURE, UV + vec2(-px.x, px.y)));
	s += weighted(texture(TEXTURE, UV + vec2(px.x, px.y)));
	COLOR = s * 0.25;
}
