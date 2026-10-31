shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int shape = 0;
uniform float angle : hint_range(-180.0, 180.0) = 20.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float width : hint_range(20.0, 1200.0) = 300.0;
uniform float intensity : hint_range(0.0, 4.0) = 1.5;
uniform vec4 colour : source_color = vec4(1.0, 0.95, 0.86, 1.0);
uniform float softness : hint_range(0.0, 1.0) = 0.3;
uniform int curve = 0;

vec3 to_linear(vec3 c) {
	vec3 lo = c / 12.92;
	vec3 hi = pow((max(c, vec3(0.0)) + 0.055) / 1.055, vec3(2.4));
	return mix(lo, hi, step(vec3(0.04045), c));
}

vec3 to_srgb(vec3 c) {
	vec3 lo = c * 12.92;
	vec3 hi = 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055;
	return mix(lo, hi, step(vec3(0.0031308), c));
}

vec4 lin_premul(vec4 c) {
	if (c.a <= 0.0) {
		return vec4(0.0);
	}
	return vec4(to_linear(c.rgb / c.a) * c.a, c.a);
}

vec4 srgb_premul(vec4 c) {
	if (c.a <= 0.0) {
		return vec4(0.0);
	}
	return vec4(to_srgb(c.rgb / c.a) * c.a, c.a);
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float q = curve == 1 ? tr_ease(p, 3) : p;
	vec2 px = uv * frame_px;
	float th = radians(angle);
	vec2 dir = vec2(cos(th), sin(th));
	float reach = max(width * px_scale, 2.0);
	float pos;
	float ext;
	if (shape == 1) {
		vec2 c = centre * frame_px;
		pos = distance(px, c);
		ext = max(max(distance(c, vec2(0.0)), distance(c, vec2(frame_px.x, 0.0))), max(distance(c, vec2(0.0, frame_px.y)), distance(c, frame_px)));
	} else if (shape == 2) {
		vec2 c = centre * frame_px;
		pos = abs(dot(px - c, dir));
		ext = max(max(abs(dot(-c, dir)), abs(dot(vec2(frame_px.x, 0.0) - c, dir))), max(abs(dot(vec2(0.0, frame_px.y) - c, dir)), abs(dot(frame_px - c, dir))));
	} else {
		pos = dot(px - frame_px * 0.5, dir);
		ext = 0.5 * (abs(frame_px.x * dir.x) + abs(frame_px.y * dir.y));
		pos += ext;
		ext *= 2.0;
	}
	float front = mix(-reach, ext + reach, q);
	float d = pos - front;
	float soft = max(softness * reach * 0.45, 1.0);
	float m = 1.0 - smoothstep(-soft, soft, d);
	vec4 a = from_at(uv);
	vec4 b = to_at(uv);
	float ad = abs(d);
	if (ad >= reach || intensity <= 0.0) {
		return mix(a, b, m);
	}
	float core_w = reach * 0.07;
	float core = exp(-(d * d) / (core_w * core_w));
	float halo = pow(1.0 - ad / reach, 3.0);
	float light = intensity * (1.6 * core + 1.1 * halo);
	vec4 base = mix(lin_premul(a), lin_premul(b), m);
	vec3 bu = base.a > 0.0 ? base.rgb / base.a : vec3(0.0);
	float lum = dot(bu, vec3(0.2126, 0.7152, 0.0722));
	vec3 add = to_linear(colour.rgb) * light * (0.07 + 1.9 * lum * lum + 0.6 * lum);
	vec3 room = max(vec3(1.0) - bu, vec3(0.02));
	vec3 lit = vec3(1.0) - room * exp(-add / room);
	float alpha = base.a;
	vec3 lift = to_linear(colour.rgb) * light * 0.1;
	float glow_a = clamp(max(lift.r, max(lift.g, lift.b)), 0.0, 1.0) * (1.0 - alpha);
	vec3 rgb = lit * alpha + lift * (1.0 - alpha);
	alpha = clamp(alpha + glow_a, 0.0, 1.0);
	return srgb_premul(vec4(min(rgb, vec3(alpha)), alpha));
}

void fragment() {
	COLOR = transition(UV);
}
