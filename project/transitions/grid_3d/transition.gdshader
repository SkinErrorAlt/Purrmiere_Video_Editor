shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int columns : hint_range(2, 24) = 8;
uniform int pattern = 0;
uniform float depth : hint_range(0.2, 4.0) = 1.6;
uniform float turn : hint_range(0.0, 90.0) = 30.0;
uniform float gap : hint_range(0.0, 0.4) = 0.12;
uniform float jitter : hint_range(0.0, 1.0) = 0.3;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform float shading : hint_range(0.0, 1.0) = 0.6;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

mat3 rot_y(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, 0.0, s), vec3(0.0, 1.0, 0.0), vec3(-s, 0.0, c));
}

vec4 tile(vec3 ro, vec3 rd, vec2 home, vec2 half_size, float z, float turn_r, float scale, float fog, bool use_from, out float dist) {
	dist = -1.0;
	float d = -ro.z;
	vec3 centre = vec3(home * (d + z) / d, z);
	mat3 m = rot_y(turn_r);
	vec3 n = m * vec3(0.0, 0.0, -1.0);
	float dn = dot(rd, n);
	if (dn > -0.000001) {
		return vec4(0.0);
	}
	float t = dot(centre - ro, n) / dn;
	vec3 q = transpose(m) * (ro + rd * t - centre) / max(scale, 0.0001);
	if (t <= 0.0 || abs(q.x) > half_size.x || abs(q.y) > half_size.y) {
		return vec4(0.0);
	}
	dist = t;
	vec2 cuv = tr_frame_uv(home + q.xy);
	vec4 c = use_from ? texture(from_tex, cuv) : texture(to_tex, cuv);
	float light = mix(1.0, abs(n.z), shading) * (1.0 - fog);
	return tr_shade(c, light);
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float cols = float(columns);
	float rows = max(1.0, floor(cols / tr_ratio() + 0.5));
	vec2 cell = floor(vec2(uv.x * cols, uv.y * rows));
	cell = clamp(cell, vec2(0.0), vec2(cols - 1.0, rows - 1.0));
	vec2 cell_uv = (cell + 0.5) / vec2(cols, rows);
	vec2 home = tr_world(cell_uv);
	vec2 half_size = vec2(tr_ratio() / cols, 1.0 / rows) * 0.5;
	float order;
	if (pattern == 0) {
		order = (cell.x / max(cols - 1.0, 1.0) + cell.y / max(rows - 1.0, 1.0)) * 0.5;
	} else if (pattern == 1) {
		order = tr_hash(cell + 1.7);
	} else if (pattern == 2) {
		order = cell.x / max(cols - 1.0, 1.0);
	} else {
		order = length(cell_uv - 0.5) / 0.7071;
	}
	order = clamp(mix(order, tr_hash(cell + 5.3), jitter * (pattern == 1 ? 0.0 : 0.5)), 0.0, 1.0);
	float u = clamp((p - 0.5 * order) / 0.5, 0.0, 1.0);
	float uo = clamp(u / 0.65, 0.0, 1.0);
	float un = clamp((u - 0.35) / 0.65, 0.0, 1.0);
	float eo = uo * uo;
	float en = 1.0 - (1.0 - un) * (1.0 - un);
	float d = tr_camera_distance(lens);
	vec3 ro = vec3(0.0, 0.0, -d);
	vec3 rd = normalize(vec3(tr_world(uv), 0.0) - ro);
	float shrink_o = 1.0 - gap * smoothstep(0.0, 0.3, uo);
	float shrink_n = 1.0 - gap * (1.0 - smoothstep(0.7, 1.0, un));
	float df = -1.0;
	float dt = -1.0;
	vec4 cf = vec4(0.0);
	vec4 ct = vec4(0.0);
	if (uo < 1.0) {
		cf = tile(ro, rd, home, half_size, depth * eo, radians(turn) * eo, shrink_o, 0.6 * eo, true, df);
		cf *= 1.0 - smoothstep(0.7, 1.0, uo);
	}
	if (un > 0.0) {
		ct = tile(ro, rd, home, half_size, depth * (1.0 - en), -radians(turn) * (1.0 - en), shrink_n, 0.6 * (1.0 - en), false, dt);
		ct *= smoothstep(0.0, 0.3, un);
	}
	vec4 bg = vec4(background.rgb * background.a, background.a);
	vec4 res = bg;
	if (df >= 0.0 && dt >= 0.0) {
		res = df < dt ? tr_over(cf, tr_over(ct, bg)) : tr_over(ct, tr_over(cf, bg));
	} else if (df >= 0.0) {
		res = tr_over(cf, bg);
	} else if (dt >= 0.0) {
		res = tr_over(ct, bg);
	}
	res = mix(res, from_at(uv), 1.0 - smoothstep(0.0, 0.03, progress));
	return mix(res, to_at(uv), smoothstep(0.97, 1.0, progress));
}

void fragment() {
	COLOR = transition(UV);
}
