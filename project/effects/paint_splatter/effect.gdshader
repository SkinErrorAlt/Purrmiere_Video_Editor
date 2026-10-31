shader_type canvas_item;
render_mode blend_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform int splats : hint_range(4, 80) = 28;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size;

float h(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float aspect = max(tex_size.x, 1.0) / max(tex_size.y, 1.0);
	vec2 p = UV * vec2(aspect, 1.0);
	float n = float(max(splats, 1));
	float keep = 1.0;
	float sd = float(seed);
	for (int i = 0; i < 80; i++) {
		if (i >= splats) { break; }
		float fi = float(i);
		vec2 ctr = vec2(h(vec3(fi, sd, 1.0)) * aspect, h(vec3(fi, sd, 2.0)));
		float t0 = fi / n * 0.8;
		float g = clamp((progress - t0) / 0.15, 0.0, 1.0);
		if (g <= 0.0) { continue; }
		float big = (0.18 + 0.22 * h(vec3(fi, sd, 3.0))) * sqrt(28.0 / n) * 1.6;
		vec2 d = p - ctr;
		float a = atan(d.y, d.x);
		float wob = 1.0 + roughness * 0.25 * (sin(a * 7.0 + fi * 3.1) + 0.6 * sin(a * 13.0 + fi * 1.7) + 0.4 * sin(a * 23.0 + fi));
		float r = big * (1.0 - pow(1.0 - g, 3.0)) * wob;
		keep *= smoothstep(r - 0.004, r + 0.004, length(d));
	}
	keep *= 1.0 - smoothstep(0.9, 1.0, progress);
	COLOR = c * keep;
}
