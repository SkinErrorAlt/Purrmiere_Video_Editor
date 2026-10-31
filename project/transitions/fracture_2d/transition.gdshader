shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int pieces : hint_range(3, 12) = 7;
uniform vec2 impact = vec2(0.5, 0.5);
uniform float crack_time : hint_range(0.0, 0.5) = 0.3;
uniform int fall = 0;
uniform float spin : hint_range(0.0, 2.0) = 0.7;
uniform float stagger : hint_range(0.0, 1.0) = 0.5;
uniform float edge_light : hint_range(0.0, 1.0) = 0.6;
uniform float thickness : hint_range(0.0, 60.0) = 9.0;
uniform float refraction : hint_range(0.0, 1.0) = 0.6;
uniform float lens : hint_range(10.0, 90.0) = 40.0;

vec2 grid_size() {
	float cols = float(clamp(pieces, 3, 12));
	float rows = max(2.0, floor(cols / tr_ratio() + 0.5));
	return vec2(cols, rows);
}

vec2 site(vec2 ij, vec2 cell) {
	vec2 j = tr_hash2(ij + vec2(3.3, 7.1)) - 0.5;
	return vec2(-tr_ratio() * 0.5, -0.5) + (ij + 0.5 + j * 0.8) * cell;
}

mat3 axis_turn(vec3 axis, float a) {
	vec3 k = normalize(axis);
	float c = cos(a);
	float s = sin(a);
	float t = 1.0 - c;
	return mat3(
		vec3(t * k.x * k.x + c, t * k.x * k.y + s * k.z, t * k.x * k.z - s * k.y),
		vec3(t * k.x * k.y - s * k.z, t * k.y * k.y + c, t * k.y * k.z + s * k.x),
		vec3(t * k.x * k.z + s * k.y, t * k.y * k.z - s * k.x, t * k.z * k.z + c));
}

vec3 glass_tint() {
	return vec3(0.8, 1.0, 0.88);
}

vec4 behind_split(vec2 w, vec2 shift, float spread) {
	vec4 g = to_mirrored(tr_frame_uv(w + shift));
	vec4 r = to_mirrored(tr_frame_uv(w + shift * (1.0 + spread)));
	vec4 b = to_mirrored(tr_frame_uv(w + shift * (1.0 - spread)));
	return vec4(r.r, g.g, b.b, g.a);
}

vec4 sample_split(vec2 w, vec2 shift, float spread) {
	vec4 g = from_mirrored(tr_frame_uv(w + shift));
	vec4 r = from_mirrored(tr_frame_uv(w + shift * (1.0 + spread)));
	vec4 b = from_mirrored(tr_frame_uv(w + shift * (1.0 - spread)));
	return vec4(r.r, g.g, b.b, g.a);
}

