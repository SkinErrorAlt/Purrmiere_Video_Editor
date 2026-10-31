shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"
uniform float strength : hint_range(0.0, 1.0) = 0.85;
uniform float ball_size : hint_range(0.1, 0.45) = 0.24;
uniform int toss = 0;
uniform float toss_speed : hint_range(0.25, 3.0) = 1.0;
uniform float shadow : hint_range(0.0, 1.0) = 0.75;
uniform float shading : hint_range(0.0, 1.0) = 0.85;
uniform float grain : hint_range(0.0, 1.0) = 0.4;
uniform float lens : hint_range(10.0, 90.0) = 40.0;
uniform vec4 background : source_color = vec4(0.0, 0.0, 0.0, 1.0);
const vec4 LP[14] = vec4[14](vec4(-0.6716, 0.7624, 0.1507, 0.9886), vec4(0.5045, -0.7430, 0.8338, 0.5521), vec4(0.2610, 0.8672, -0.2954, 0.9554), vec4(0.3752, -1.0184, 0.9937, 0.1118), vec4(-0.8045, -0.4476, 0.7425, 0.6699), vec4(-0.1835, 1.0488, -0.9999, 0.0135), vec4(0.8564, 0.2035, -0.1971, 0.9804), vec4(1.0790, -0.0193, 1.0000, 0.0017), vec4(-0.0480, 0.7686, 0.3167, 0.9485), vec4(0.4456, -0.3684, 0.9628, 0.2704), vec4(0.4129, -0.6112, 0.7151, 0.6990), vec4(-0.0561, -0.0211, -0.5413, 0.8408), vec4(0.7765, 0.4312, 0.2510, 0.9680), vec4(-0.1268, -0.4594, 0.6618, 0.7497));
const float LA[14] = float[14](-0.8993, -0.7563, 0.7387, -0.9078, -0.7030, 0.8941, -0.6378, -0.6734, -0.5183, 0.5831, -0.5253, -0.5471, 0.5959, 0.7427);
const vec4 PN[18] = vec4[18](vec4(0.3029, 0.1275, 0.9444, 0.7437), vec4(-0.3025, 0.4627, 0.8333, 0.9292), vec4(0.1164, -0.6818, 0.7222, 0.8496), vec4(0.6746, 0.4140, 0.6111, 0.7678), vec4(-0.8589, -0.1108, 0.5000, 0.7418), vec4(0.8179, -0.4240, 0.3889, 0.8978), vec4(-0.1640, 0.9465, 0.2778, 0.7541), vec4(-0.6442, -0.7464, 0.1667, 0.8610), vec4(0.9978, -0.0374, 0.0556, 0.8100), vec4(-0.9557, 0.2891, -0.0556, 0.7642), vec4(0.4792, -0.8617, -0.1667, 0.8981), vec4(0.5387, 0.7954, -0.2778, 0.8134), vec4(-0.7460, -0.5405, -0.3889, 0.7991), vec4(0.7858, -0.3639, -0.5000, 0.8560), vec4(-0.5640, 0.5554, -0.6111, 0.7701), vec4(-0.0178, -0.6914, -0.7222, 0.8452), vec4(0.3649, 0.4152, -0.8333, 0.8138), vec4(-0.3282, 0.0182, -0.9444, 0.7549));
const vec4 GN[8] = vec4[8](vec4(-0.7566, -0.6535, 0.0207, 0.3010), vec4(-0.5840, 0.7779, 0.2318, -0.3087), vec4(0.5780, 0.6425, -0.5031, -0.3459), vec4(-0.3947, 0.7495, -0.5316, 0.2533), vec4(-0.1685, -0.4773, -0.8624, -0.3064), vec4(-0.7451, -0.6607, -0.0907, -0.3162), vec4(0.2072, 0.9766, -0.0581, 0.3215), vec4(0.6809, -0.7044, 0.2004, 0.3464));

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

struct Wad {
	vec3 ctr;
	vec2 ext;
	float th;
	float rad;
	float morph;
	float crumple;
	float spin;
};

