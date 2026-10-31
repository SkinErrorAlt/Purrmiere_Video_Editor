shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D dist_tex : filter_nearest, repeat_disable;
uniform sampler2D sign_tex : filter_nearest, repeat_disable;
uniform sampler2D global_tex : filter_nearest, repeat_disable;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform int cut_style : hint_range(0, 2) = 0;
uniform float rough : hint_range(0.0, 1.0) = 0.6;
uniform float cut_scale : hint_range(4.0, 120.0) = 26.0;
uniform float grow : hint_range(-20.0, 20.0) = 0.0;
uniform float edge_width : hint_range(0.0, 40.0) = 8.0;
uniform vec4 paper_colour : source_color = vec4(0.97, 0.95, 0.9, 1.0);
uniform float fibre : hint_range(0.0, 1.0) = 0.5;
uniform float grain : hint_range(0.0, 1.0) = 0.3;
uniform float thickness : hint_range(0.0, 1.0) = 0.45;
uniform float lift : hint_range(0.0, 40.0) = 5.0;
uniform float lift_angle : hint_range(-180.0, 180.0) = 135.0;
uniform float shadow : hint_range(0.0, 1.0) = 0.5;
uniform float shadow_soft : hint_range(0.0, 40.0) = 7.0;
uniform int seed_mode : hint_range(0, 2) = 2;
uniform int seed : hint_range(0, 9999) = 0;

const float DMAX = 256.0;

