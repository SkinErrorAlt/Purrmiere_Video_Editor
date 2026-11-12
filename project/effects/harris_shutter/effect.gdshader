shader_type canvas_item;
render_mode blend_disabled;
#include "res://engine/history.gdshaderinc"

uniform float span : hint_range(0.03, 1.3) = 0.27;
uniform int order = 0;
uniform int filters = 1;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

vec3 unpremul(vec4 c) {
	return c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
}

mat3 filter_set() {
	if (filters == 1) {
		vec3 r = vec3(0.86, 0.10, 0.04);
		vec3 g = vec3(0.10, 0.80, 0.10);
		vec3 b = vec3(0.04, 0.10, 0.86);
		return mat3(r, g, b);
	}
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, 1.0));
}

ivec3 slot_order() {
	if (order == 1) {
		return ivec3(0, 2, 1);
	} else if (order == 2) {
		return ivec3(1, 0, 2);
	} else if (order == 3) {
		return ivec3(2, 0, 1);
	} else if (order == 4) {
		return ivec3(1, 2, 0);
	} else if (order == 5) {
		return ivec3(2, 1, 0);
	}
	return ivec3(0, 1, 2);
}

void fragment() {
	vec4 now = texture(TEXTURE, UV);
	float last = clamp(span * history_fps, 0.0, float(history_count));
	vec4 shots[3];
	shots[0] = history_between(last, UV, now);
	shots[1] = history_between(last * 0.5, UV, now);
	shots[2] = now;
	ivec3 s = slot_order();
	vec3 col;
	float a;
	if (filters == 2) {
		int first = s.x == 0 ? 0 : (s.y == 0 ? 1 : 2);
		vec4 warm = first == 0 ? shots[0] : shots[2];
		vec4 cool = first == 0 ? shots[2] : shots[0];
		vec3 w = unpremul(warm);
		vec3 c = unpremul(cool);
		col = vec3(w.r, c.g, c.b);
		a = max(warm.a, cool.a);
	} else {
		mat3 f = filter_set();
		vec3 er = unpremul(shots[s.x]);
		vec3 eg = unpremul(shots[s.y]);
		vec3 eb = unpremul(shots[s.z]);
		vec3 sum = f[0] + f[1] + f[2];
		col = (er * f[0] + eg * f[1] + eb * f[2]) / sum;
		a = max(max(shots[0].a, shots[1].a), shots[2].a);
	}
	vec3 base = unpremul(now);
	vec3 rgb = mix(base, clamp(col, 0.0, 1.0), strength);
	COLOR = vec4(rgb * a, a);
}
