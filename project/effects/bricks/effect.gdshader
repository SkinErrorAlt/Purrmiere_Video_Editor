shader_type canvas_item;
render_mode blend_disabled;

uniform int pattern : hint_range(0, 3) = 0;
uniform float size : hint_range(8.0, 1000.0) = 150.0;
uniform float mortar : hint_range(0.0, 60.0) = 7.0;
uniform vec4 brick_colour : source_color = vec4(0.58, 0.26, 0.17, 1.0);
uniform float variety : hint_range(0.0, 1.0) = 0.5;
uniform vec4 mortar_colour : source_color = vec4(0.66, 0.63, 0.58, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float light_angle : hint_range(-180.0, 180.0) = -130.0;
uniform float wear : hint_range(0.0, 1.0) = 0.3;
uniform int placement : hint_range(0, 2) = 2;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

vec4 h42(vec2 p) {
	vec4 q = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	q += dot(q, q.wzxy + 33.33);
	return fract((q.xxyz + q.yzzw) * q.zywx);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p, int oct) {
	float s = 0.0;
	float a = 0.5;
	float n = 0.0;
	for (int i = 0; i < 6; i++) {
		if (i >= oct) {
			break;
		}
		s += a * vnoise(p);
		n += a;
		p = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * p * 2.07 + vec2(11.3, 4.7);
		a *= 0.5;
	}
	return s / n;
}

void brick_at(vec2 p, float ps, out vec3 id, out vec2 dims, out vec2 local) {
	float len = max(size * ps, 4.0);
	float m = mortar * ps * (pattern == 3 ? 0.5 : 1.0);
	if (pattern == 2) {
		float s = len * 0.5;
		vec2 u = p / s;
		float n = floor(u.y);
		float xs = u.x - n;
		float k = floor(xs / 4.0);
		float r = xs - 4.0 * k;
		if (r < 2.0) {
			id = vec3(k, n, 0.0);
			dims = vec2(2.0 * s, s);
			local = vec2(r * s, fract(u.y) * s);
		} else if (r < 3.0) {
			id = vec3(k, n, 1.0);
			dims = vec2(s, 2.0 * s);
			local = vec2((r - 2.0) * s, (fract(u.y) + 1.0) * s);
		} else {
			id = vec3(k, n + 1.0, 1.0);
			dims = vec2(s, 2.0 * s);
			local = vec2((r - 3.0) * s, fract(u.y) * s);
		}
		return;
	}
	float h = len * (pattern == 3 ? 0.5 : 0.32);
	float row = floor(p.y / h);
	float shift = (pattern == 1) ? 0.0 : mod(row, 2.0) * 0.5 * len;
	float col = floor((p.x + shift) / len);
	id = vec3(col, row, 0.0);
	dims = vec2(len, h);
	local = vec2(p.x + shift - col * len, p.y - row * h);
}

float shade_class(vec3 id) {
	if (pattern == 2) {
		return h12(id.xy * 1.7 + id.z * 31.0 + float(seed));
	}
	float cls = mod(2.0 * id.x + id.y, 5.0);
	float j = h12(id.xy * 1.31 + float(seed) * 0.17);
	return (cls + 0.5 + (j - 0.5) * 0.6) / 5.0;
}

float height_at(vec2 p, float ps, out vec3 id, out float edge, out float is_brick) {
	vec2 dims;
	vec2 local;
	brick_at(p, ps, id, dims, local);
	float m = mortar * ps * (pattern == 3 ? 0.5 : 1.0);
	vec2 d2 = min(local, dims - local) - m * 0.5;
	float e = min(d2.x, d2.y);
	vec4 hb = h42(id.xy * 1.13 + id.z * 7.0 + float(seed) * 0.3);
	float rough = clamp(roughness, 0.0, 1.0);
	float wr = clamp(wear, 0.0, 1.0);
	float edge_n = fbm(p / (5.0 * ps) + hb.xy * 50.0, 3);
	e -= (edge_n - 0.35) * (pattern == 3 ? 0.4 + 1.5 * wr : 1.0 + 2.5 * rough + 5.0 * wr) * ps;
	vec2 corner = min(local, dims - local);
	float cn = h12(id.xy * 3.1 + floor(local / dims * 2.0) + float(seed));
	float chip = cn < (pattern == 3 ? 0.25 * wr : 0.12 + 0.4 * wr) ? (5.0 + 14.0 * wr) * ps * (0.5 + cn * 3.0) : 0.0;
	float cr = length(corner) * (0.75 + 0.6 * fbm(p / (3.0 * ps) + hb.wz * 13.0, 3));
	e = min(e, cr - m * 0.7 - chip);
	edge = e;
	float bev = (pattern == 3 ? 4.0 : 2.2) * ps;
	is_brick = step(0.0, e);
	float top = pattern == 3 ? sqrt(clamp(e / bev, 0.0, 1.0)) : smoothstep(0.0, bev, e);
	float grain = (fbm(p / (3.0 * ps) + hb.zw * 20.0, 4) - 0.5) * (pattern == 3 ? 0.02 : 0.1 * rough);
	float pits = pattern == 3 ? 0.0 : -smoothstep(0.8, 0.93, vnoise(p / (3.5 * ps) + hb.xy * 9.0)) * 0.2 * rough;
	float hb_h = 1.0 + top * 0.0 + grain + pits;
	float mortar_h = 0.35 - 0.2 * wr + (vnoise(p / (1.6 * ps)) - 0.5) * 0.12;
	return mix(mortar_h, mix(mortar_h, hb_h, top), is_brick);
}

void fragment() {
	vec4 pic = texture(TEXTURE, UV);
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 p = UV * sz + vec2(float(seed) * 37.0, float(seed) * 11.0);
	vec3 id;
	vec3 idx;
	float edge;
	float ed2;
	float isb;
	float ib2;
	float h0 = height_at(p, ps, id, edge, isb);
	float hx = height_at(p + vec2(ps, 0.0), ps, idx, ed2, ib2);
	float hy = height_at(p + vec2(0.0, ps), ps, idx, ed2, ib2);
	float depth = (pattern == 3 ? 3.0 : 4.5);
	vec3 n = normalize(vec3(-(hx - h0) * depth, -(hy - h0) * depth, 1.0));
	float la = radians(light_angle);
	vec3 L = normalize(vec3(cos(la) * 0.75, sin(la) * 0.75, 0.62));
	float diff = max(dot(n, L), 0.0);
	float flat_l = 0.62;
	float lit = 0.3 + 0.7 * diff / flat_l * 0.85;
	vec4 hb = h42(id.xy * 1.13 + id.z * 7.0 + float(seed) * 0.3);
	float var = clamp(variety, 0.0, 1.0) * (pattern == 3 ? 0.22 : 1.0);
	float cls = shade_class(id);
	vec3 bc = brick_colour.rgb;
	float val = 1.0 + (cls - 0.5) * 0.7 * var;
	vec3 hue_shift = mix(vec3(1.0), vec3(1.08, 0.92, 0.85), (hb.x - 0.5) * 2.0 * var);
	vec3 col = bc * val * hue_shift;
	float mott = fbm(p / (14.0 * ps) + hb.yz * 30.0, 4);
	col *= pattern == 3 ? 0.97 + 0.06 * mott : 0.82 + 0.36 * mott * (0.4 + 0.6 * var);
	if (pattern != 3) {
		vec2 dims;
		vec2 local;
		vec3 dummy;
		brick_at(p, ps, dummy, dims, local);
		float flash = hb.w < 0.35 * var ? (1.0 - smoothstep(0.0, 0.45, local.x / dims.x)) * 0.35 : 0.0;
		col *= 1.0 - flash;
		float spec = smoothstep(0.82, 0.95, vnoise(p / (1.2 * ps) + hb.xy * 17.0));
		col = mix(col, col * 0.55, spec * 0.5 * roughness);
		float sand = vnoise(p / (0.8 * ps) + hb.zw * 41.0);
		col *= 0.9 + 0.2 * sand;
		float grit = smoothstep(0.86, 0.97, vnoise(p / (1.1 * ps) + hb.xy * 23.0));
		col = mix(col, vec3(0.2, 0.17, 0.15), grit * 0.35);
		col = mix(col, vec3(0.85, 0.8, 0.7), smoothstep(0.9, 0.98, vnoise(p / (0.9 * ps) + 77.0)) * 0.3);
	}
	vec3 mc = mortar_colour.rgb * (0.85 + 0.3 * vnoise(p / (1.3 * ps) + 3.0)) * (0.9 + 0.2 * vnoise(p / (9.0 * ps)));
	float wr = clamp(wear, 0.0, 1.0);
	vec3 surf = mix(mc, col, isb);
	float grime = smoothstep(0.45, 0.85, fbm(p / (90.0 * ps) + 7.0, 5)) * wr;
	surf *= 1.0 - grime * 0.45;
	float salt = smoothstep(0.62, 0.85, fbm(p / (30.0 * ps) + 19.0, 5)) * wr * (1.0 - smoothstep(0.0, 10.0 * ps, edge)) * isb;
	surf = mix(surf, vec3(0.86, 0.85, 0.82), salt * 0.5);
	vec3 o = surf * lit;
	float ao = mix(0.55, 1.0, smoothstep(-2.0 * ps, 3.0 * ps, edge));
	o *= ao;
	if (pattern == 3) {
		vec3 hv = normalize(L + vec3(0.0, 0.0, 1.0));
		float sp = pow(max(dot(n, hv), 0.0), 60.0) * isb * smoothstep(0.0, 3.0 * ps, edge);
		vec2 dims3;
		vec2 local3;
		vec3 id3;
		brick_at(p, ps, id3, dims3, local3);
		float sheen = smoothstep(0.0, 1.0, 1.0 - abs(local3.x / dims3.x - 0.35 - 0.3 * h12(id3.xy)) * 2.2) * smoothstep(1.0, 0.2, local3.y / dims3.y);
		o += vec3(0.6) * sp + vec3(0.07) * sheen * isb;
	}
	o = clamp(o, 0.0, 1.0);
	if (placement == 0) {
		COLOR = vec4(pic.rgb + o * (1.0 - pic.a), 1.0);
	} else if (placement == 1) {
		vec3 base = pic.a > 0.0001 ? pic.rgb / pic.a : vec3(0.0);
		vec3 rel = o / max(dot(surf, vec3(0.3333)) * 0.9, 0.05);
		vec3 tex = clamp(mix(vec3(1.0), rel, 0.65) * mix(vec3(1.0), surf * 1.6, 0.25), 0.0, 2.0);
		COLOR = vec4(clamp(base * tex, 0.0, 1.0) * pic.a, pic.a);
	} else {
		COLOR = vec4(o, 1.0);
	}
}