vec4 transition(vec2 uv) {
	float p = progress;
	float leak = clamp(min(p, 1.0 - p) * 8.0, 0.0, 1.0);
	vec4 under = to_at(uv);
	vec2 w = tr_world(uv);
	vec2 g = grid_size();
	vec2 cell = vec2(tr_ratio(), 1.0) / g;
	vec2 half_frame = vec2(tr_ratio() * 0.5, 0.5);
	vec2 hit_w = tr_world(impact);
	float reach = length(abs(hit_w) + half_frame);
	float max_delay = 0.25 * stagger;
	float span = max(1.0 - crack_time - 0.04 - max_delay, 0.2);
	float px_world = px_scale / max(frame_px.y, 1.0);
	float crack_w = max(1.4 * px_world, 1.1 / max(frame_px.y, 1.0));
	float crack_r = reach * 1.05 * pow(clamp(p / max(crack_time, 0.001), 0.0, 1.0), 0.8);
	float th = thickness * px_world;
	float bound = length(cell) * 0.95 + th;
	float d = tr_camera_distance(lens);
	vec3 cam = vec3(0.0, 0.0, -d);
	vec3 dir = normalize(vec3(w, d));
	vec3 light = normalize(vec3(-0.45, 0.6, -0.65));
	float bevel_w = max(th * 0.35, 1.5 * px_world);
	vec4 top_c = vec4(0.0);
	float top_v = 0.0;
	float top_t = 1e9;
	vec4 und_c = vec4(0.0);
	float und_v = 0.0;
	float und_t = 1e9;
	for (int j = 0; j < 12; j++) {
		if (float(j) >= g.y) {
			break;
		}
		for (int i = 0; i < 12; i++) {
			if (float(i) >= g.x) {
				break;
			}
			vec2 ij = vec2(float(i), float(j));
			vec2 s = site(ij, cell);
			vec2 dv = s - hit_w;
			float dl = length(dv);
			vec2 away = dl > 0.0001 ? dv / dl : vec2(0.0, 1.0);
			vec3 rnd = vec3(tr_hash2(ij + vec2(9.1, 4.7)), tr_hash(ij + vec2(1.3, 8.2)));
			float arrive = crack_time * pow(clamp(dl / (reach * 1.05), 0.0, 1.0), 1.25);
			float delay = max_delay * rnd.x;
			float u = clamp((p - arrive - 0.04 - delay) / span, 0.0, 1.0);
			vec3 move;
			float turn;
			if (fall == 1) {
				move = vec3(away * 0.6 * u + vec2(0.0, -0.3 * u * u), -d * 1.4 * u);
				turn = spin * TR_PI * (0.4 + 0.6 * rnd.y) * u;
			} else if (fall == 2) {
				move = vec3(away * (1.6 + 0.6 * rnd.y) * u, (rnd.z - 0.5) * 1.2 * u);
				move.y -= 0.6 * u * u;
				turn = spin * 2.0 * TR_PI * (0.5 + 0.5 * rnd.y) * u;
			} else {
				move = vec3(away * 0.25 * u + vec2(0.0, -1.9 * u * u), 0.9 * u);
				turn = spin * 1.5 * TR_PI * (0.5 + 0.5 * rnd.y) * u;
			}
			vec3 centre = vec3(s, th * 0.5);
			vec3 wc = centre + move;
			if (wc.z + d < 0.05) {
				continue;
			}
			vec2 proj = wc.xy * d / (wc.z + d);
			float rad = bound * d / (wc.z + d);
			if (length(proj - w) > rad) {
				continue;
			}
			mat3 rot = axis_turn(vec3(rnd.y - 0.5, rnd.z - 0.5, (rnd.x - 0.5) * 0.6) + vec3(0.0001, 0.0, 0.0), turn);
			mat3 inv = transpose(rot);
			vec3 o = centre + inv * (cam - wc);
			vec3 dl3 = inv * dir;
			float t_in = 0.0;
			float t_out = 1e9;
			vec3 n_in = vec3(0.0, 0.0, -1.0);
			int face = 0;
			float nd = -dl3.z;
			float dist = o.z;
			if (abs(nd) < 1e-6) {
				if (dist < 0.0) {
					continue;
				}
			} else if (nd < 0.0) {
				float t = dist / nd;
				if (t > t_in) {
					t_in = t;
					n_in = vec3(0.0, 0.0, -1.0);
					face = 0;
				}
			} else {
				t_out = min(t_out, dist / nd);
			}
			nd = dl3.z;
			dist = th - o.z;
			if (abs(nd) < 1e-6) {
				if (dist < 0.0) {
					continue;
				}
			} else if (nd < 0.0) {
				float t = dist / nd;
				if (t > t_in) {
					t_in = t;
					n_in = vec3(0.0, 0.0, 1.0);
					face = 1;
				}
			} else {
				t_out = min(t_out, dist / nd);
			}
			bool ok = true;
			for (int k = 0; k < 12; k++) {
				vec3 n;
				float c;
				if (k < 8) {
					int kk = k < 4 ? k : k + 1;
					vec2 nij = ij + vec2(float(kk % 3 - 1), float(kk / 3 - 1));
					if (nij.x < 0.0 || nij.y < 0.0 || nij.x >= g.x || nij.y >= g.y) {
						continue;
					}
					vec2 sn = site(nij, cell);
					n = vec3(sn - s, 0.0);
					c = (dot(sn, sn) - dot(s, s)) * 0.5;
				} else if (k == 8) {
					n = vec3(1.0, 0.0, 0.0);
					c = half_frame.x;
				} else if (k == 9) {
					n = vec3(-1.0, 0.0, 0.0);
					c = half_frame.x;
				} else if (k == 10) {
					n = vec3(0.0, 1.0, 0.0);
					c = 0.5;
				} else {
					n = vec3(0.0, -1.0, 0.0);
					c = 0.5;
				}
				nd = dot(n, dl3);
				dist = c - dot(n, o);
				if (abs(nd) < 1e-7) {
					if (dist < 0.0) {
						ok = false;
					}
				} else if (nd < 0.0) {
					float t = dist / nd;
					if (t > t_in) {
						t_in = t;
						n_in = normalize(n);
						face = 2;
					}
				} else {
					t_out = min(t_out, dist / nd);
				}
			}
			if (!ok || t_in > t_out || t_in <= 0.0 || (t_in >= top_t && t_in >= und_t)) {
				continue;
			}
			vec3 hp = o + dl3 * t_in;
			float edge = 1000.0;
			vec2 edge_n = vec2(0.0);
			for (int k = 0; k < 8; k++) {
				int kk = k < 4 ? k : k + 1;
				vec2 nij = ij + vec2(float(kk % 3 - 1), float(kk / 3 - 1));
				if (nij.x < 0.0 || nij.y < 0.0 || nij.x >= g.x || nij.y >= g.y) {
					continue;
				}
				vec2 sn = site(nij, cell);
				vec2 n2 = sn - s;
				float e = ((dot(sn, sn) - dot(s, s)) * 0.5 - dot(n2, hp.xy)) / length(n2);
				if (e < edge) {
					edge = e;
					edge_n = n2 / length(n2);
				}
			}
			float moving = smoothstep(0.0, 0.08, u);
			vec4 col;
			vec3 n_world;
			if (face == 2) {
				vec2 shift = n_in.xy * refraction * 0.05 * moving;
				vec4 own = sample_split(hp.xy, shift, 0.6 * refraction);
				vec4 through = behind_split(w, -shift * 1.5, 0.8 * refraction);
				col = mix(own, through, 0.3 * refraction);
				col.rgb *= glass_tint();
				n_world = rot * n_in;
			} else {
				float b = face == 0 ? 1.0 - smoothstep(0.0, bevel_w, edge) : 0.0;
				b *= moving;
				vec3 nl = normalize(mix(n_in, vec3(edge_n, 0.0), b * 0.7));
				n_world = rot * nl;
				vec2 shift = edge_n * refraction * 0.02 * b;
				col = b > 0.0 ? sample_split(hp.xy, shift, 0.6 * refraction) : from_at(tr_frame_uv(hp.xy));
				if (b > 0.0) {
					col.rgb = mix(col.rgb, col.rgb * glass_tint(), b);
				}
				if (face == 0) {
					float reached = 1.0 - smoothstep(crack_r - crack_w * 4.0, crack_r, length(hp.xy - hit_w));
					float fresh = (1.0 - moving) * reached;
					float glint = (1.0 - smoothstep(0.0, crack_w, edge)) * fresh;
					float shade_band = smoothstep(crack_w * 0.6, crack_w * 1.6, edge) * (1.0 - smoothstep(crack_w * 1.6, crack_w * 3.2, edge)) * fresh;
					col = tr_shade(col, 1.0 - 0.18 * shade_band);
					col.rgb = mix(col.rgb, col.rgb * glass_tint() + vec3(0.5) * col.a, glint * glint * (3.0 - 2.0 * glint));
				}
			}
			vec3 view = normalize(-dir);
			float diff = max(dot(n_world, light), 0.0);
			float spec = pow(max(dot(n_world, normalize(light + view)), 0.0), 36.0);
			float lit = face == 1 ? 0.55 + 0.25 * diff : 0.72 + 0.32 * diff;
			col = tr_shade(col, mix(1.0, lit, moving));
			float glow = face == 2 ? 0.2 + 1.0 * spec : spec * 0.6;
			if (face == 0) {
				float b2 = (1.0 - smoothstep(0.0, bevel_w, edge)) * moving;
				glow = spec * 0.35 + b2 * (0.35 + 1.6 * spec);
			}
			if (face != 2) {
				vec4 through = behind_split(w, n_world.xy * refraction * 0.03, 0.6 * refraction);
				col = mix(col, vec4(through.rgb * glass_tint(), through.a), 0.1 * refraction * moving);
				float fres = pow(1.0 - abs(dot(n_world, view)), 3.0);
				glow += fres * 0.5;
			}
			col.rgb += vec3(glow * edge_light * moving) * col.a;
			float cv = fall == 1 ? 1.0 - smoothstep(0.5, 1.0, u) : 1.0 - smoothstep(0.85, 1.0, u);
			if (t_in < top_t) {
				und_c = top_c;
				und_v = top_v;
				und_t = top_t;
				top_c = col;
				top_v = cv;
				top_t = t_in;
			} else {
				und_c = col;
				und_v = cv;
				und_t = t_in;
			}
		}
	}
	float cov = top_v + und_v * (1.0 - top_v);
	vec4 weighted = top_c * top_v + und_c * und_v * (1.0 - top_v);
	return weighted + under * (1.0 - cov + max(cov - weighted.a, 0.0) * leak);
}

void fragment() {
	COLOR = transition(UV);
}
