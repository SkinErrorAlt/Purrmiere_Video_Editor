shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"
uniform int pieces : hint_range(3, 9) = 6;
uniform float spread : hint_range(0.0, 2.0) = 1.0;
uniform float spin : hint_range(0.0, 1.0) = 0.6;
uniform bool assemble = true;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform float shading : hint_range(0.0, 1.0) = 0.5;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);

vec3 cam_eye() {
	return vec3(0.0, 0.0, -tr_camera_distance(lens));
}

vec3 cam_dir(vec2 uv) {
	return normalize(vec3(tr_world(uv), 0.0) - cam_eye());
}

vec4 plane_cast(vec3 ro, vec3 rd, mat3 r, vec3 pos) {
	vec3 o = transpose(r) * (ro - pos);
	vec3 d = transpose(r) * rd;
	float t = abs(d.z) < 0.000001 ? -1.0 : -o.z / d.z;
	vec3 h = o + d * max(t, 0.0);
	return vec4(h.x / tr_ratio() + 0.5, 0.5 - h.y, d.z > 0.0 ? 1.0 : -1.0, t);
}

vec3 pivot_place(mat3 r, vec3 pivot, vec3 offset) {
	return pivot - r * pivot + offset;
}

float box_cover(vec4 hit, vec4 box) {
	vec2 fw = max(fwidth(hit.xy), vec2(0.00001));
	vec2 lo = (hit.xy - box.xy) / fw;
	vec2 hi = (box.zw - hit.xy) / fw;
	float c = clamp(min(min(lo.x, lo.y), min(hi.x, hi.y)) + 0.5, 0.0, 1.0);
	return hit.w > 0.0 ? c : 0.0;
}

float edge_cover(vec4 hit) {
	return box_cover(hit, vec4(0.0, 0.0, 1.0, 1.0));
}

float face_light(mat3 r) {
	return mix(1.0, abs((r * vec3(0.0, 0.0, -1.0)).z), shading);
}

vec4 bg_fill() {
	float w = clamp(min(progress, 1.0 - progress) * 25.0, 0.0, 1.0);
	return vec4(background.rgb * background.a, background.a) * w;
}

mat3 axis_rot(vec3 k, float a) {
	float c = cos(a);
	float s = sin(a);
	mat3 kx = mat3(vec3(0.0, k.z, -k.y), vec3(-k.z, 0.0, k.x), vec3(k.y, -k.x, 0.0));
	mat3 kk = mat3(k * k.x, k * k.y, k * k.z);
	return mat3(c) + kx * s + kk * (1.0 - c);
}

vec2 grid_size() {
	float cols = float(pieces);
	float rows = clamp(floor(cols / tr_ratio() + 0.5), 2.0, 9.0);
	return vec2(cols, rows);
}

vec2 seed_at(vec2 cell, vec2 grid, float salt) {
	vec2 cs = vec2(tr_ratio(), 1.0) / grid;
	vec2 lo = vec2(-tr_ratio() * 0.5, -0.5);
	vec2 h = tr_hash2(cell * 1.37 + vec2(salt * 5.3, salt * 2.9 + 1.0));
	return lo + (cell + 0.2 + 0.6 * h) * cs;
}

bool owns(vec2 q, vec2 cell, vec2 grid, float salt) {
	vec2 cs = vec2(tr_ratio(), 1.0) / grid;
	vec2 lo = vec2(-tr_ratio() * 0.5, -0.5);
	if (q.x < lo.x || q.y < lo.y || q.x > -lo.x || q.y > -lo.y) {
		return false;
	}
	vec2 qc = floor((q - lo) / cs);
	float best = 1e9;
	vec2 bc = vec2(-1.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 nc = qc + vec2(float(i), float(j));
			if (nc.x < 0.0 || nc.y < 0.0 || nc.x >= grid.x || nc.y >= grid.y) {
				continue;
			}
			float dd = distance(q, seed_at(nc, grid, salt));
			if (dd < best) {
				best = dd;
				bc = nc;
			}
		}
	}
	return all(equal(bc, cell));
}

