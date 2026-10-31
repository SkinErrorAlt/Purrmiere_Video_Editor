shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float rotation : hint_range(-45.0, 45.0) = 6.0;
uniform float scale : hint_range(1.0, 3.0) = 1.2;
uniform float glow : hint_range(0.0, 1.0) = 0.35;
uniform float blend : hint_range(0.05, 0.5) = 0.2;
uniform vec2 centre = vec2(0.5, 0.5);

vec2 place(vec2 uv, float deg, float s) {
	vec2 c = tr_world(centre);
	vec2 w = tr_world(uv) - c;
	return tr_frame_uv(tr_rotate(w, -radians(deg)) / s + c);
}

vec4 soft(vec2 suv, bool use_from, float radius) {
	vec4 acc = vec4(0.0);
	for (int i = 0; i < 8; i++) {
		float a = float(i) * TR_PI * 0.25 + 0.39;
		vec2 o = vec2(cos(a) / tr_ratio(), sin(a)) * radius * (i % 2 == 0 ? 1.0 : 0.55);
		acc += use_from ? from_mirrored(suv + o) : to_mirrored(suv + o);
	}
	return acc * 0.125;
}

vec4 dreamy(vec2 suv, bool use_from, float g) {
	vec4 c = use_from ? from_mirrored(suv) : to_mirrored(suv);
	if (g < 0.0001) {
		return c;
	}
	vec4 s = soft(suv, use_from, 0.02);
	vec4 m = mix(c, s, 0.6 * g);
	vec3 lift = m.rgb + s.rgb * 0.45 * g;
	return vec4(min(lift, vec3(m.a)), m.a);
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float e = tr_ease(p, 3);
	float sc = max(scale, 1.0);
	float g = glow * pow(sin(TR_PI * p), 2.0);
	float b = clamp(blend, 0.005, 0.5);
	float w = smoothstep(0.5 - b, 0.5 + b, p);
	vec4 a = vec4(0.0);
	vec4 z = vec4(0.0);
	if (w < 1.0) {
		float f = 2.0 * e;
		a = dreamy(place(uv, rotation * f, pow(sc, f)), true, g);
	}
	if (w > 0.0) {
		float f = 2.0 * e - 2.0;
		z = dreamy(place(uv, rotation * f, pow(sc, -f)), false, g);
	}
	return mix(a, z, w);
}

void fragment() {
	COLOR = transition(UV);
}
