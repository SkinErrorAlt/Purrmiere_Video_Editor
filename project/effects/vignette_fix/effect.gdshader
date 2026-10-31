shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float amount : hint_range(0.0, 3.0) = 0.7;
uniform float midpoint : hint_range(0.0, 1.0) = 0.5;
uniform float roundness : hint_range(0.0, 1.0) = 0.4;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float protect : hint_range(0.0, 1.0) = 0.5;
uniform bool show = false;

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 to_srgb(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

vec2 shaped(vec2 d_px, vec2 size) {
	vec2 by_frame = d_px / (size * 0.5);
	vec2 by_circle = d_px / (size.y * 0.5);
	return mix(by_frame, by_circle, clamp(roundness, 0.0, 1.0));
}

void fragment() {
	vec2 size = max(tex_size, vec2(1.0));
	vec2 d = shaped((UV - centre) * size, size);
	vec2 corner = shaped(max(centre, vec2(1.0) - centre) * size, size);
	float rn = clamp(length(d) / max(length(corner), 0.0001), 0.0, 1.5);
	float p = mix(1.5, 6.0, clamp(midpoint, 0.0, 1.0));
	float fall = pow(rn, p);
	float gain = exp2(clamp(amount, 0.0, 3.0) * fall);
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? clamp(c.rgb / a, 0.0, 1.0) : vec3(0.0);
	if (show) {
		float g = (gain - 1.0) / max(exp2(clamp(amount, 0.0, 3.0)) - 1.0, 0.0001);
		COLOR = vec4(vec3(clamp(g, 0.0, 1.0)), 1.0);
	} else {
		vec3 lin = to_linear(rgb);
		float x0 = max(lin.r, max(lin.g, lin.b));
		vec3 up = lin * gain;
		float x1 = x0 * gain;
		float knee = 1.0 - clamp(protect, 0.0, 1.0) * 0.4;
		float y0 = min(max(knee, x0), 0.999);
		float target = x1;
		if (x1 > y0) {
			float room = 1.0 - y0;
			target = protect > 0.0 ? y0 + room * (1.0 - exp(-(x1 - y0) / room)) : min(x1, 1.0);
		}
		vec3 outl = x1 > 0.000001 ? up * (target / x1) : up;
		COLOR = vec4(clamp(to_srgb(outl), 0.0, 1.0) * a, a);
	}
}