void shard_pose(vec2 cell, vec2 centre, float salt, float a, bool incoming, out mat3 r, out vec3 t) {
	vec2 h = tr_hash2(cell * 2.71 + vec2(salt * 1.9 + 3.0, 4.2));
	vec2 g = tr_hash2(cell * 0.83 + vec2(7.7, salt * 3.1 + 2.0));
	vec3 axis = normalize(vec3(h.x - 0.5, h.y - 0.5, 0.4 * (g.x - 0.5)) + vec3(0.001, 0.002, 0.0));
	r = axis_rot(axis, spin * (2.5 + 4.0 * g.y) * a * (g.x < 0.5 ? -1.0 : 1.0));
	vec2 outward = (centre + (h - 0.5) * 0.3) * spread * (0.6 + 0.8 * g.y);
	if (incoming) {
		t = vec3(outward * 0.8 * a, -0.45 * spread * a * (0.5 + 0.5 * h.x));
	} else {
		t = vec3(outward * a, 1.6 * spread * a * (0.5 + 0.5 * h.y)) + vec3(0.0, -1.2 * a * a, 0.0);
	}
}

vec4 transition(vec2 uv) {
	vec2 grid = grid_size();
	float reach = 2.2 * max(tr_ratio() / grid.x, 1.0 / grid.y);
	vec3 ro = cam_eye();
	vec3 rd = cam_dir(uv);
	vec4 c1 = vec4(0.0);
	float d1 = 1e9;
	vec4 c2 = vec4(0.0);
	float d2 = 1e9;
	for (int k = 0; k < 2; k++) {
		bool incoming = k == 1;
		if (incoming && !assemble) {
			continue;
		}
		float salt = incoming ? 1.0 : 0.0;
		for (int j = 0; j < 9; j++) {
			if (float(j) >= grid.y) {
				break;
			}
			for (int i = 0; i < 9; i++) {
				if (float(i) >= grid.x) {
					break;
				}
				vec2 cell = vec2(float(i), float(j));
				float hh = tr_hash(cell * 3.17 + vec2(salt * 7.0, 1.3));
				float a;
				float alpha;
				if (incoming) {
					a = 1.0 - clamp((progress - 0.35 - 0.2 * hh) / 0.45, 0.0, 1.0);
					alpha = 1.0 - smoothstep(0.45, 1.0, a);
					a = a * a;
				} else {
					a = clamp((progress - 0.3 * hh) / 0.6, 0.0, 1.0);
					alpha = 1.0 - smoothstep(0.55, 1.0, a);
					a = a * (0.4 + 0.6 * a);
				}
				if (alpha <= 0.0) {
					continue;
				}
				vec2 centre = seed_at(cell, grid, salt);
				mat3 r;
				vec3 t;
				shard_pose(cell, centre, salt, a, incoming, r, t);
				vec3 c3 = vec3(centre, 0.0);
				vec3 o = transpose(r) * (ro - c3 - t) + c3;
				vec3 dd = transpose(r) * rd;
				if (abs(dd.z) < 0.000001) {
					continue;
				}
				float l = -o.z / dd.z;
				if (l <= 0.0 || l >= d2) {
					continue;
				}
				vec2 qp = (o + dd * l).xy;
				if (distance(qp, centre) > reach || !owns(qp, cell, grid, salt)) {
					continue;
				}
				vec2 tuv = tr_frame_uv(qp);
				vec4 col = incoming ? texture(to_tex, tuv) : texture(from_tex, tuv);
				float lt = mix(1.0, abs((r * vec3(0.0, 0.0, -1.0)).z), shading) * (dd.z > 0.0 ? 1.0 : 0.55);
				col = tr_shade(col, lt) * alpha;
				if (l < d1) {
					c2 = c1;
					d2 = d1;
					c1 = col;
					d1 = l;
				} else {
					c2 = col;
					d2 = l;
				}
			}
		}
	}
	vec4 under = assemble ? vec4(0.0) : to_at(uv) * clamp(progress * 25.0, 0.0, 1.0);
	return tr_over(c1, tr_over(c2, tr_over(under, bg_fill())));
}

void fragment() {
	COLOR = transition(UV);
}
