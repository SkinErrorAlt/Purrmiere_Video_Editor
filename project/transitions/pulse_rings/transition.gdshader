shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform vec2 centre = vec2(0.5, 0.5);
uniform float crests : hint_range(1.0, 14.0) = 4.0;
uniform float bend : hint_range(0.0, 0.12) = 0.03;
uniform float glow : hint_range(0.0, 2.0) = 0.7;
uniform vec4 tint : source_color = vec4(0.65, 0.85, 1.0, 1.0);
uniform float width : hint_range(0.02, 0.6) = 0.16;

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	vec2 aspect = vec2(tr_ratio(), 1.0);
	vec2 d = (uv - centre) * aspect;
	float r = length(d);
	float reach = length(vec2(max(centre.x, 1.0 - centre.x) * tr_ratio(), max(centre.y, 1.0 - centre.y))) + 0.001;
	float w = max(width, 0.02);
	float front = p * (reach + w * 2.0) - w;
	float band = (front - r) / w;
	float cover = clamp(band + 0.5, 0.0, 1.0);
	float ripple = sin(clamp(band, -1.0, 1.0) * TR_PI * max(crests, 1.0)) * smoothstep(1.2, 0.0, abs(band));
	vec2 push = (r > 0.0001 ? d / r : vec2(0.0)) * ripple * bend;
	vec2 suv = uv + push / aspect;
	vec4 col = mix(from_clamped(suv), to_clamped(suv), smoothstep(0.0, 1.0, cover));
	float crest = smoothstep(0.55, 1.0, 1.0 - abs(band)) * (1.0 - smoothstep(0.92, 1.0, p));
	col.rgb += tint.rgb * crest * glow;
	float trail = smoothstep(1.0, 0.0, abs(band * 0.7)) * max(ripple, 0.0) * glow * 0.25;
	col.rgb += tint.rgb * trail;
	return col;
}

void fragment() {
	COLOR = transition(UV);
}
