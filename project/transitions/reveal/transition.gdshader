shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int direction = 0;
uniform int style = 0;
uniform int timing = 1;
uniform float softness : hint_range(0.0, 0.5) = 0.06;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

vec2 travel_of(int d) {
	if (d == 1) {
		return vec2(1.0, 0.0);
	} else if (d == 2) {
		return vec2(0.0, -1.0);
	} else if (d == 3) {
		return vec2(0.0, 1.0);
	} else if (d == 4) {
		return vec2(-1.0, -1.0);
	} else if (d == 5) {
		return vec2(1.0, -1.0);
	} else if (d == 6) {
		return vec2(-1.0, 1.0);
	} else if (d == 7) {
		return vec2(1.0, 1.0);
	}
	return vec2(-1.0, 0.0);
}

int curve_of(int t) {
	if (t == 1) {
		return 3;
	} else if (t == 2) {
		return 4;
	} else if (t == 3) {
		return 2;
	} else if (t == 4) {
		return 5;
	} else if (t == 5) {
		return 7;
	}
	return 0;
}

float lead_alpha(vec2 q, vec2 v, float soft, float e) {
	if (!tr_inside(q)) {
		return 0.0;
	}
	float lead = 1e9;
	if (v.x < -0.5) {
		lead = min(lead, q.x * tr_ratio());
	}
	if (v.x > 0.5) {
		lead = min(lead, (1.0 - q.x) * tr_ratio());
	}
	if (v.y < -0.5) {
		lead = min(lead, q.y);
	}
	if (v.y > 0.5) {
		lead = min(lead, 1.0 - q.y);
	}
	float a = smoothstep(0.0, max(soft, 0.0001), lead);
	return max(a, smoothstep(0.985, 1.0, e));
}

vec4 transition(vec2 uv) {
	float e = tr_ease(progress, curve_of(timing));
	vec2 v = travel_of(direction);
	vec4 bg = vec4(background.rgb * background.a, background.a);
	vec4 from_c = texture(from_tex, uv);

	if (style == 1) {
		float h1 = clamp(e * 2.0, 0.0, 1.0);
		float h2 = clamp(e * 2.0 - 1.0, 0.0, 1.0);
		vec2 q2 = uv + v * (1.0 - h2);
		float a2 = lead_alpha(q2, v, softness, h2);
		vec4 inc2 = texture(to_tex, clamp(q2, vec2(0.0), vec2(1.0))) * (a2 * h2);
		vec4 old_b = tr_over(from_c * (1.0 - h1), bg);
		vec4 new_b = tr_over(inc2, bg);
		return e < 0.5 ? old_b : new_b;
	}

	vec2 q = uv + v * (1.0 - e);
	float a_in = lead_alpha(q, v, softness, e);
	vec4 inc = texture(to_tex, clamp(q, vec2(0.0), vec2(1.0))) * a_in;
	vec4 old_faded = from_c * (1.0 - e);
	return tr_over(inc, tr_over(old_faded, bg));
}

void fragment() {
	COLOR = transition(UV);
}
