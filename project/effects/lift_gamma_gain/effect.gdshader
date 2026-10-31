shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 lift_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float lift_push : hint_range(0.0, 1.0) = 0.5;
uniform float lift : hint_range(-1.0, 1.0) = 0.0;
uniform vec4 gamma_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float gamma_push : hint_range(0.0, 1.0) = 0.5;
uniform float gamma : hint_range(-1.0, 1.0) = 0.0;
uniform vec4 gain_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float gain_push : hint_range(0.0, 1.0) = 0.5;
uniform float gain : hint_range(-1.0, 1.0) = 0.0;
uniform vec4 offset_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float offset_push : hint_range(0.0, 1.0) = 0.5;
uniform float offset : hint_range(-1.0, 1.0) = 0.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 wheel(vec4 picked, float push) {
	vec3 chroma = picked.rgb - vec3(dot(picked.rgb, LUMA));
	return chroma * push;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec3 lift_v = vec3(lift * 0.5) + wheel(lift_colour, lift_push) * 0.3;
	vec3 gamma_v = exp2(vec3(gamma) + wheel(gamma_colour, gamma_push));
	vec3 gain_v = exp2(vec3(gain) + wheel(gain_colour, gain_push));
	vec3 v = gain_v * (rgb + lift_v * (vec3(1.0) - rgb));
	v = pow(max(v, vec3(0.0)), vec3(1.0) / max(gamma_v, vec3(0.01)));
	v += vec3(offset * 0.5) + wheel(offset_colour, offset_push) * 0.2;
	float l = dot(v, LUMA);
	v = vec3(l) + (v - vec3(l)) * saturation;
	COLOR = vec4(clamp(v, 0.0, 1.0) * a, a);
}
