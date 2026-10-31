shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform vec2 centre = vec2(0.5, 0.5);
uniform float angle : hint_range(-180.0, 180.0) = 0.0;
uniform float gap : hint_range(0.0, 1.5) = 0.5;
uniform float softness : hint_range(0.0, 300.0) = 2.0;
uniform int curve = 1;

float half_disc(vec2 p, vec2 nrm, float r, float s) {
	float disc = 1.0 - smoothstep(r - s, r, length(p));
	float side = smoothstep(-s * 0.5, s * 0.5, dot(p, nrm));
	return disc * side;
}

vec4 transition(vec2 uv) {
	float e = curve == 1 ? 0.5 * progress + 0.5 * tr_ease(progress, 3) : clamp(progress, 0.0, 1.0);
	vec2 c = tr_world(centre);
	vec2 p = tr_world(uv) - c;
	vec2 h = vec2(tr_ratio(), 1.0) * 0.5;
	float reach = max(max(length(h - c), length(vec2(-h.x, h.y) - c)), max(length(vec2(h.x, -h.y) - c), length(-h - c)));
	float px = 1.0 / max(frame_px.y, 1.0);
	float s = max(softness * px_scale * px, 1.5 * px);
	float lead = clamp(gap, 0.0, 2.0);
	float r = e * (reach + s * 2.0);
	float off = lead * 0.4 * reach * e * (1.0 - e) * (1.0 - e) * 6.75;
	float rad = radians(angle);
	vec2 nrm = vec2(-sin(rad), cos(rad));
	float k = half_disc(p - nrm * off, nrm, r, s) + half_disc(p + nrm * off, -nrm, r, s);
	return mix(from_at(uv), to_at(uv), clamp(k, 0.0, 1.0));
}

void fragment() {
	COLOR = transition(UV);
}
