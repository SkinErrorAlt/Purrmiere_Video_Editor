shader_type canvas_item;
render_mode blend_disabled;

uniform float starts_at : hint_range(0.0, 600.0) = 0.0;
uniform float duration : hint_range(0.03, 3.0) = 0.25;
uniform int flips : hint_range(1, 24) = 4;
uniform int style : hint_range(0, 3) = 3;
uniform float threshold : hint_range(0.0, 1.0) = 0.45;
uniform float flash : hint_range(0.0, 1.0) = 0.7;
uniform float repeat_every : hint_range(0.0, 10.0) = 0.0;
uniform float clip_time;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float dt = clip_time - starts_at;
	if (repeat_every > 0.001 && dt >= 0.0) {
		dt = mod(dt, repeat_every);
	}
	if (dt < 0.0 || dt > duration || c.a <= 0.0001) {
		COLOR = c;
	} else {
		float f = dt / max(duration, 0.001);
		int n = int(floor(f * float(max(flips, 1))));
		vec3 rgb = c.rgb / c.a;
		float y = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
		float bw = smoothstep(threshold - 0.03, threshold + 0.03, y);
		int mode = style;
		if (style == 3) {
			mode = n % 3;
		}
		vec3 outc = rgb;
		if (n % 2 == 0 || style == 3) {
			if (mode == 0) {
				outc = 1.0 - rgb;
			} else if (mode == 1) {
				outc = vec3(bw);
			} else {
				outc = vec3(1.0 - bw);
			}
		}
		float fl = flash * clamp(1.0 - f * 4.0, 0.0, 1.0);
		outc = mix(outc, vec3(1.0), fl);
		COLOR = vec4(clamp(outc, 0.0, 1.0) * c.a, c.a);
	}
}
