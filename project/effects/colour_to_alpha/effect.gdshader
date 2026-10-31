shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float transparency_threshold : hint_range(0.0, 1.0) = 0.0;
uniform float opacity_threshold : hint_range(0.0, 1.0) = 1.0;

const float EPS = 0.0001;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 src = c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
	vec3 key = clamp(colour.rgb, 0.0, 1.0);
	float tt = clamp(transparency_threshold, 0.0, 1.0);
	float ot = max(clamp(opacity_threshold, 0.0, 1.0), tt + EPS);
	float alpha = 0.0;
	float dist = 0.0;
	for (int i = 0; i < 3; i++) {
		float d = abs(src[i] - key[i]);
		float a = 0.0;
		if (d < tt + EPS) {
			a = 0.0;
		} else if (d > ot - EPS) {
			a = 1.0;
		} else if (src[i] < key[i]) {
			a = (d - tt) / max(min(ot, key[i]) - tt, EPS);
		} else {
			a = (d - tt) / max(min(ot, 1.0 - key[i]) - tt, EPS);
		}
		a = clamp(a, 0.0, 1.0);
		if (a > alpha) {
			alpha = a;
			dist = d;
		}
	}
	vec3 outc = src;
	if (alpha > EPS) {
		float ratio = tt / max(dist, EPS);
		vec3 cut = key + (src - key) * ratio;
		outc = clamp(cut + (src - cut) / alpha, 0.0, 1.0);
	} else {
		outc = vec3(0.0);
	}
	float a_out = c.a * alpha;
	COLOR = vec4(outc * a_out, a_out);
}
