shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int rows : hint_range(2, 60) = 16;
uniform int direction = 0;
uniform float stagger : hint_range(0.0, 0.9) = 0.5;
uniform float pull_back : hint_range(0.0, 1.5) = 0.5;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform float shading : hint_range(0.0, 1.0) = 0.6;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

vec4 strip(vec3 ro, vec3 rd, float r, float n_rows, float p, float back, out float dist) {
	dist = -1.0;
	if (r < 0.0 || r >= n_rows) {
		return vec4(0.0);
	}
	float h = 1.0 / n_rows;
	float yc = 0.5 - (r + 0.5) * h;
	float k = direction == 0 ? r / max(n_rows - 1.0, 1.0) : 1.0 - r / max(n_rows - 1.0, 1.0);
	float u = clamp((p - stagger * k) / (1.0 - stagger), 0.0, 1.0);
	float a = TR_PI * u * u * (3.0 - 2.0 * u);
	float c = cos(a);
	float s = sin(a);
	mat3 m = mat3(vec3(c, 0.0, s), vec3(0.0, 1.0, 0.0), vec3(-s, 0.0, c));
	vec3 n = m * vec3(0.0, 0.0, -1.0);
	float dn = dot(rd, n);
	if (abs(dn) < 0.000001) {
		return vec4(0.0);
	}
	vec3 centre = vec3(0.0, yc, back);
	float t = dot(centre - ro, n) / dn;
	vec3 q = transpose(m) * (ro + rd * t - centre);
	float hw = tr_ratio() * 0.5;
	if (t <= 0.0 || abs(q.x) > hw || abs(q.y) > h * 0.5) {
		return vec4(0.0);
	}
	dist = t;
	bool front = dn < 0.0;
	vec2 cuv = tr_frame_uv(vec2(front ? q.x : -q.x, yc + q.y));
	vec4 col = front ? texture(from_tex, cuv) : texture(to_tex, cuv);
	return tr_shade(col, mix(1.0, abs(n.z), shading));
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	float n_rows = float(rows);
	float back = pull_back * sin(TR_PI * tr_ease(p, 3));
	float d = tr_camera_distance(lens);
	vec3 ro = vec3(0.0, 0.0, -d);
	vec2 w = tr_world(uv);
	vec3 rd = normalize(vec3(w, 0.0) - ro);
	float yw = w.y * (d + back) / d;
	float r0 = floor((0.5 - yw) * n_rows);
	vec4 bg = vec4(background.rgb * background.a, background.a);
	vec4 res = bg;
	float best = 1000000.0;
	for (int i = -3; i <= 3; i++) {
		float dist;
		vec4 c = strip(ro, rd, r0 + float(i), n_rows, p, back, dist);
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
