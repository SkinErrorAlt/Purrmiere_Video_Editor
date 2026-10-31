shader_type canvas_item;
render_mode blend_disabled;

uniform float hue_noise : hint_range(0.0, 1.0) = 0.0;
uniform float lightness_noise : hint_range(0.0, 1.0) = 0.15;
uniform float saturation_noise : hint_range(0.0, 1.0) = 0.0;
uniform float grain_size : hint_range(1.0, 20.0) = 1.0;
uniform bool animate = true;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size;
uniform float px_scale;
uniform float time;

float h(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
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

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	vec2 cell = floor(UV * tex_size / max(grain_size * max(px_scale, 0.0001), 0.0001));
	float f = animate ? floor(time * 24.0) : 0.0;
	vec3 b = vec3(cell, f + float(seed) * 17.0);
	vec3 hsv = rgb2hsv(rgb);
	hsv.x = fract(hsv.x + (h(b) - 0.5) * hue_noise);
	hsv.y = clamp(hsv.y + (h(b + vec3(5.9, 13.7, 1.3)) - 0.5) * saturation_noise * 2.0, 0.0, 1.0);
	vec3 o = hsv2rgb(hsv) + vec3((h(b + vec3(11.3, 7.1, 3.7)) - 0.5) * lightness_noise);
	COLOR = vec4(clamp(o, 0.0, 1.0) * c.a, c.a);
}
