shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform int output_mode : hint_range(0, 2) = 0;
uniform float amount : hint_range(0.0, 4.0) = 1.0;
uniform bool monochrome = false;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 overlay_blend(vec3 base, vec3 top) {
	vec3 lo = 2.0 * base * top;
	vec3 hi = 1.0 - 2.0 * (1.0 - base) * (1.0 - top);
	return mix(lo, hi, step(vec3(0.5), base));
}

vec3 soft_light_blend(vec3 base, vec3 top) {
	vec3 b = clamp(base, 0.0, 1.0);
	vec3 d = mix(sqrt(b), ((16.0 * b - 12.0) * b + 4.0) * b, step(b, vec3(0.25)));
	vec3 lo = b - (1.0 - 2.0 * top) * b * (1.0 - b);
	vec3 hi = b + (2.0 * top - 1.0) * (d - b);
	return mix(lo, hi, step(vec3(0.5), top));
}

void fragment() {
	vec4 o = texture(effect_tex, UV);
	vec4 bl = texture(TEXTURE, UV);
	float a = o.a;
	vec3 orgb = a > 0.0001 ? o.rgb / a : vec3(0.0);
	vec3 brgb = bl.a > 0.0001 ? bl.rgb / bl.a : vec3(0.0);
	vec3 detail = orgb - brgb;
	if (monochrome) {
		detail = vec3(dot(detail, LUMA));
	}
	vec3 grey = clamp(vec3(0.5) + detail * amount, 0.0, 1.0);
	vec3 rgb = grey;
	if (output_mode == 1) {
		rgb = overlay_blend(orgb, grey);
	} else if (output_mode == 2) {
		rgb = soft_light_blend(orgb, grey);
	}
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
