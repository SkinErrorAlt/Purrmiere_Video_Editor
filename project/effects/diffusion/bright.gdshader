shader_type canvas_item;
render_mode blend_disabled;

uniform float threshold : hint_range(0.0, 1.0) = 0.55;
uniform float black_mist : hint_range(0.0, 1.0) = 0.0;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float l = dot(rgb, LUMA);
	float w = smoothstep(threshold - 0.2, threshold + 0.2, l);
	w = mix(w, 1.0, clamp(black_mist, 0.0, 1.0));
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * w * a, w * a);
}
