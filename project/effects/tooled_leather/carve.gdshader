shader_type canvas_item;
render_mode blend_disabled;

uniform int hide = 0;
uniform int layers : hint_range(2, 5) = 3;
uniform float contrast : hint_range(0.5, 2.5) = 1.2;
uniform float bevel : hint_range(1.0, 24.0) = 7.0;
uniform float depth : hint_range(0.0, 1.0) = 0.7;
uniform float antique : hint_range(0.0, 1.0) = 0.65;
uniform float stamp : hint_range(0.0, 1.0) = 0.7;
uniform float light_angle : hint_range(-180.0, 180.0) = -135.0;
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

float tone(sampler2D tex, vec2 uv) {
	vec4 c = texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
	float l = dot(c.rgb / max(c.a, 0.0001), vec3(0.2126, 0.7152, 0.0722));
	l = clamp((l - 0.5) * contrast + 0.5, 0.0, 1.0);
	return l * float(layers) * 0.999;
}

float pebble(vec2 p, vec2 so) {
	vec2 g = p / 3.2;
	vec2 gi = floor(g);
	float d1 = 9.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = gi + vec2(float(x), float(y));
			vec2 s = o + 0.2 + 0.6 * h22(o + so);
			d1 = min(d1, distance(g, s));
		}
	}
	return d1;
}

float height_at(sampler2D tex, vec2 uv, vec2 to_uv, vec2 p, vec2 so, out float cut, out int lev) {
	float t = tone(tex, uv);
	float tx = tone(tex, uv + vec2(to_uv.x, 0.0));
	float ty = tone(tex, uv + vec2(0.0, to_uv.y));
	float g = max(length(vec2(tx - t, ty - t)), 0.0005);
	float k = floor(t);
	lev = int(k);
	float f = t - k;
	float d_up = (1.0 - f) / g;
	float d_down = f / g;
	float bw = max(bevel, 0.5);
	float dip = (1.0 - smoothstep(0.0, bw, d_up)) * (k < float(layers) - 1.0 ? 1.0 : 0.0);
	float h = k / float(max(layers - 1, 1));
	h -= dip * 0.75 / float(max(layers - 1, 1));
	float edge_round = (1.0 - smoothstep(0.0, 1.8, d_down)) * (k > 0.0 ? 1.0 : 0.0);
	h -= edge_round * 0.08 / float(max(layers - 1, 1));
	cut = (1.0 - smoothstep(0.6, 1.8, d_down)) * step(0.5, k);
	if (lev == 0) {
		h -= stamp * 0.05 * smoothstep(0.15, 0.55, pebble(p, so));
	}
	return h;
}

void fragment() {
	vec4 base = texture(effect_tex, UV);
	vec2 out_size = max(1.0 / max(fwidth(UV), vec2(0.000001)), vec2(1.0));
	float ps = max(px_scale * out_size.x / max(tex_size.x, 1.0), 0.0001);
	vec2 p = UV * out_size / ps;
	vec2 to_uv = ps / out_size;
	vec2 so = vec2(float(seed) * 2.03, float(seed) * 5.17);
	float cut = 0.0;
	float cx = 0.0;
	float cy = 0.0;
	int lev = 0;
	int lx = 0;
	float h = height_at(TEXTURE, UV, to_uv, p, so, cut, lev);
	float hx = height_at(TEXTURE, UV + vec2(to_uv.x, 0.0), to_uv, p + vec2(1.0, 0.0), so, cx, lx);
	float hy = height_at(TEXTURE, UV + vec2(0.0, to_uv.y), to_uv, p + vec2(0.0, 1.0), so, cy, lx);
	float relief = depth * 70.0;
	vec3 N = normalize(vec3(-(hx - h) * relief, -(hy - h) * relief, 1.0));
	float grainn = vnoise(p * 0.9 + so) * 0.5 + vnoise(p * 0.31 + so) * 0.5;
	float crease = smoothstep(0.62, 0.7, vnoise(p * 0.11 + so * 1.4) + vnoise(p * 0.37 + so) * 0.3);
	N = normalize(N + vec3(vec2(vnoise(p * 0.7 + so) - 0.5, vnoise(p * 0.7 + so + 9.0) - 0.5) * 0.25, 0.0));
	float la = radians(light_angle);
	vec3 L = normalize(vec3(cos(la), sin(la), 1.0));
	float diff = clamp(dot(N, L), 0.0, 1.0);
	vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
	float spec = pow(clamp(dot(N, H), 0.0, 1.0), 24.0);
	vec3 skin;
	vec3 stain;
	if (hide == 1) {
		skin = vec3(0.5, 0.3, 0.17);
		stain = vec3(0.16, 0.08, 0.04);
	} else if (hide == 2) {
		skin = vec3(0.42, 0.13, 0.1);
		stain = vec3(0.12, 0.03, 0.03);
	} else if (hide == 3) {
		skin = vec3(0.17, 0.15, 0.14);
		stain = vec3(0.04, 0.035, 0.03);
	} else {
		skin = vec3(0.8, 0.58, 0.37);
		stain = vec3(0.3, 0.16, 0.07);
	}
	float lf = float(lev) / float(max(layers - 1, 1));
	float bg = lev == 0 ? 1.0 : 0.0;
	float bevel_dark = clamp((lf - h) * float(max(layers - 1, 1)) * 2.5, 0.0, 1.0);
	float recess = clamp(bg * 0.75 + bevel_dark * 0.8 + cut + crease * 0.12, 0.0, 1.0);
	float mottle = vnoise(p * 0.01 + so) * 0.6 + vnoise(p * 0.035 + so) * 0.4;
	vec3 col = skin * mix(0.8, 1.06, lf) * (0.86 + 0.24 * mottle);
	col = mix(col, stain, recess * antique * 0.85);
	col *= 0.9 + 0.12 * grainn;
	col *= 0.35 + 0.8 * diff;
	float slope = clamp(length(N.xy) * 2.0, 0.0, 1.0);
	col = mix(col, stain * 0.6, slope * antique * 0.35);
	col += vec3(1.0, 0.9, 0.75) * spec * 0.2 * (0.4 + lf);
	float pores = smoothstep(0.7, 0.9, vnoise(p * 1.3 + so * 2.0));
	col *= 1.0 - pores * 0.12;
	col = mix(col, stain * 0.35, cut * 0.9);
	COLOR = vec4(clamp(col, 0.0, 1.0) * base.a, base.a);
}
