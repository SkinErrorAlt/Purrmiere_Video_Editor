shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 1;
uniform float spread : hint_range(0.0, 0.3) = 0.06;
uniform float travel : hint_range(0.0, 1.0) = 0.08;
uniform float glow : hint_range(0.0, 1.0) = 0.3;

vec2 axis() {
	if (direction == 1) {
		return vec2(-1.0, 0.0);
	} else if (direction == 2) {
		return vec2(0.0, 1.0);
	} else if (direction == 3) {
		return vec2(0.0, -1.0);
	} else if (direction == 4) {
		return normalize(vec2(1.0, 0.56));
	}
	return vec2(1.0, 0.0);
}

vec4 planes(vec2 uv, vec2 shift, vec2 split, bool use_from) {
	vec4 r = use_from ? from_mirrored(uv - shift - split) : to_mirrored(uv - shift - split);
	vec4 g = use_from ? from_mirrored(uv - shift) : to_mirrored(uv - shift);
	vec4 b = use_from ? from_mirrored(uv - shift + split) : to_mirrored(uv - shift + split);
	float a = max(r.a, max(g.a, b.a));
	return vec4(r.r, g.g, b.b, a);
}

vec4 transition(vec2 uv) {
	float p = progress;
	float s = sin(TR_PI * clamp(p, 0.0, 1.0));
	if (s <= 0.0 || !tr_inside(uv)) {
		return mix(from_at(uv), to_at(uv), step(0.5, p));
	}
	vec2 ax = axis();
	float e = tr_ease(p, 4);
	vec2 split = ax * spread * s;
	vec2 out_shift = ax * travel * e;
	vec2 in_shift = -ax * travel * (1.0 - e);
	vec4 f = planes(uv, out_shift, split, true);
	vec4 t = planes(uv, in_shift, split, false);
	vec4 c = mix(f, t, smoothstep(0.25, 0.75, p));
	float k = glow * s * s;
	vec3 rgb = c.rgb + c.rgb * c.rgb * k * 1.5;
	return vec4(min(rgb, vec3(c.a)), c.a);
}

void fragment() {
	COLOR = transition(UV);
}
