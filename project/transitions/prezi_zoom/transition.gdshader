shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int way = 0;
uniform float inset_size : hint_range(0.1, 0.6) = 0.3;
uniform vec2 inset_centre = vec2(0.7, 0.35);
uniform float arc : hint_range(0.0, 1.0) = 0.35;
uniform float turn : hint_range(-45.0, 45.0) = 0.0;
uniform int timing = 1;
uniform float frame_line : hint_range(0.0, 1.0) = 0.0;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float e = tr_ease(p, timing == 1 ? 4 : (timing == 2 ? 3 : 0));
	float s = clamp(inset_size, 0.05, 0.95);
	float r = tr_ratio();
	vec2 lim = vec2(r, 1.0) * (0.5 - 0.5 * s);
	vec2 ci = clamp(tr_world(inset_centre), -lim, lim);
	float rot = radians(turn);
	float t = way == 0 ? e : 1.0 - e;
	float z = pow(s, t) * (1.0 + arc * sin(TR_PI * t));
	vec2 cam = ci * (1.0 - pow(s, t)) / (1.0 - s);
	vec2 pt = cam + tr_rotate(tr_world(uv), rot * t) * z;
	vec2 local = tr_rotate(pt - ci, -rot) / s;
	vec2 inner_uv = tr_frame_uv(local);
	vec2 outer_uv = tr_frame_uv(pt);
	bool in_inset = tr_inside(inner_uv);
	float shown = way == 0 ? smoothstep(0.0, 0.3, p) : 1.0 - smoothstep(0.7, 1.0, p);
	vec4 bg = vec4(background.rgb * background.a, background.a);
	vec4 outer = vec4(0.0);
	vec4 inner = vec4(0.0);
	if (way == 0) {
		outer = tr_inside(outer_uv) ? texture(from_tex, outer_uv) : bg;
		inner = in_inset ? texture(to_tex, inner_uv) : vec4(0.0);
	} else {
		outer = tr_inside(outer_uv) ? texture(to_tex, outer_uv) : bg;
		inner = in_inset ? texture(from_tex, inner_uv) : vec4(0.0);
	}
	if (!in_inset) {
		return outer;
	}
	vec2 edge = min(inner_uv, 1.0 - inner_uv) * vec2(r, 1.0) * s / max(z, 0.0001);
	float line = frame_line * shown * smoothstep(0.0, 0.15, p) * smoothstep(0.0, 0.15, 1.0 - p) * (1.0 - smoothstep(0.0, 0.006, min(edge.x, edge.y)));
	vec4 c = mix(outer, inner, shown);
	return mix(c, vec4(vec3(1.0), 1.0), line * 0.85);
}

void fragment() {
	COLOR = transition(UV);
}
