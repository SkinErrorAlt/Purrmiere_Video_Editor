shader_type canvas_item;
render_mode blend_disabled;
#include "res://effects/_events/ev.gdshaderinc"

void fragment() {
	int a = ev_age_of(UV);
	bool ok = ev_valid(TEXTURE, a);
	vec3 acc = vec3(0.0);
	float wsum = 0.0;
	for (int j = 0; j < EV_NY; j++) {
		for (int i = 0; i < EV_NX; i++) {
			vec2 p = ev_point(i, j);
			vec3 c = ev_thumb(TEXTURE, a, p).rgb;
			float w = 1.0 + 1.5 * exp(-dot(p - 0.5, p - 0.5) * 8.0);
			acc += c * c * w;
			wsum += w;
		}
	}
	vec3 m = acc / wsum + vec3(1.0 / 1024.0);
	COLOR = vec4(clamp((log2(m) + 10.0) / 10.0, 0.0, 1.0), ok ? 1.0 : 0.0);
}
