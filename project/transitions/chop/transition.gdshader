shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int pieces = 2;
uniform float angle : hint_range(-80.0, 80.0) = 20.0;
uniform int timing = 2;
uniform float stagger : hint_range(0.0, 0.8) = 0.0;
uniform float edge_shade : hint_range(0.0, 1.0) = 0.0;

int curve_of(int t) {
	if (t == 1) {
		return 3;
	} else if (t == 2) {
		return 4;
	} else if (t == 3) {
		return 2;
	} else if (t == 4) {
		return 1;
	}
	return 0;
}

vec4 transition(vec2 uv) {
	int n = clamp(pieces, 2, 16);
	vec2 w = tr_world(uv);
	float a = radians(angle);
	vec2 t = vec2(cos(a), sin(a));
	vec2 nrm = vec2(-t.y, t.x);
	float r = tr_ratio();
	float ext_n = abs(nrm.x) * r + abs(nrm.y);
	float ext_t = abs(t.x) * r + abs(t.y);
	float across = dot(w, nrm) / ext_n + 0.5;
	float band = clamp(floor(across * float(n)), 0.0, float(n - 1));
	float side = mod(band, 2.0) < 0.5 ? 1.0 : -1.0;
	float st = clamp(stagger, 0.0, 0.95);
	float start = st * band / float(n - 1);
	float local = clamp((progress - start) / (1.0 - st), 0.0, 1.0);
	float shift = tr_ease(local, curve_of(timing)) * ext_t * 1.02 * side;
	vec2 src = w - t * shift;
	vec2 suv = tr_frame_uv(src);
	if (tr_inside(suv)) {
		vec4 c = texture(from_tex, suv);
		float inside_band = fract(across * float(n));
		float edge = min(inside_band, 1.0 - inside_band) * ext_n / float(n);
		float shade = edge_shade * (1.0 - smoothstep(0.0, 0.03, edge)) * clamp(local * 10.0, 0.0, 1.0);
		return tr_shade(c, 1.0 - 0.6 * shade);
	}
	return texture(to_tex, uv);
}

void fragment() {
	COLOR = transition(UV);
}
