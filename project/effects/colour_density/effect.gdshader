shader_type canvas_item;
render_mode blend_disabled;

uniform float density : hint_range(0.0, 1.0) = 0.5;
uniform float saturation : hint_range(0.0, 2.0) = 1.1;
uniform float pale_highlights : hint_range(0.0, 1.0) = 0.2;
uniform float keep_skin : hint_range(0.0, 1.0) = 0.3;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float hue_of(vec3 c) {
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
		h /= 6.0;
	}
	return h;
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float a = src.a;
	vec3 rgb = a > 0.0001 ? clamp(src.rgb / a, 0.0, 1.0) : vec3(0.0);
	float l = dot(rgb, LUMA);
	vec3 c = vec3(l) + (rgb - vec3(l)) * clamp(saturation, 0.0, 2.0);
	c = max(c, vec3(0.0));
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = mx > 0.0001 ? clamp((mx - mn) / mx, 0.0, 1.0) : 0.0;
	float dh = abs(fract(hue_of(rgb) - 0.07 + 0.5) - 0.5);
	float skin = (1.0 - smoothstep(0.04, 0.09, dh)) * smoothstep(0.08, 0.2, sat) * (1.0 - smoothstep(0.65, 0.85, sat));
	float d = clamp(density, 0.0, 1.0) * (1.0 - clamp(keep_skin, 0.0, 1.0) * skin);
	c *= 1.0 - d * pow(sat, 1.2) * 0.45;
	float lc = dot(c, LUMA);
	float pale = clamp(pale_highlights, 0.0, 1.0) * smoothstep(0.55, 1.0, lc);
	c = mix(c, vec3(lc), pale * 0.7);
	COLOR = vec4(clamp(c, 0.0, 1.0) * a, a);
}
