shader_type canvas_item;
render_mode blend_disabled;

uniform float tuft : hint_range(3.0, 30.0) = 7.0;
uniform int yarns : hint_range(2, 12) = 4;
uniform float saturation : hint_range(0.0, 2.0) = 1.15;
uniform float carve : hint_range(0.0, 1.0) = 0.75;
uniform float carve_width : hint_range(1.0, 20.0) = 5.0;
uniform float fuzz : hint_range(0.0, 1.0) = 0.55;
uniform float light_angle : hint_range(-180.0, 180.0) = -120.0;
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

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

vec3 yarn_of(sampler2D tex, vec2 uv) {
	vec4 s = texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
	vec3 c = s.rgb / max(s.a, 0.0001);
	vec3 h = rgb2hsv(clamp(c, 0.0, 1.0));
	float n = float(max(yarns, 2) - 1);
	h.x = floor(h.x * 12.0 + 0.5) / 12.0;
	h.y = clamp(floor(h.y * saturation * 3.0 + 0.35) / 3.0, 0.0, 1.0);
	h.z = (floor(h.z * n + 0.5) + 0.15) / (n + 0.3);
	return hsv2rgb(h);
}

void fragment() {
	vec4 base = texture(effect_tex, UV);
	vec2 out_size = max(1.0 / max(fwidth(UV), vec2(0.000001)), vec2(1.0));
	float ps = max(px_scale * out_size.x / max(tex_size.x, 1.0), 0.0001);
	vec2 p = UV * out_size / ps;
	vec2 to_uv = ps / out_size;
	vec2 so = vec2(float(seed) * 2.13, float(seed) * 4.77);
	float T = max(tuft, 2.0);
	float la = radians(light_angle);
	vec3 L = normalize(vec3(cos(la), sin(la), 0.8));
	vec2 g = p / T;
	vec2 gi = floor(g);
	float bestv = -1e9;
	vec3 col = vec3(0.0);
	float dome = 0.0;
	vec2 tid = vec2(0.0);
	vec2 qbest = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 id = gi + vec2(float(x), float(y));
			vec2 c = id + 0.15 + 0.7 * h22(id + so);
			vec2 q = (g - c) / 0.72;
			float r2 = dot(q, q);
			float v = 1.0 - r2 + h12(id + so + 3.0) * 0.35;
			if (v > bestv && r2 < 1.3) {
				bestv = v;
				dome = sqrt(max(1.0 - r2, 0.0));
				tid = id;
				qbest = q;
			}
		}
	}
	float hue_j = h12(tid + so + 7.0);
	vec2 stray = (h22(tid + so * 1.9) - 0.5) * T * 1.6 * fuzz;
	vec2 fib = (vec2(vnoise(p * 0.9 + so), vnoise(p * 0.9 + so + 17.0)) - 0.5) * T * 0.6 * fuzz;
	vec2 cuv = (tid + 0.5) * T * to_uv + (stray + fib) * to_uv;
	col = yarn_of(TEXTURE, cuv);
	float cw = max(carve_width, 0.5);
	vec3 c0 = yarn_of(TEXTURE, UV);
	float edge = 0.0;
	float lean = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		vec2 o = vec2(cos(a), sin(a));
		vec3 cn = yarn_of(TEXTURE, UV + o * cw * to_uv);
		float diff = step(0.02, distance(cn, c0));
		edge += diff;
		lean += diff * dot(o, -L.xy);
	}
	edge = clamp(edge / 3.0, 0.0, 1.0);
	vec3 Nn = normalize(vec3(qbest * 0.9, 1.0));
	float diffl = clamp(dot(Nn, L), 0.0, 1.0);
	float sw = atan(qbest.y, qbest.x) * 3.0 + length(qbest) * 9.0 + hue_j * 6.28;
	float fibre = 0.84 + 0.1 * sin(sw) + 0.18 * vnoise(p * 1.9 + so) * vnoise(p * 0.7 + so * 1.3);
	float tipl = pow(dome, 0.45);
	vec3 yarn = col * (0.94 + 0.12 * hue_j);
	float strands = 0.88 + 0.24 * vnoise(p * 2.6 + so) * vnoise(p * 1.3 - so);
	vec3 shade = yarn * (0.66 + 0.36 * diffl) * mix(0.8, 1.0, tipl) * fibre * strands;
	shade += yarn * 0.15 * smoothstep(0.6, 1.0, dome) * (0.5 + 0.5 * diffl);
	float groove = edge * carve;
	float rim = clamp(lean, -2.0, 2.0) * 0.08 * carve * edge;
	shade *= 1.0 - groove * 0.62;
	shade *= 1.0 + rim;
	float backing = vnoise(p * 0.5 + so) * 0.06;
	shade += backing * groove * col;
	COLOR = vec4(clamp(shade, 0.0, 1.0) * base.a, base.a);
}
