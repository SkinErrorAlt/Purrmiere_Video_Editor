shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform bool behind = true;
uniform int blend : hint_range(0, 3) = 0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

vec3 blend_rgb(vec3 base, vec3 top, int mode) {
	if (mode == 1) { return base * top; }
	if (mode == 2) { return 1.0 - (1.0 - base) * (1.0 - top); }
	if (mode == 3) {
		return mix(2.0 * base * top, 1.0 - 2.0 * (1.0 - base) * (1.0 - top), step(0.5, base));
	}
	return top;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float sa = colour.a * opacity;
	if (behind) {
		vec3 mixed = blend_rgb(colour.rgb, rgb, blend);
		vec3 o = mix(colour.rgb, mixed, a);
		float oa = max(a, sa);
		if (oa < 0.0001) {
			COLOR = vec4(0.0);
		} else {
			COLOR = vec4(clamp(o, 0.0, 1.0) * oa, oa);
		}
	} else {
		vec3 o = mix(rgb, blend_rgb(rgb, colour.rgb, blend), sa);
		COLOR = vec4(clamp(o, 0.0, 1.0) * a, a);
	}
}
