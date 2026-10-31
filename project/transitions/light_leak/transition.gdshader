shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform vec4 colour : source_color = vec4(1.0, 0.55, 0.15, 1.0);
uniform vec4 colour_two : source_color = vec4(0.95, 0.15, 0.3, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float size : hint_range(0.2, 2.0) = 1.0;

vec2 travel_dir() {
	if (direction == 1) {
		return vec2(-1.0, 0.0);
	} else if (direction == 2) {
		return vec2(0.0, -1.0);
	} else if (direction == 3) {
		return vec2(0.0, 1.0);
	} else if (direction == 4) {
		return normalize(vec2(1.0, -0.6));
	}
	return vec2(1.0, 0.0);
}

vec4 transition(vec2 uv) {
	float p = progress;
	vec4 f = from_at(uv);
	vec4 t = to_at(uv);
	vec4 base = mix(f, t, smoothstep(0.3, 0.7, p));
	float env = pow(sin(TR_PI * clamp(p, 0.0, 1.0)), 1.3);
	if (env <= 0.0) {
		return base;
	}
	vec2 q = tr_world(uv);
	vec2 d = travel_dir();
	vec2 n = vec2(-d.y, d.x);
	float half_len = abs(d.x) * tr_ratio() * 0.5 + abs(d.y) * 0.5;
	float along = dot(q, d);
	float side = dot(q, n);
	float field = 0.0;
	float warm = 0.0;
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float r1 = tr_hash(vec2(fi, 1.0));
		float r2 = tr_hash(vec2(fi, 2.0));
		float r3 = tr_hash(vec2(fi, 3.0));
		float r4 = tr_hash(vec2(fi, 4.0));
		float speed = 0.8 + 0.6 * r1;
		float centre_along = (p - 0.5) * 2.0 * half_len * 1.6 * speed + (r2 - 0.5) * half_len * 0.8;
		float centre_side = (r3 - 0.5) * 0.9;
		float sa = (0.18 + 0.22 * r4) * size;
		float sn = (0.45 + 0.5 * r1) * size;
		float da = (along - centre_along) / sa;
		float dn = (side - centre_side) / sn;
		float g = exp(-(da * da + dn * dn)) * (0.6 + 0.6 * r2);
		field += g;
		warm += g * r3;
	}
	float hue = clamp(warm / max(field, 0.0001), 0.0, 1.0);
	float grain = 0.65 + 0.7 * tr_fbm(q * 2.2 / size + d * p * 1.5);
	field = field * grain;
	float wash = env * env * env * 0.45;
	vec3 tone = mix(colour_two.rgb * colour_two.a, colour.rgb * colour.a, hue);
	vec3 hot = vec3(1.0, 0.9, 0.7);
	float k = env * intensity;
	vec3 light = vec3(1.0) - exp(-tone * field * 1.6 * k);
	light += hot * smoothstep(1.1, 2.4, field * k) * 0.45;
	light += colour.rgb * colour.a * wash * intensity;
	light = clamp(light, 0.0, 1.0);
	float la = max(light.r, max(light.g, light.b));
	vec3 rgb = light + base.rgb - light * base.rgb;
	float a = la + base.a - la * base.a;
	return vec4(min(rgb, vec3(a)), a);
}

void fragment() {
	COLOR = transition(UV);
}
