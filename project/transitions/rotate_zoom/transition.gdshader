shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int rotations = 1;
uniform float scale : hint_range(1.0, 20.0) = 8.0;
uniform int timing = 0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform vec4 background : source_color = vec4(0.15, 0.15, 0.15, 1.0);

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float e = tr_ease(p, timing == 1 ? 3 : (timing == 2 ? 4 : 0));
	float a = -float(rotations) * 2.0 * TR_PI * e;
	float shrink = mix(max(scale, 1.0), 1.0, abs(2.0 * e - 1.0));
	vec2 w = tr_world(uv) - tr_world(centre);
	vec2 src = tr_rotate(w, -a) * shrink + tr_world(centre);
	vec2 suv = tr_frame_uv(src);
	if (!tr_inside(suv)) {
		return vec4(background.rgb * background.a, background.a);
	}
	return mix(texture(from_tex, suv), texture(to_tex, suv), e);
}

void fragment() {
	COLOR = transition(UV);
}
