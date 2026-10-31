shader_type canvas_item;
render_mode blend_disabled;

uniform float spray_radius : hint_range(0.0, 25.0) = 10.0;
uniform float smoothness : hint_range(1.0, 15.0) = 5.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float h12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec2 field(vec2 p, float s) {
	vec2 a = vec2(vn(p / s), vn(p / s + 41.3));
	vec2 b = vec2(vn(p / (s * 0.45) + 13.7), vn(p / (s * 0.45) + 77.1));
	return (a * 0.65 + b * 0.35 - 0.5) * 2.0;
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float fs = float(seed);
	vec2 so = vec2(mod(fs * 12.9898, 997.0), mod(fs * 78.233, 991.0));
	vec2 P = UV * dims / ps + so;
	float sm = clamp(smoothness, 1.0, 15.0);
	float scale = 0.6 + sm * 0.55;
	vec2 blot = field(P, scale);
	vec2 cell = floor(P);
	vec2 speck = vec2(h12(cell), h12(cell + 19.19)) * 2.0 - 1.0;
	float fine = mix(0.55, 0.0, (sm - 1.0) / 14.0);
	vec2 disp = (blot * (1.0 - fine) + speck * fine) * spray_radius * 1.25;
	vec4 c = texture(TEXTURE, UV);
	vec4 s = texture(TEXTURE, clamp(UV + disp * ps / dims, vec2(0.0), vec2(1.0)));
	vec3 rgb = s.a > 0.0001 ? clamp(s.rgb / s.a, 0.0, 1.0) : (c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0));
	COLOR = vec4(rgb * c.a, c.a);
}