float unpack16(vec2 p) {
	return (p.x + p.y / 255.0) * DMAX;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float snoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fibres(vec2 p) {
	float f = 0.0;
	for (int i = 0; i < 3; i++) {
		float a = float(i) * 2.1 + 0.4;
		vec2 r = vec2(cos(a) * p.x + sin(a) * p.y, -sin(a) * p.x + cos(a) * p.y);
		f += snoise(r * vec2(0.09, 0.95));
	}
	return f / 3.0;
}

float sig_at(vec2 uv) {
	vec2 s = texture(sign_tex, clamp(uv, vec2(0.0), vec2(1.0))).rg;
	return floor(s.r * 255.0 + 0.5) * 256.0 + floor(s.g * 255.0 + 0.5);
}

float node_v(vec2 nid, float spacing, vec4 geo, float gsig, float oct) {
	float extra = 0.0;
	if (seed_mode == 1) {
		extra = gsig;
	}
	if (seed_mode == 2) {
		extra = sig_at(nid * spacing / geo.xy);
	}
	float h = hash12(nid + vec2(oct * 13.77, oct * 29.31));
	return fract(h + hash12(vec2(extra + 0.5, float(seed) * 1.37 + oct * 11.13 + h * 311.0)));
}

float lat(vec2 p, float spacing, vec4 geo, float gsig, float oct) {
	float sp = max(spacing, 2.0 / geo.w);
	vec2 q = p / sp;
	vec2 i = floor(q);
	vec2 f = q - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = node_v(i, sp, geo, gsig, oct);
	float b = node_v(i + vec2(1.0, 0.0), sp, geo, gsig, oct);
	float c = node_v(i + vec2(0.0, 1.0), sp, geo, gsig, oct);
	float d = node_v(i + vec2(1.0, 1.0), sp, geo, gsig, oct);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 2.0 - 1.0;
}

float style_amp() {
	if (cut_style == 1) {
		return 0.3;
	}
	if (cut_style == 2) {
		return 0.62;
	}
	return 1.0;
}

float tear(vec2 p, vec4 geo, float gsig) {
	float w1 = 0.58;
	float w2 = 0.29;
	float w3 = 0.13;
	if (cut_style == 1) {
		w1 = 0.3;
		w2 = 0.32;
		w3 = 0.38;
	}
	if (cut_style == 2) {
		w1 = 0.26;
		w2 = 0.3;
		w3 = 0.44;
	}
	float cs = geo.z;
	float n = lat(p, cs, geo, gsig, 1.0) * w1;
	n += lat(p, cs * 0.41, geo, gsig, 2.0) * w2;
	n += lat(p, cs * 0.17, geo, gsig, 3.0) * w3;
	return n;
}

float edge_at(vec2 p, vec4 geo, float gsig) {
	float base = max(edge_width, 0.0);
	float fine = lat(p, geo.z * 0.26, geo, gsig, 7.0) * 0.78;
	fine += lat(p, geo.z * 0.12, geo, gsig, 8.0) * 0.22;
	return base * (1.0 + clamp(fibre, 0.0, 1.0) * 0.5 * fine);
}

float raw_s(vec2 uv, float ps) {
	vec4 d = texture(dist_tex, clamp(uv, vec2(0.0), vec2(1.0)));
	return (unpack16(d.ba) - unpack16(d.rg)) / ps;
}

float paper_at(vec2 uv, vec4 geo, float gsig) {
	vec2 p = uv * geo.xy;
	float s = raw_s(uv, geo.w) + grow;
	float amp = clamp(rough, 0.0, 1.0) * geo.z * 0.45 * style_amp();
	return s + tear(p, geo, gsig) * amp + edge_at(p, geo, gsig);
}

void fragment() {
	vec2 out_size = max(1.0 / max(fwidth(UV), vec2(0.000001)), vec2(1.0));
	float ps = max(px_scale * out_size.x / max(tex_size.x, 1.0), 0.0001);
	vec2 src = max(out_size / ps, vec2(1.0));
	float cs = max(cut_scale, 3.0 / ps);
	vec4 geo = vec4(src.x, src.y, cs, ps);
	float gsig = 0.0;
	if (seed_mode == 1) {
		vec2 g = texture(global_tex, vec2(0.5, 0.5)).rg;
		gsig = floor(g.r * 255.0 + 0.5) * 256.0 + floor(g.g * 255.0 + 0.5);
	}
	float aa = max(0.8 / ps, 0.0001);
	float pshape = paper_at(UV, geo, gsig);
	float pa = clamp(smoothstep(-aa, aa, pshape), 0.0, 1.0);
	vec4 sc = texture(effect_tex, UV);
	float a0 = clamp(sc.a, 0.0, 1.0);
	vec3 rgb0 = a0 > 0.0001 ? clamp(sc.rgb / a0, 0.0, 1.0) : vec3(0.0);
	vec2 step_uv = 1.0 / out_size;
	float sx = raw_s(UV + vec2(step_uv.x, 0.0), ps) - raw_s(UV - vec2(step_uv.x, 0.0), ps);
	float sy = raw_s(UV + vec2(0.0, step_uv.y), ps) - raw_s(UV - vec2(0.0, step_uv.y), ps);
	vec2 gv = vec2(sx, sy);
	vec2 outward = length(gv) > 0.00001 ? -normalize(gv) : vec2(0.0, 1.0);
	float la = radians(lift_angle);
	vec2 sdir = vec2(sin(la), -cos(la));
	float lit = dot(outward, -sdir);
	float ew_nom = max(edge_width, 1.0);
	float rim = 1.0 - smoothstep(0.0, ew_nom * 0.8, max(pshape, 0.0));
	float crease = 1.0 - smoothstep(0.0, ew_nom * 0.22, max(pshape, 0.0));
	float shade = 1.0 + clamp(thickness, 0.0, 1.0) * (0.6 * lit * rim - 0.3 * crease * crease);
	float gn = fibres(UV * src * 1.15 + float(seed) * 3.7 + 11.0);
	float gmul = 1.0 - clamp(grain, 0.0, 1.0) * 0.22 * (gn - 0.5) * 2.0;
	float sh_a = 0.0;
	if (shadow > 0.001) {
		vec2 off = sdir * max(lift, 0.0) / src;
		float ss = max(shadow_soft, 0.6);
		float sp = paper_at(UV - off, geo, gsig);
		sh_a = clamp(shadow, 0.0, 1.0) * 0.8 * smoothstep(-ss, ss, sp);
	}
	float ia = min(a0, pa);
	vec3 pap = clamp(paper_colour.rgb * shade * gmul, 0.0, 1.0);
	vec3 printed = clamp(rgb0 * mix(1.0, gmul, 0.7), 0.0, 1.0);
	vec3 pre = pap * max(pa - ia, 0.0) + printed * ia;
	float oa = clamp(pa + sh_a * (1.0 - pa), 0.0, 1.0);
	COLOR = clamp(vec4(pre, oa), 0.0, 1.0);
}
