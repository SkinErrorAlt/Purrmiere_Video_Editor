shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform int squeeze : hint_range(0, 7) = 1;
uniform float own_squeeze : hint_range(1.0, 3.0) = 1.33;
uniform int fit : hint_range(0, 1) = 0;
uniform float pan : hint_range(-1.0, 1.0) = 0.0;
uniform vec4 bars : source_color = vec4(0.0, 0.0, 0.0, 1.0);

const float FACTORS[7] = float[7](1.25, 1.33333, 1.5, 1.55, 1.6, 1.8, 2.0);

void fragment() {
	float f = squeeze >= 0 && squeeze < 7 ? FACTORS[squeeze] : own_squeeze;
	f = clamp(f, 1.0, 3.0);
	vec2 size = max(tex_size, vec2(1.0));
	if (fit == 0) {
		float v = (UV.y - 0.5) * f + 0.5;
		if (v < 0.0 || v > 1.0) {
			COLOR = vec4(bars.rgb * bars.a, bars.a);
		} else {
			float step_v = f / size.y;
			vec4 s = vec4(0.0);
			for (int i = 0; i < 4; i++) {
				float o = (float(i) + 0.5) / 4.0 - 0.5;
				s += texture(TEXTURE, vec2(UV.x, clamp(v + o * step_v, 0.0, 1.0)));
			}
			COLOR = s * 0.25;
		}
	} else {
		float room = 0.5 - 0.5 / f;
		float u = (UV.x - 0.5) / f + 0.5 + clamp(pan, -1.0, 1.0) * room;
		COLOR = texture(TEXTURE, vec2(clamp(u, 0.0, 1.0), UV.y));
	}
}
