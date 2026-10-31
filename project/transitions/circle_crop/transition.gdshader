shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform vec2 centre = vec2(0.5, 0.5);
uniform int timing = 0;
uniform float softness : hint_range(0.0, 300.0) = 2.0;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

float corner_reach(vec2 c) {
	vec2 h = vec2(tr_ratio(), 1.0) * 0.5;
	float m = max(length(h - c), length(vec2(-h.x, h.y) - c));
	return max(m, max(length(vec2(h.x, -h.y) - c), length(-h - c)));
}

vec4 transition(vec2 uv) {
	vec2 c = tr_world(centre);
	float f = length(tr_world(uv) - c);
	float px = 1.0 / max(frame_px.y, 1.0);
	float s = max(softness * px_scale * px, 1.5 * px);
	float k = abs(2.0 * progress - 1.0);
	float g = timing == 0 ? pow(k, 1.8) : (timing == 1 ? k : tr_ease(k, 3));
	float r = g * (corner_reach(c) + s);
	float inside = 1.0 - smoothstep(r - s, r, f);
	vec4 pic = progress < 0.5 ? from_at(uv) : to_at(uv);
	vec4 bg = vec4(background.rgb * background.a, background.a);
	return mix(bg, pic, inside);
}

void fragment() {
	COLOR = transition(UV);
}
