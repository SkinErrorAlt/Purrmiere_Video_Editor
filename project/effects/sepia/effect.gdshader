shader_type canvas_item;
render_mode blend_disabled;

uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float warmth : hint_range(0.0, 1.0) = 0.5;
uniform float fade : hint_range(0.0, 1.0) = 0.1;
uniform float contrast : hint_range(-1.0, 1.0) = 0.1;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	rgb = clamp(rgb, 0.0, 1.0);
	float l = dot(rgb, LUMA);
	l = clamp((l - 0.5) * (1.0 + contrast) + 0.5, 0.0, 1.0);
	l = mix(fade * 0.3, 1.0 - fade * 0.06, l);
	vec3 tone = mix(vec3(1.05, 0.97, 0.82), vec3(1.16, 0.9, 0.6), warmth);
	tone /= dot(tone, LUMA);
	vec3 toned = vec3(l) * tone;
	toned = mix(toned, vec3(l), smoothstep(0.75, 1.0, l) * 0.5);
	rgb = mix(rgb, toned, amount);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
