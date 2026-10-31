shader_type canvas_item;
render_mode blend_disabled;

uniform float bpm : hint_range(30.0, 300.0) = 120.0;
uniform float offset : hint_range(-10.0, 10.0) = 0.0;
uniform int every : hint_range(0, 3) = 0;
uniform int mode : hint_range(0, 2) = 1;
uniform vec4 colour : source_color = vec4(1.0, 0.25, 0.6, 1.0);
uniform bool cycle = false;
uniform float strength : hint_range(0.0, 1.0) = 0.5;
uniform float decay : hint_range(0.0, 1.0) = 0.5;
uniform float clip_time;

vec3 hue(float h) {
	vec3 k = clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return k;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float mul = every == 1 ? 0.5 : (every == 2 ? 0.25 : (every == 3 ? 2.0 : 1.0));
	float beats = (clip_time - offset) * max(bpm, 1.0) / 60.0 * mul;
	float env = 0.0;
	vec3 tint = colour.rgb;
	if (beats >= 0.0) {
		env = pow(1.0 - fract(beats), 2.0 + decay * 10.0);
		if (cycle) {
			tint = hue(fract(floor(beats) * 0.13 + 0.9));
		}
	}
	float w = env * clamp(strength, 0.0, 1.0) * colour.a;
	if (w <= 0.0 || c.a <= 0.0001) {
		COLOR = c;
	} else {
		vec3 rgb = c.rgb / c.a;
		vec3 outc = rgb;
		if (mode == 0) {
			outc = mix(rgb, tint, w);
		} else if (mode == 1) {
			outc = rgb + tint * w;
		} else {
			outc = mix(rgb, 1.0 - rgb, w);
		}
		COLOR = vec4(clamp(outc, 0.0, 1.0) * c.a, c.a);
	}
}
