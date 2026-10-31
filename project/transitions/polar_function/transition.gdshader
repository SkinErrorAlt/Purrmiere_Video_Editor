shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int petals : hint_range(1, 16) = 5;
uniform float depth : hint_range(0.0, 0.9) = 0.25;
uniform float softness : hint_range(0.0, 40.0) = 1.5;
uniform float rotation : hint_range(-180.0, 180.0) = 0.0;
uniform float twist : hint_range(-1.0, 1.0) = 0.0;
uniform vec2 centre = vec2(0.5, 0.5);

vec4 transition(vec2 uv) {
	float p = progress;
	vec2 c = tr_world(centre);
	vec2 rel = tr_world(uv) - c;
	vec2 h = vec2(tr_ratio() * 0.5, 0.5);
	float reach = length(abs(c) + h);
	float d = length(rel);
	float a = atan(rel.y, rel.x) - 0.5 * TR_PI - radians(rotation) - twist * TR_PI * p;
	float shape = (1.0 + depth * cos(float(petals) * a)) / (1.0 + depth);
	float soft = max(softness * px_scale / max(frame_px.y, 1.0), 0.0005);
	float k = reach * (1.0 + depth) / max(1.0 - depth, 0.05);
	float r = shape * k * p - soft + 2.0 * soft * p;
	float m = 1.0 - smoothstep(r - soft, r + soft, d);
	return mix(from_at(uv), to_at(uv), m);
}

void fragment() {
	COLOR = transition(UV);
}
