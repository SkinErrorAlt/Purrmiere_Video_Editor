shader_type canvas_item;
render_mode blend_disabled;

uniform float amount : hint_range(0.0, 1.0) = 0.5;
uniform float balance : hint_range(-1.0, 1.0) = 0.0;
uniform vec4 shadow_colour : source_color = vec4(0.0, 0.55, 0.6, 1.0);
uniform vec4 highlight_colour : source_color = vec4(1.0, 0.62, 0.3, 1.0);
uniform float protect_skin : hint_range(0.0, 1.0) = 0.6;
uniform float contrast : hint_range(0.0, 1.0) = 0.2;

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

vec3 unit_tint(vec3 col) {
	return clamp(col, 0.0, 1.0) / max(dot(clamp(col, 0.0, 1.0), LUMA), 0.05);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	rgb = clamp(rgb, 0.0, 1.0);
	float l = dot(rgb, LUMA);
	float pivot = 0.5 - balance * 0.3;
	float w_high = smoothstep(pivot - 0.35, pivot + 0.35, l);
	vec3 tint = mix(unit_tint(shadow_colour.rgb), unit_tint(highlight_colour.rgb), w_high);
	vec3 graded = rgb * mix(vec3(1.0), tint, amount * 0.5);
	graded += vec3(l - dot(graded, LUMA));
	float mx = max(rgb.r, max(rgb.g, rgb.b));
	float sat = mx > 0.0001 ? (mx - min(rgb.r, min(rgb.g, rgb.b))) / mx : 0.0;
	float dh = abs(fract(hue_of(rgb) - 0.07 + 0.5) - 0.5);
	float skin = 1.0 - smoothstep(0.04, 0.09, dh);
	skin *= smoothstep(0.08, 0.2, sat) * (1.0 - smoothstep(0.65, 0.85, sat));
	skin *= smoothstep(0.08, 0.2, l);
	graded = mix(graded, rgb, protect_skin * skin);
	float lg = clamp(dot(graded, LUMA), 0.0, 1.0);
	float curved = mix(lg, lg * lg * (3.0 - 2.0 * lg), contrast);
	graded += vec3(curved - lg);
	COLOR = vec4(clamp(graded, 0.0, 1.0) * a, a);
}
