shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform float stops : hint_range(0.0, 8.0) = 4.0;
uniform float whiteout : hint_range(0.0, 1.0) = 1.0;
uniform vec4 colour : source_color = vec4(1.0, 0.98, 0.94, 1.0);
uniform float bloom : hint_range(0.0, 1.0) = 0.5;

vec4 exposed(vec4 c, float e) {
	vec3 s = c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
	vec3 x = s * exp2(stops * e) + vec3(bloom * 0.25 * e * e);
	float peak = max(x.r, max(x.g, x.b));
	vec3 clipped = min(x, vec3(1.0));
	vec3 bleached = mix(clipped, vec3(1.0), clamp((peak - 1.0) * 0.25, 0.0, 1.0));
	return vec4(bleached * c.a, c.a);
}

vec4 transition(vec2 uv) {
	float p = progress;
	vec4 f = from_at(uv);
	vec4 t = to_at(uv);
	float s = sin(TR_PI * clamp(p, 0.0, 1.0));
	if (s <= 0.0) {
		return mix(f, t, step(0.5, p));
	}
	float e = p < 0.5 ? pow(s, 1.6) : pow(s, 2.4);
	vec4 base = mix(exposed(f, e), exposed(t, e), smoothstep(0.44, 0.56, p));
	float w = pow(e, 5.0) * whiteout;
	vec4 c = vec4(colour.rgb * colour.a, colour.a);
	return mix(base, c, w);
}

void fragment() {
	COLOR = transition(UV);
}
