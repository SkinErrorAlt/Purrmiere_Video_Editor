shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"
uniform bool spread = false;
uniform float spine : hint_range(0.0, 1.0) = 0.45;
uniform int corner = 0;
uniform float radius : hint_range(0.02, 0.5) = 0.15;
uniform float back_fade : hint_range(0.0, 1.0) = 0.5;
uniform vec4 paper : source_color = vec4(0.95, 0.94, 0.9, 1.0);
uniform float shadow : hint_range(0.0, 1.0) = 0.5;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform float shading : hint_range(0.0, 1.0) = 0.6;
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

void curl_frame(out vec2 a, out vec2 d) {
	float hw = tr_ratio() * 0.5;
	if (corner == 4) {
		a = vec2(hw, 0.0);
		d = vec2(-1.0, 0.0);
	} else if (corner == 5) {
		a = vec2(-hw, 0.0);
		d = vec2(1.0, 0.0);
	} else {
		float sx = (corner == 0 || corner == 2) ? 1.0 : -1.0;
		float sy = corner < 2 ? -1.0 : 1.0;
		a = vec2(sx * hw, sy * 0.5);
		d = normalize(vec2(-sx, -sy * 0.45));
	}
}

float curl_reach(vec2 a, vec2 d) {
	float hw = tr_ratio() * 0.5;
	float m = max(dot(vec2(hw, 0.5) - a, d), dot(vec2(-hw, 0.5) - a, d));
	m = max(m, max(dot(vec2(hw, -0.5) - a, d), dot(vec2(-hw, -0.5) - a, d)));
	return m;
}

vec2 page_uv(vec2 a, vec2 d, float m, float n) {
	vec2 q = vec2(-d.y, d.x);
	vec2 p = a + d * m + q * n;
	return vec2(p.x / tr_ratio() + 0.5, 0.5 - p.y);
}

vec4 curl_cast(vec3 ro, vec3 rd, vec2 a, vec2 d, float cl, float phi, float r, float min_u, out float light, out float flat_x) {
	vec2 q = vec2(-d.y, d.x);
	float x0 = cl - dot(ro.xy - a, d);
	float dx = -dot(rd.xy, d);
	float n0 = dot(ro.xy - a, q);
	float dn = dot(rd.xy, q);
	float z0 = ro.z;
	float dz = rd.z;
	vec4 best = vec4(0.0, 0.0, 0.0, 1e9);
	light = 1.0;
	float lf = -z0 / dz;
	flat_x = x0 + dx * lf;
	if (flat_x <= 0.0) {
		vec2 u = page_uv(a, d, cl - flat_x, n0 + dn * lf);
		if (tr_inside(u) && u.x >= min_u) {
			best = vec4(u, 1.0, lf);
		}
	}
	float qa = dx * dx + dz * dz;
	float qb = 2.0 * (x0 * dx + (z0 + r) * dz);
	float qc = x0 * x0 + (z0 + r) * (z0 + r) - r * r;
	float disc = qb * qb - 4.0 * qa * qc;
	if (disc >= 0.0 && qa > 0.0000001) {
		float sq = sqrt(disc);
		for (int i = 0; i < 2; i++) {
			float l = (-qb + (i == 0 ? -sq : sq)) / (2.0 * qa);
			if (l > 0.0 && l < best.w) {
				float hx = x0 + dx * l;
				float hz = z0 + r + dz * l;
				float al = atan(hx, hz);
				if (al >= 0.0 && al <= phi) {
					vec2 u = page_uv(a, d, cl - r * al, n0 + dn * l);
					if (tr_inside(u) && u.x >= min_u) {
						float side = (dx * hx + dz * hz) > 0.0 ? 1.0 : -1.0;
						best = vec4(u, side, l);
						light = 0.35 + 0.65 * abs(cos(al));
					}
				}
			}
		}
	}
	vec2 sp = vec2(r * sin(phi), -r + r * cos(phi));
	vec2 tg = vec2(cos(phi), -sin(phi));
	float det = -dx * tg.y + tg.x * dz;
	if (abs(det) > 0.000001) {
		float l = ((sp.x - x0) * (-tg.y) + tg.x * (sp.y - z0)) / det;
		float u = (dx * (sp.y - z0) - dz * (sp.x - x0)) / det;
		if (u >= 0.0 && l > 0.0 && l < best.w) {
			vec2 pu = page_uv(a, d, cl - r * phi - u, n0 + dn * l);
			if (tr_inside(pu) && pu.x >= min_u) {
				vec2 fn = vec2(-sin(phi), -cos(phi));
				float side = dot(vec2(dx, dz), fn) < 0.0 ? 1.0 : -1.0;
				best = vec4(pu, side, l);
				light = 0.35 + 0.65 * abs(cos(phi));
			}
		}
	}
	if (best.w > 1e8) {
		best = vec4(0.0, 0.0, 0.0, -1.0);
	}
	return best;
}

