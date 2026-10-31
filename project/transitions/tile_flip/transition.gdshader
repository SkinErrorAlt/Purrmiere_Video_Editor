shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int columns : hint_range(2, 24) = 6;
uniform int axis = 0;
uniform int pattern = 0;
uniform float flip_time : hint_range(0.15, 1.0) = 0.45;
uniform float gap : hint_range(0.0, 0.4) = 0.1;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform float shading : hint_range(0.0, 1.0) = 0.6;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

mat3 turn_m(float a) {
	float c = cos(a);
	float s = sin(a);
	if (axis == 1) {
		return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
	}
	return mat3(vec3(c, 0.0, s), vec3(0.0, 1.0, 0.0), vec3(-s, 0.0, c));
}

float tile_order(vec2 cell, vec2 grid) {
	vec2 g = max(grid - 1.0, vec2(1.0));
	if (pattern == 1) {
		return cell.x / g.x;
	} else if (pattern == 2) {
		return (cell.x / g.x + cell.y / g.y) * 0.5;
	} else if (pattern == 3) {
		return clamp(length((cell + 0.5) / grid - 0.5) / 0.7071, 0.0, 1.0);
	}
	return tr_hash(cell + 2.9);
}

vec4 tile(vec3 ro, vec3 rd, vec2 cell, vec2 grid, float p, out float dist) {
	dist = -1.0;
	if (cell.x < 0.0 || cell.y < 0.0 || cell.x >= grid.x || cell.y >= grid.y) {
		return vec4(0.0);
	}
	vec2 home = tr_world((cell + 0.5) / grid);
	vec2 half_size = vec2(tr_ratio(), 1.0) / grid * 0.5;
	float k = tile_order(cell, grid);
	float u = clamp((p - (1.0 - flip_time) * k) / flip_time, 0.0, 1.0);
	float a = TR_PI * u * u * (3.0 - 2.0 * u);
	float scale = 1.0 - gap * sin(TR_PI * u);
	mat3 m = turn_m(a);
	vec3 n = m * vec3(0.0, 0.0, -1.0);
	float dn = dot(rd, n);
	if (abs(dn) < 0.000001) {
		return vec4(0.0);
	}
	vec3 c = vec3(home, 0.0);
	float t = dot(c - ro, n) / dn;
	vec3 q = transpose(m) * (ro + rd * t - c) / scale;
	if (t <= 0.0 || abs(q.x) > half_size.x || abs(q.y) > half_size.y) {
		return vec4(0.0);
	}
	dist = t;
	bool front = dn < 0.0;
	vec2 lq = q.xy;
	if (!front) {
		if (axis == 1) {
			lq.y = -lq.y;
		} else {
			lq.x = -lq.x;
		}
	}
	vec2 cuv = tr_frame_uv(home + lq);
	vec4 col = front ? texture(from_tex, cuv) : texture(to_tex, cuv);
	return tr_shade(col, mix(1.0, abs(n.z), shading));
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float cols = float(columns);
	float rows = max(1.0, floor(cols / tr_ratio() + 0.5));
	vec2 grid = vec2(cols, rows);
	vec2 cell = clamp(floor(uv * grid), vec2(0.0), grid - 1.0);
	float d = tr_camera_distance(lens);
	vec3 ro = vec3(0.0, 0.0, -d);
	vec3 rd = normalize(vec3(tr_world(uv), 0.0) - ro);
	vec2 step_dir = axis == 1 ? vec2(0.0, 1.0) : vec2(1.0, 0.0);
	vec4 bg = vec4(background.rgb * background.a, background.a);
	float best = 1000000.0;
	vec4 res = bg;
	for (int i = -1; i <= 1; i++) {
		float dist;
		vec4 c = tile(ro, rd, cell + step_dir * float(i), grid, p, dist);
		if (dist > 0.0 && dist < best) {
			best = dist;
			res = tr_over(c, bg);
		}
	}
	res = mix(res, from_at(uv), 1.0 - smoothstep(0.0, 0.03, progress));
	return mix(res, to_at(uv), smoothstep(0.97, 1.0, progress));
}

void fragment() {
	COLOR = transition(UV);
}
