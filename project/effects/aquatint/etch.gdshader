shader_type canvas_item;
render_mode blend_disabled;

uniform int bites : hint_range(2, 8) = 5;
uniform float contrast : hint_range(0.5, 2.5) = 1.15;
uniform float grain : hint_range(1.0, 10.0) = 2.6;
uniform float lines : hint_range(0.0, 1.0) = 0.6;
uniform float plate_tone : hint_range(0.0, 1.0) = 0.45;
uniform float plate_mark : hint_range(0.0, 0.2) = 0.0;
uniform vec4 ink : source_color = vec4(0.17, 0.11, 0.08, 1.0);
uniform vec4 paper : source_color = vec4(0.95, 0.92, 0.85, 1.0);
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform sampler2D effect_tex : filter_linear, repeat_disable;

float h12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 h22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec2(5.3, 9.1);
		a *= 0.5;
	}
	return s;
}

float lum_at(sampler2D tex, vec2 uv) {
	vec4 c = texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
	float l = dot(c.rgb / max(c.a, 0.0001), vec3(0.2126, 0.7152, 0.0722));
	return clamp((l - 0.5) * contrast + 0.5, 0.0, 1.0);
}

float rosin(vec2 p, vec2 so) {
	vec2 g = p;
	vec2 gi = floor(g);
	float d1 = 9.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = gi + vec2(float(x), float(y));
			vec2 s = o + 0.1 + 0.8 * h22(o + so);
			float r = 0.75 + 0.5 * h12(o + so + 3.0);
			d1 = min(d1, distance(g, s) / r);
		}
	}
	return d1;
}

void fragment() {
	vec4 base = texture(effect_tex, UV);
	vec2 out_size = max(1.0 / max(fwidth(UV), vec2(0.000001)), vec2(1.0));
	float ps = max(px_scale * out_size.x / max(tex_size.x, 1.0), 0.0001);
	vec2 p = UV * out_size / ps;
	vec2 to_uv = ps / out_size;
	vec2 so = vec2(float(seed) * 1.73, float(seed) * 2.29);
	vec2 src = out_size / ps;
	vec2 wob = (vec2(fbm(p * 0.01 + so), fbm(p * 0.01 + so + 7.0)) - 0.5) * 10.0;
	float l = lum_at(TEXTURE, UV + wob * to_uv);
	float n = float(clamp(bites, 2, 8));
	float t = (1.0 - l) * n;
	float k = floor(t);
	float f = fract(t);
	float step_edge = smoothstep(0.88, 1.0, f) * 0.6;
	float depth = (k + step_edge) / n;
	float rd = rosin(p / max(grain, 0.5), so);
	float rd2 = rosin(p / max(grain * 2.3, 0.5) + 17.0, so + 4.0);
	float open = mix(1.35, 0.25, pow(depth, 0.8));
	float inked = smoothstep(open - 0.12, open + 0.12, rd * 0.8 + rd2 * 0.35);
	inked = mix(inked, 1.0, smoothstep(0.92, 1.0, depth));
	inked *= step(0.02, depth);
	float tone = inked * (0.55 + 0.45 * depth);
	float el = 0.0;
	if (lines > 0.0) {
		float lx = lum_at(TEXTURE, UV + vec2(1.5, 0.0) * to_uv) - lum_at(TEXTURE, UV - vec2(1.5, 0.0) * to_uv);
		float ly = lum_at(TEXTURE, UV + vec2(0.0, 1.5) * to_uv) - lum_at(TEXTURE, UV - vec2(0.0, 1.5) * to_uv);
		float g = length(vec2(lx, ly));
		float broken = smoothstep(0.25, 0.6, vnoise(p * 0.08 + so));
		el = smoothstep(0.12, 0.3, g) * lines * mix(0.55, 1.0, broken);
	}
	tone = max(tone, el);
	vec2 sp = UV - 0.5;
	float wipe_dir = fbm(vec2(dot(p, vec2(0.7, 0.7)) * 0.002, dot(p, vec2(-0.7, 0.7)) * 0.03) + so);
	float corners = smoothstep(0.2, 0.75, length(sp * vec2(1.0, 0.8)));
	float film = plate_tone * (0.08 + 0.1 * wipe_dir + 0.12 * corners);
	float inside = 1.0;
	float bevel = 0.0;
	if (plate_mark > 0.0) {
		vec2 m = vec2(plate_mark * src.y) ;
		vec2 dpx = min(p, src - p) - m;
		float dmin = min(dpx.x, dpx.y);
		inside = smoothstep(-0.5, 0.5, dmin);
		bevel = (1.0 - smoothstep(0.0, 5.0, abs(dmin))) * sign(dmin);
	}
	float amount = clamp((tone + film) * inside, 0.0, 1.0);
	float fib = vnoise(p * 0.35 + so) * 0.5 + vnoise(p * 0.09 + so) * 0.5;
	vec3 pap = paper.rgb * (0.95 + 0.08 * fib);
	float ink_var = 0.9 + 0.2 * vnoise(p * 0.03 + so);
	vec3 col = mix(pap, ink.rgb * ink_var, amount);
	float emb = 0.0;
	if (plate_mark > 0.0) {
		vec2 m2 = vec2(plate_mark * src.y);
		vec2 dpx2 = min(p, src - p) - m2;
		float dmin2 = min(dpx2.x, dpx2.y);
		float lit = (p.x < src.x * 0.5 ? 1.0 : -0.6) * step(dpx2.x, dpx2.y) + (p.y < src.y * 0.5 ? 0.8 : -0.8) * step(dpx2.y, dpx2.x);
		emb = (1.0 - smoothstep(0.0, 4.0, abs(dmin2))) * lit * 0.08;
		col *= 1.0 + emb;
		col *= mix(1.0, 0.97, inside);
	}
	COLOR = vec4(clamp(col, 0.0, 1.0) * base.a, base.a);
}
