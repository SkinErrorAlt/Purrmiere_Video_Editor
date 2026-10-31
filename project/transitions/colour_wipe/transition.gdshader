shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform vec4 colour : source_color = vec4(0.49, 0.3, 1.0, 1.0);
uniform float overlap : hint_range(-0.5, 0.9) = 0.4;
uniform float softness : hint_range(0.0, 200.0) = 0.0;
uniform int curve = 1;

float w_sweep(float v, float p, float soft) {
	float s = max(soft, 0.0001);
	float e = mix(-s, 1.0, p);
	return 1.0 - smoothstep(e, e + s, v);
}

float along_coord(vec2 uv) {
	if (direction == 1) {
		return 1.0 - uv.x;
	} else if (direction == 2) {
		return uv.y;
	} else if (direction == 3) {
		return 1.0 - uv.y;
	}
	return uv.x;
}

float across_coord(vec2 uv) {
	return direction < 2 ? uv.y : uv.x;
}

float along_px() {
	return direction < 2 ? frame_px.x : frame_px.y;
}

vec4 transition(vec2 uv) {
	int kind = curve == 1 ? 3 : 0;
	float span = 0.5 + clamp(overlap, -0.5, 0.9) * 0.5;
	float lead = tr_ease(clamp(progress / span, 0.0, 1.0), kind);
	float trail = tr_ease(clamp((progress - (1.0 - span)) / span, 0.0, 1.0), kind);
	float v = along_coord(uv);
	float s = max(softness * px_scale, 1.0) / along_px();
	float c_lead = w_sweep(v, lead, s);
	float c_trail = min(w_sweep(v, trail, s), c_lead);
	vec4 col = vec4(colour.rgb * colour.a, colour.a);
	return from_at(uv) * (1.0 - c_lead) + col * (c_lead - c_trail) + to_at(uv) * c_trail;
}

void fragment() {
	COLOR = transition(UV);
}