void sheet_fields(vec2 qn, float c, out float h, out vec2 off, out float ridge) {
	float hw = tr_ratio() * 0.5;
	float ang = seed * 2.39996;
	vec2 q = tr_rotate(qn, ang);
	h = 0.0;
	vec2 o = vec2(0.0);
	ridge = 0.0;
	for (int i = 0; i < 14; i++) {
		vec4 l = LP[i];
		vec2 pt = l.xy * vec2(hw, 0.5);
		float d = dot(q - pt, l.zw);
		float r = max(abs(l.x), abs(l.y));
		float start = (1.0 - min(r, 1.0)) * 0.4;
		float k = smoothstep(start, start + 0.5, c) * strength;
		float wd = (i < 8 ? 0.34 : 0.12) + 0.16 * fract(float(i) * 0.618);
		float ad = sqrt(d * d + 0.00002);
		float slope = LA[i] * k;
		h += slope * max(wd - ad, 0.0);
		float sec_m = sqrt(1.0 + slope * slope) - 1.0;
		o += l.zw * sign(d) * min(ad, wd) * sec_m;
		float sg = sign(LA[i]) * k;
		ridge += sg * exp(-ad / 0.004) - 0.6 * sg * exp(-abs(ad - wd) / 0.004);
	}
	h += c * strength * 0.02 * (sin(q.x * 3.7 + 1.0) * sin(q.y * 4.9 + 2.0) + 0.6 * sin(q.x * 6.3 + q.y * 2.9 + 0.5));
	off = tr_rotate(o, -ang);
}

float wad_facets(vec3 rc, float rad, out float crease, out float valley) {
	vec3 dir = normalize(rc + vec3(0.000001));
	float facets = length(rc) - rad;
	for (int k = 0; k < 18; k++) {
		facets = max(facets, dot(rc, PN[k].xyz) - rad * PN[k].w);
	}
	crease = 0.0;
	valley = 0.0;
	for (int j = 0; j < 8; j++) {
		float g = abs(dot(dir, GN[j].xyz));
		float tent = max(0.32 - g, 0.0);
		crease += GN[j].w * tent;
		valley = max(valley, (GN[j].w < 0.0 ? 1.0 : 0.3) * exp(-g / 0.012));
	}
	return facets;
}

float shape(vec3 p, Wad w) {
	float hw = tr_ratio() * 0.5;
	vec3 rel = p - w.ctr;
	rel.xy = tr_rotate(rel.xy, -w.spin);
	vec3 hs = mix(vec3(w.ext, w.th), vec3(w.rad), w.morph);
	vec2 sc = hs.xy / vec2(hw, 0.5);
	vec2 qn = rel.xy / sc;
	float h;
	vec2 off;
	float ridge;
	sheet_fields(qn, w.crumple, h, off, ridge);
	float flat_k = 1.0 - w.morph;
	vec2 mxy = (qn + off * flat_k) * sc;
	float zc = hs.z - h * flat_k * sc.y;
	vec3 bq = abs(vec3(mxy, rel.z - zc)) - hs;
	float d = length(max(bq, vec3(0.0))) + min(max(bq.x, max(bq.y, bq.z)), 0.0);
	vec3 rc = rel - vec3(0.0, 0.0, hs.z);
	float crease;
	float valley;
	float facets = wad_facets(rc, w.rad, crease, valley);
	d = max(d, facets - (1.0 - w.morph) * (length(hs) + 0.05) * 1.2);
	d -= w.morph * (crease * w.rad * 0.55 + h * sc.y * 0.3);
	return d;
}

vec3 shape_normal(vec3 p, Wad w) {
	float e = 0.0008;
	vec2 k = vec2(1.0, -1.0);
	return normalize(k.xyy * shape(p + k.xyy * e, w) + k.yyx * shape(p + k.yyx * e, w) + k.yxy * shape(p + k.yxy * e, w) + k.xxx * shape(p + k.xxx * e, w));
}

