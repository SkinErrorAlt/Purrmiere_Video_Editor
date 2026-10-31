shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float brush_size : hint_range(2.0, 30.0) = 8.0;
uniform float definition : hint_range(0.0, 25.0) = 12.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 seed_offset(int s) {
	float f = float(s);
	return vec2(mod(f * 12.9898, 997.0), mod(f * 78.233, 991.0));
}

float pores(vec2 p) {
	vec2 b = floor(p);
	float best = 9.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 cell = b + vec2(float(x), float(y));
			vec2 h = hash22(cell);
			vec2 d = cell + h - p;
			best = min(best, length(d) * (0.75 + 0.5 * fract(h.x * 7.13 + h.y)));
		}
	}
	return best;
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float a = texture(effect_tex, UV).a;
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	vec2 so = seed_offset(seed);
	vec2 pix = UV * dims / ps + so;
	float cell = max(brush_size, 2.0);
	vec2 wob = vec2(value_noise(pix / (cell * 1.7)), value_noise(pix / (cell * 1.7) + 7.7)) * 0.9;
	float f1 = pores(pix / cell + wob);
	float f2 = pores(pix / (cell * 0.55) + wob * 1.6 + 17.3);
	float mott = value_noise(pix / (cell * 2.2)) * 0.6 + value_noise(pix / (cell * 0.9) + 3.1) * 0.4;
	float sponge = smoothstep(0.18, 0.55, f1) * 0.35 + smoothstep(0.15, 0.5, f2) * 0.2 + mott * 0.45;
	float d = definition / 25.0;
	float l = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	rgb = mix(vec3(l), rgb, 1.0 + d * 0.5);
	rgb = (rgb - 0.5) * (1.0 + d * 0.6) + 0.5;
	float m = smoothstep(0.25, 0.75, sponge);
	rgb *= mix(1.0 - (0.3 + d * 0.45), 1.0 + d * 0.12, m);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
