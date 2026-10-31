shader_type canvas_item;
render_mode blend_disabled;

uniform int source : hint_range(0, 6) = 0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform bool invert = false;
uniform bool ignore_alpha = false;
uniform float black : hint_range(0.0, 1.0) = 0.0;
uniform float white : hint_range(0.0, 1.0) = 1.0;
uniform float gamma : hint_range(0.1, 10.0) = 1.0;
uniform bool show_alpha = false;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	float base = ignore_alpha ? 1.0 : a;
	float hi = max(rgb.r, max(rgb.g, rgb.b));
	float lo = min(rgb.r, min(rgb.g, rgb.b));
	float v = base;
	if (source == 1) {
		v = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	} else if (source == 2) {
		v = rgb.r;
	} else if (source == 3) {
		v = rgb.g;
	} else if (source == 4) {
		v = rgb.b;
	} else if (source == 5) {
		v = hi;
	} else if (source == 6) {
		v = hi > 0.0001 ? (hi - lo) / hi : 0.0;
	}
	if (invert) {
		v = 1.0 - v;
	}
	float span = white - black;
	float lv = abs(span) > 0.0001 ? clamp((v - black) / span, 0.0, 1.0) : (v >= black ? 1.0 : 0.0);
	lv = pow(lv, 1.0 / max(gamma, 0.01));
	float na = lv * clamp(opacity, 0.0, 1.0);
	if (source != 0) {
		na *= base;
	}
	na = clamp(na, 0.0, 1.0);
	if (show_alpha) {
		COLOR = vec4(vec3(na), 1.0);
	} else {
		COLOR = vec4(rgb * na, na);
	}
}
