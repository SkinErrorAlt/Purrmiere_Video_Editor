shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform vec2 centre = vec2(0.5, 0.5);
uniform float rays : hint_range(3.0, 48.0) = 14.0;
uniform float taper : hint_range(0.0, 1.0) = 0.55;
uniform float spin : hint_range(-180.0, 180.0) = 35.0;
uniform float tip : hint_range(0.0, 2.0) = 0.8;
uniform vec4 tint : source_color = vec4(1.0, 0.93, 0.72, 1.0);
uniform float ragged : hint_range(0.0, 1.0) = 0.5;

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	vec2 ar = vec2(tr_ratio(), 1.0);
	vec2 d = (uv - centre) * ar;
	float r = length(d);
	float reach = length(vec2(max(centre.x, 1.0 - centre.x) * tr_ratio(), max(centre.y, 1.0 - centre.y))) + 0.001;
	float n = max(rays, 3.0);
	float ang = atan(d.y, d.x) + radians(spin) * p;
	float a = ang / (TR_PI * 2.0);
	float lane = floor(a * n);
	float within = fract(a * n);
	float h = tr_hash(vec2(lane, 4.0));
	float wide = mix(0.5, 1.0, mod(lane, 2.0) < 1.0 ? 1.0 : 0.45);
	float speed = mix(1.0, 0.55 + h * 0.95, ragged);
	float grow = clamp(p * 1.45 * speed, 0.0, 2.0);
	float half_w = 0.5 * wide * mix(1.0, 0.45 + h * 0.8, ragged);
	float side = abs(within - 0.5);
	float narrow = mix(1.0, clamp(1.0 - r / reach, 0.0, 1.0) + 0.25, taper);
	float edge = 1.5 / max(frame_px.y, 1.0) / max(r, 0.015);
	float in_ray = 1.0 - smoothstep(half_w * narrow - edge, half_w * narrow + edge, side);
	float len = grow * reach * 1.25;
	float along = 1.0 - smoothstep(len - 0.02, len + 0.02, r);
	float m = clamp(in_ray * along, 0.0, 1.0);
	m = max(m, smoothstep(0.92, 1.0, p));
	vec4 col = mix(from_at(uv), to_at(uv), m);
	float hot = smoothstep(0.1, 0.0, abs(r - len)) * in_ray * tip * (1.0 - smoothstep(0.9, 1.0, p)) * step(0.01, p);
	col.rgb += tint.rgb * hot;
	return col;
}

void fragment() {
	COLOR = transition(UV);
}
