shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform int palette = 0;
uniform int show = 0;
uniform float picture : hint_range(0.0, 1.0) = 0.55;
uniform float opacity : hint_range(0.0, 1.0) = 0.9;
uniform vec4 colour : source_color = vec4(1.0, 0.35, 0.1, 1.0);

vec3 thermal(float h) {
	vec3 c0 = vec3(0.02, 0.0, 0.08);
	vec3 c1 = vec3(0.32, 0.0, 0.55);
	vec3 c2 = vec3(0.85, 0.08, 0.35);
	vec3 c3 = vec3(1.0, 0.45, 0.05);
	vec3 c4 = vec3(1.0, 0.88, 0.25);
	vec3 c5 = vec3(1.0, 1.0, 0.92);
	float x = clamp(h, 0.0, 1.0) * 5.0;
	if (x < 1.0) {
		return mix(c0, c1, x);
	} else if (x < 2.0) {
		return mix(c1, c2, x - 1.0);
	} else if (x < 3.0) {
		return mix(c2, c3, x - 2.0);
	} else if (x < 4.0) {
		return mix(c3, c4, x - 3.0);
	}
	return mix(c4, c5, x - 4.0);
}

vec3 ice(float h) {
	vec3 a = mix(vec3(0.0, 0.02, 0.1), vec3(0.0, 0.35, 0.8), smoothstep(0.0, 0.45, h));
	a = mix(a, vec3(0.3, 0.9, 1.0), smoothstep(0.35, 0.8, h));
	return mix(a, vec3(1.0), smoothstep(0.75, 1.0, h));
}

void fragment() {
	vec4 now = texture(effect_tex, UV);
	vec3 rgb = now.a > 0.0001 ? now.rgb / now.a : vec3(0.0);
	float h = texture(TEXTURE, UV).r;
	vec3 hc = palette == 0 ? thermal(h) : (palette == 1 ? ice(h) : colour.rgb * mix(0.12, 1.0, smoothstep(0.0, 0.6, h)) + vec3(1.0) * smoothstep(0.7, 1.0, h) * 0.6);
	float l = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 base = vec3(l) * picture;
	vec3 out_c;
	if (show == 1) {
		out_c = hc;
	} else {
		float a = smoothstep(0.02, 0.35, h) * opacity;
		vec3 lit = 1.0 - (1.0 - base) * (1.0 - hc);
		out_c = mix(base, lit, a);
	}
	COLOR = vec4(clamp(out_c, 0.0, 1.0) * now.a, now.a);
}
