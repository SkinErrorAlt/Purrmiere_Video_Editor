shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(1920.0, 1080.0);
uniform float smear : hint_range(0.0, 3.0) = 1.1;
uniform float streaks : hint_range(0.0, 1.0) = 0.6;
uniform float lean : hint_range(0.0, 1.0) = 0.35;

vec3 lin(vec3 c) {
	return c * c;
}

void fragment() {
	vec4 src = texture(effect_tex, UV);
	vec4 b = texelFetch(TEXTURE, ivec2(0, 0), 0);
	float on = b.b;
	vec2 v = (b.rg - 0.5) * 0.8;
	if (on < 0.01 || smear <= 0.0) {
		COLOR = src;
	} else {
		float a = max(src.a, 0.0001);
		vec2 q = UV + vec2(v.x, v.y) * lean * on * (UV.y - 0.5) * 0.9;
		vec2 len = v * smear * on;
		vec3 acc = vec3(0.0);
		vec3 hi = vec3(0.0);
		float wsum = 0.0;
		for (int i = 0; i < 24; i++) {
			float f = (float(i) + 0.5) / 24.0 - 0.5;
			vec3 c = lin(texture(effect_tex, q + len * f).rgb / a);
			float w = 1.0 - 1.6 * f * f;
			acc += c * w;
			wsum += w;
			hi += max(c - 0.55, 0.0) * w;
		}
		vec3 l = acc / wsum;
		vec3 h = hi / wsum;
		vec3 tail = vec3(0.0);
		for (int i = 0; i < 12; i++) {
			float f = (float(i) + 0.5) / 12.0 - 0.5;
			vec3 c = lin(texture(effect_tex, q + len * f * 2.2).rgb / a);
			tail += max(c - 0.6, 0.0);
		}
		l += (tail / 12.0) * streaks * 1.6 * on + h * streaks * 0.5 * on;
		vec3 base = lin(texture(effect_tex, q).rgb / a);
		l = mix(base, l, smoothstep(0.0, 0.25, on));
		COLOR = vec4(sqrt(clamp(l, 0.0, 1.0)) * a, a);
	}
}
