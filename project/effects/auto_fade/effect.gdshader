shader_type canvas_item;
render_mode blend_disabled;

uniform float fade_in : hint_range(0.0, 10.0) = 0.5;
uniform float fade_out : hint_range(0.0, 10.0) = 0.5;
uniform int to : hint_range(0, 1) = 0;
uniform vec4 colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform int curve : hint_range(0, 2) = 1;
uniform float clip_time;
uniform float clip_duration;

float shape(float x) {
	x = clamp(x, 0.0, 1.0);
	if (curve == 1) { return x * x * (3.0 - 2.0 * x); }
	if (curve == 2) { return x * x * x * (x * (x * 6.0 - 15.0) + 10.0); }
	return x;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float vin = fade_in > 0.0 ? shape(clip_time / fade_in) : 1.0;
	float vout = fade_out > 0.0 && clip_duration > 0.0 ? shape((clip_duration - clip_time) / fade_out) : 1.0;
	float v = min(vin, vout);
	if (to == 1) {
		vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
		vec3 o = mix(colour.rgb, rgb, v);
		COLOR = vec4(o * c.a, c.a);
	} else {
		COLOR = c * v;
	}
}