vec4 transition(vec2 uv) {
	float t = progress;
	float hw = tr_ratio() * 0.5;
	Wad w;
	w.crumple = smoothstep(0.0, 0.5, t);
	w.morph = smoothstep(0.34, 0.64, t);
	float tt = max(t - 0.62, 0.0) * toss_speed / 0.3;
	float sx = (toss == 1 || toss == 3) ? -1.0 : 1.0;
	if (toss == 4) {
		w.ctr = vec3(0.0, 0.25 * tt - 0.3 * tt * tt, 4.0 * tt);
	} else if (toss == 2 || toss == 3) {
		w.ctr = vec3(sx * 1.05 * tt, 1.1 * tt - 0.8 * tt * tt, 1.4 * tt);
	} else {
		w.ctr = vec3(sx * 1.1 * tt, 0.45 * tt - 1.5 * tt * tt, 1.2 * tt);
	}
	w.spin = sx * 2.2 * tt;
	w.ext = vec2(hw, 0.5) * mix(1.0, 0.9, w.crumple);
	w.th = 0.006;
	w.rad = ball_size;
	vec3 hs = mix(vec3(w.ext, w.th), vec3(w.rad), w.morph);
	vec3 ro = cam_eye();
	vec3 rd = cam_dir(uv);
	vec3 bc = w.ctr + vec3(0.0, 0.0, hs.z);
	float br = length(hs) + 1.4 * (1.0 - w.morph) * hs.y * w.crumple + w.rad * 0.4 * w.morph + 0.03;
	vec3 oc = ro - bc;
	float bb = dot(oc, rd);
	float disc = bb * bb - (dot(oc, oc) - br * br);
	float hit_t = -1.0;
	float dmin = 1e9;
	float tmin = 0.0;
	bool escaped = true;
	if (disc > 0.0) {
		escaped = false;
		float sq = sqrt(disc);
		float hmax = 1.4 * (1.0 - w.morph) * hs.y * w.crumple + w.rad * 0.4 * w.morph + 0.01;
		float front = (w.ctr.z - hmax - ro.z) / max(rd.z, 0.0001);
		float tr = max(max(-bb - sq, 0.0), w.morph > 0.5 ? 0.0 : front);
		float te = -bb + sq;
		for (int i = 0; i < 100; i++) {
			float d = shape(ro + rd * tr, w);
			if (d < dmin) {
				dmin = d;
				tmin = tr;
			}
			if (d < 0.00001) {
				hit_t = tr;
				break;
			}
			tr += d * 0.55;
			if (tr > te) {
				escaped = true;
				break;
			}
		}
		if (hit_t < 0.0 && !escaped && dmin < 0.01) {
			hit_t = tmin;
		}
	}
	float pix = 1.0 / frame_px.y;
	float cov = hit_t > 0.0 ? 1.0 : clamp(0.5 - dmin / max(pix * tmin / tr_camera_distance(lens), 0.000001), 0.0, 1.0);
	vec3 hp = ro + rd * (hit_t > 0.0 ? hit_t : tmin);
	vec3 rel = hp - w.ctr;
	rel.xy = tr_rotate(rel.xy, -w.spin);
	vec2 sc = hs.xy / vec2(hw, 0.5);
	vec2 qn = rel.xy / sc;
	float h;
	vec2 off;
	float ridge;
	sheet_fields(qn, w.crumple, h, off, ridge);
	vec2 m = qn + off * (1.0 - w.morph);
	vec3 rc = rel - vec3(0.0, 0.0, hs.z);
	float crease;
	float valley;
	float fd = wad_facets(rc, w.rad, crease, valley);
	m = m * mix(1.0, 0.8, w.morph);
	vec4 col = from_mirrored(tr_frame_uv(m));
	vec3 n = shape_normal(hp, w);
	vec3 ld = normalize(vec3(-0.5, 0.65, -0.6));
	float lam = max(dot(n, ld), 0.0);
	float lam0 = max(dot(vec3(0.0, 0.0, -1.0), ld), 0.0);
	float lit = (0.12 + 0.88 * lam) / (0.12 + 0.88 * lam0);
	float creased = clamp(w.crumple + w.morph, 0.0, 1.0);
	float line_light = 1.0 + 0.4 * clamp(ridge, -1.2, 1.2) * (1.0 - 0.6 * w.morph);
	float folds = 1.0 - 0.7 * valley * w.morph;
	float gr = 1.0 + grain * creased * 0.3 * (tr_noise(m * 230.0) + tr_noise(m * 75.0 + 5.0) - 1.0);
	float wl = clamp(creased * 6.0, 0.0, 1.0);
	col = tr_shade(col, mix(1.0, lit * line_light * folds, shading * wl));
	col.rgb = min(col.rgb, vec3(col.a));
	col = tr_shade(col, gr);
	float gone = 1.0 - smoothstep(0.92, 1.0, t);
	col *= cov * gone;
	vec4 under = to_at(uv) * clamp(t * 25.0, 0.0, 1.0);
	float cd = tr_camera_distance(lens);
	vec3 foot = vec3(w.ctr.x, -0.5, w.ctr.z + w.rad);
	float fsc = cd / (cd + foot.z);
	vec2 sp = tr_world(uv) - foot.xy * fsc;
	float lift = max(w.ctr.y - w.rad + 0.5, 0.0);
	vec2 ell = vec2(w.rad * (1.5 + 0.8 * lift), w.rad * (0.42 + 0.3 * lift)) * fsc;
	float s2 = dot(sp / ell, sp / ell);
	float dark = shadow * 0.85 * w.morph * gone * (1.0 - smoothstep(0.05, 1.0, s2)) / (1.0 + 1.2 * lift) * smoothstep(-0.15, 0.0, w.ctr.y - w.rad + 0.5);
	under = tr_shade(under, 1.0 - dark);
	return tr_over(col, tr_over(under, bg_fill()));
}

void fragment() {
	COLOR = transition(UV);
}
