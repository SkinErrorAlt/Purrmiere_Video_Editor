shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float strength : hint_range(0.0, 2.0) = 1.0;
uniform float bloom : hint_range(0.0, 1.0) = 0.6;
uniform float px_scale = 1.0;
#define px_out (px_scale * 32.0)

void fragment() {
	vec2 uv_px = fwidth(UV);
	vec4 src = texture(effect_tex, UV);
	vec4 b = texelFetch(TEXTURE, ivec2(0, 0), 0);
	float e = (b.r - 0.5) * 8.0 * strength;
	vec3 wb = (b.gba - 0.5) * 4.0 * strength;
	if (abs(e) < 0.02 && max(max(abs(wb.r), abs(wb.g)), abs(wb.b)) < 0.02) {
		COLOR = src;
	} else {
		float a = max(src.a, 0.0001);
		vec3 l = src.rgb / a;
		l = l * l;
		vec3 g = exp2(vec3(e) + wb);
		vec3 x = l * g;
		if (e > 0.05 && bloom > 0.0) {
			vec2 px = uv_px;
			vec3 acc = vec3(0.0);
			for (int i = 0; i < 12; i++) {
				float ang = float(i) * 2.39996;
				float r = (6.0 + 3.0 * float(i)) * px_out;
				vec3 c = texture(effect_tex, UV + vec2(cos(ang), sin(ang)) * r * px).rgb / a;
				c = c * c * g;
				acc += max(c - 0.9, 0.0);
			}
			x += acc / 12.0 * bloom * min(e, 3.0) * 0.8;
		}
		float m = max(max(x.r, x.g), x.b);
		if (m > 0.8) {
			float mc = 0.8 + 0.2 * (1.0 - exp(-(m - 0.8) / 0.2));
			x = x * (mc / m);
			x = mix(x, vec3(mc), smoothstep(1.0, 4.0, m));
		}
		COLOR = vec4(sqrt(clamp(x, 0.0, 1.0)) * a, a);
	}
}
