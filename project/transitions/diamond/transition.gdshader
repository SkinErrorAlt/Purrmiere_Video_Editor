shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform int aspect = 0;
uniform float softness : hint_range(0.0, 300.0) = 2.0;
uniform int curve = 1;
uniform float border : hint_range(0.0, 60.0) = 0.0;
uniform vec4 border_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);

vec4 shape_consts(float e) {
	return vec4(0.0);
}

float field(vec2 p, float e, vec4 k) {
	float a = aspect == 0 ? tr_ratio() : 1.0;
	return abs(p.x) / a + abs(p.y);
}

vec2 perim(float t, vec2 h) {
	t = mod(t, 4.0);
	if (t < 1.0) {
		return vec2(mix(-h.x, h.x, t), h.y);
	} else if (t < 2.0) {
		return vec2(h.x, mix(h.y, -h.y, t - 1.0));
	} else if (t < 3.0) {
		return vec2(mix(h.x, -h.x, t - 2.0), -h.y);
	}
	return vec2(-h.x, mix(-h.y, h.y, t - 3.0));
}

float reach(vec2 c, float e, vec4 k) {
	vec2 h = vec2(tr_ratio(), 1.0) * 0.5;
	float m = field(h - c, e, k);
	m = max(m, field(vec2(-h.x, h.y) - c, e, k));
	m = max(m, field(vec2(h.x, -h.y) - c, e, k));
	m = max(m, field(-h - c, e, k));
	return m;
}

vec4 transition(vec2 uv) {
	float e = curve == 1 ? 0.5 * progress + 0.5 * tr_ease(progress, 3) : clamp(progress, 0.0, 1.0);
	vec4 k = shape_consts(e);
	vec2 c = tr_world(centre);
	float f = field(tr_world(uv) - c, e, k);
	float px = 1.0 / max(frame_px.y, 1.0);
	float s = max(softness * px_scale * px, 1.5 * px);
	float bw = max(border, 0.0) * px_scale * px;
	float full = reach(c, e, k) + s + bw;
	float r = direction == 0 ? e * full : (1.0 - e) * full;
	float edge_out = 1.0 - smoothstep(r - s, r, f);
	float edge_in = 1.0 - smoothstep(r - bw - s, r - bw, f);
	float amount = direction == 0 ? edge_out : 1.0 - edge_out;
	vec4 col = mix(from_at(uv), to_at(uv), amount);
	float ring = clamp(edge_out - edge_in, 0.0, 1.0) * border_colour.a;
	return tr_over(vec4(border_colour.rgb, 1.0) * ring, col);
}

void fragment() {
	COLOR = transition(UV);
}
