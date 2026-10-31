shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform vec4 colour : source_color = vec4(1.0);
uniform int mode : hint_range(0, 1) = 0;
uniform float hold : hint_range(0.0, 0.8) = 0.1;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	float a = c.a;
	float k;
	float out_a = a;
	if (mode == 1) {
		float half_len = max((1.0 - hold) * 0.5, 0.0001);
		k = smoothstep(0.0, 1.0, clamp(progress / half_len, 0.0, 1.0));
		float fade = smoothstep(0.0, 1.0, clamp((progress - half_len - hold) / half_len, 0.0, 1.0));
		out_a = mix(a, 1.0, k) * (1.0 - fade);
	} else {
		k = smoothstep(0.0, 1.0, clamp(progress / max(1.0 - hold, 0.0001), 0.0, 1.0));
	}
	vec3 o = mix(rgb, colour.rgb, k * colour.a);
	COLOR = vec4(clamp(o, 0.0, 1.0) * out_a, out_a);
}
