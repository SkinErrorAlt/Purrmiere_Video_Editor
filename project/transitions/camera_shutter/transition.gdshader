shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int blades = 7;
uniform float turn : hint_range(0.0, 180.0) = 50.0;
uniform float hold : hint_range(0.0, 0.6) = 0.06;
uniform vec2 centre = vec2(0.5, 0.5);
uniform vec4 blade_colour : source_color = vec4(0.13, 0.13, 0.14, 1.0);
uniform float shading : hint_range(0.0, 1.0) = 0.6;
uniform float softness : hint_range(0.0, 300.0) = 2.0;

vec4 transition(vec2 uv) {
	vec2 c = tr_world(centre);
	vec2 p = tr_world(uv) - c;
	vec2 h = vec2(tr_ratio(), 1.0) * 0.5;
	float reach = max(max(length(h - c), length(vec2(-h.x, h.y) - c)), max(length(vec2(h.x, -h.y) - c), length(-h - c)));
	float px = 1.0 / max(frame_px.y, 1.0);
	float s = max(softness * px_scale * px, 1.5 * px);
	float amax = reach + s + 0.02;
	float hh = clamp(hold, 0.0, 0.9) * 0.5;
	float span = max(0.5 - hh, 0.0001);
	float closing = tr_ease(clamp(progress / span, 0.0, 1.0), 3);
	float opening = tr_ease(clamp((progress - 0.5 - hh) / span, 0.0, 1.0), 3);
	float shut = progress < 0.5 ? closing : 1.0 - opening;
	float a = amax * (1.0 - shut);
	float rot = radians(turn) * shut;
	int n = clamp(blades, 3, 16);
	float step_a = 2.0 * TR_PI / float(n);
	float worst = -1000000.0;
	int top = 0;
	float top_d = 0.0;
	float next_d = 0.0;
	float first = dot(p, vec2(cos(rot), sin(rot))) - a;
	float prev = first;
	for (int i = 0; i < n; i++) {
		int j = i + 1 < n ? i + 1 : 0;
		float ang = rot + float(j) * step_a;
		float dj = j == 0 ? first : dot(p, vec2(cos(ang), sin(ang))) - a;
		worst = max(worst, prev);
		if (prev > 0.0 && dj <= 0.0) {
			top = i;
			top_d = prev;
			next_d = dj;
		}
		prev = dj;
	}
	float open_amount = 1.0 - smoothstep(-s, 0.0, worst);
	vec4 pic = progress < 0.5 ? from_at(uv) : to_at(uv);
	float blade_ang = rot + float(top) * step_a;
	vec2 along = vec2(-sin(blade_ang), cos(blade_ang));
	float sheen = 0.5 + 0.5 * dot(normalize(p + vec2(0.000001)), normalize(along + vec2(0.3, 0.6)));
	float tone = 0.82 + 0.36 * fract(float(top) * 0.618034);
	float light = mix(1.0, tone * (0.75 + 0.5 * sheen), shading);
	float shadow = 1.0 - shading * 0.6 * (1.0 - smoothstep(0.0, 0.012, -next_d));
	float edge = shading * 0.5 * (1.0 - smoothstep(0.0, 0.004, top_d));
	vec3 rgb = blade_colour.rgb * light * shadow + vec3(edge) * 0.35;
	vec4 blade = vec4(rgb * blade_colour.a, blade_colour.a);
	return mix(blade, pic, open_amount);
}

void fragment() {
	COLOR = transition(UV);
}
