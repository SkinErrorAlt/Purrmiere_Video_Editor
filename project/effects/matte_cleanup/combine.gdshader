shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D source_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float holes : hint_range(0.0, 20.0) = 3.0;
uniform bool show_matte = false;

vec3 straight(vec4 c) {
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
}

void fragment() {
	float m = clamp(texture(TEXTURE, UV).r, 0.0, 1.0);
	vec4 orig = texture(effect_tex, UV);
	vec3 rgb = straight(orig);
	if (orig.a < 0.5 && m > orig.a) {
		vec2 size = max(tex_size, vec2(1.0));
		float r = (holes + 1.0) * max(px_scale, 0.0001);
		vec3 sum = vec3(0.0);
		float w = 0.0;
		for (int i = 0; i < 12; i++) {
			float ang = float(i) / 12.0 * 6.28318530718;
			vec2 dir = vec2(cos(ang), sin(ang)) / size;
			vec4 far_c = texture(effect_tex, clamp(UV + dir * r, vec2(0.0), vec2(1.0)));
			vec4 near_c = texture(effect_tex, clamp(UV + dir * r * 0.5, vec2(0.0), vec2(1.0)));
			sum += far_c.rgb + near_c.rgb;
			w += far_c.a + near_c.a;
		}
		vec3 fill = w > 0.0001 ? clamp(sum / w, 0.0, 1.0) : straight(texture(source_tex, UV));
		rgb = mix(fill, rgb, clamp(orig.a * 2.0, 0.0, 1.0));
	}
	if (show_matte) {
		COLOR = vec4(vec3(m), 1.0);
	} else {
		COLOR = vec4(rgb * m, m);
	}
}
