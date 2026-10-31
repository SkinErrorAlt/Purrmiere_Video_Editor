shader_type canvas_item;
render_mode blend_disabled;

uniform float starts_at : hint_range(0.0, 600.0) = 0.0;
uniform float hold : hint_range(0.0, 1.0) = 0.03;
uniform float fade : hint_range(0.02, 3.0) = 0.3;
uniform float repeat_every : hint_range(0.0, 10.0) = 0.0;
uniform int mode : hint_range(0, 3) = 0;
uniform vec4 colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.85;
uniform float clip_time;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float dt = clip_time - starts_at;
	if (repeat_every > 0.001 && dt >= 0.0) {
		dt = mod(dt, repeat_every);
	}
	float env = 0.0;
	if (dt >= 0.0) {
		float f = clamp((dt - max(hold, 0.0)) / max(fade, 0.001), 0.0, 1.0);
		env = (1.0 - f) * (1.0 - f);
	}
	float w = env * clamp(strength, 0.0, 1.0) * colour.a;
	if (w <= 0.0) {
		COLOR = c;
	} else {
		float a = c.a;
		vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
		vec3 outc = rgb;
		if (mode == 0) {
			outc = mix(rgb, colour.rgb, w);
		} else if (mode == 1) {
			outc = rgb + colour.rgb * w;
		} else if (mode == 2) {
			vec3 lit = rgb * (1.0 + 7.0 * w) * mix(vec3(1.0), colour.rgb, 0.5);
			outc = 1.0 - exp(-lit * 1.2);
			outc = mix(rgb, max(outc, rgb), clamp(w * 1.5, 0.0, 1.0));
		} else {
			outc = mix(rgb, (1.0 - rgb) * colour.rgb, w);
		}
		COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
	}
}