vec4 sheet_colour(vec4 hit, float light, bool use_from) {
	if (hit.w < 0.0) {
		return vec4(0.0);
	}
	vec4 c = use_from ? texture(from_tex, hit.xy) : texture(to_tex, hit.xy);
	if (hit.z < 0.0) {
		c = mix(c, vec4(paper.rgb, 1.0) * c.a, back_fade);
	}
	return tr_shade(c, mix(1.0, light, shading));
}

vec4 spread_turn(vec2 uv) {
	float hw = tr_ratio() * 0.5;
	float x = clamp(progress / 0.9, 0.0, 1.0);
	float e = x * (2.0 - x);
	vec2 a = vec2(hw, -0.5);
	vec2 d = normalize(mix(normalize(vec2(-1.0, 0.45)), vec2(-1.0, 0.0), smoothstep(0.0, 1.0, e)));
	float reach_r = max(dot(vec2(0.0, 0.5) - a, d), dot(vec2(0.0, -0.5) - a, d));
	float cl = e * reach_r;
	float rr = radius * min(e * 1.5, 1.0) * (1.0 - e);
	float light;
	float fx;
	vec4 hit = curl_cast(cam_eye(), cam_dir(uv), a, d, cl, TR_PI, rr, 0.5, light, fx);
	vec4 top = vec4(0.0);
	if (hit.w > 0.0) {
		vec4 c = hit.z > 0.0 ? texture(from_tex, hit.xy) : texture(to_tex, vec2(1.0 - hit.x, hit.y));
		top = tr_shade(c, mix(1.0, light, shading));
	}
	float wend = 1.0 - smoothstep(0.75, 0.9, progress);
	float env = smoothstep(0.0, 0.1, progress) * (1.0 - smoothstep(0.55, 0.92, progress));
	bool right = uv.x >= 0.5;
	vec4 under = right ? to_at(uv) * clamp(progress * 25.0, 0.0, 1.0) : from_at(uv);
	float sh = 0.0;
	if (hit.w <= 0.0) {
		if (right) {
			sh = shadow * exp(-max(fx, 0.0) / (rr * 2.0 + 0.03)) * wend;
		} else {
			float edge_x = rr * TR_PI - cl;
			sh = fx < edge_x ? shadow * 0.8 * exp((fx - edge_x) / (rr * 1.5 + 0.02)) * wend : 0.0;
		}
	}
	float fold = spine * env * exp(-abs(uv.x - 0.5) * tr_ratio() / 0.035);
	under = tr_shade(under, (1.0 - sh) * (1.0 - fold));
	top = tr_shade(top, 1.0 - fold * 0.6);
	return tr_over(top, tr_over(under, bg_fill()));
}

vec4 transition(vec2 uv) {
	if (spread) {
		return spread_turn(uv);
	}
	vec2 a;
	vec2 d;
	curl_frame(a, d);
	float e = mix(progress, tr_ease(progress, 3), 0.6);
	float cl = e * (curl_reach(a, d) + radius * TR_PI * 0.5 + 0.08);
	float light;
	float fx;
	vec4 hit = curl_cast(cam_eye(), cam_dir(uv), a, d, cl, TR_PI, radius, 0.0, light, fx);
	vec4 top = sheet_colour(hit, light, true);
	float sh = hit.w > 0.0 ? 0.0 : shadow * exp(-max(fx, 0.0) / (radius * 2.0 + 0.03)) * clamp((1.0 - progress) * 12.0, 0.0, 1.0);
	vec4 under = tr_shade(to_at(uv), 1.0 - sh) * clamp(progress * 25.0, 0.0, 1.0);
	return tr_over(top, tr_over(under, bg_fill()));
}

void fragment() {
	COLOR = transition(UV);
}
