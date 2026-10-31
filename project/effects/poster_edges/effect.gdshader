shader_type canvas_item;
render_mode blend_disabled;

uniform float edge_thickness : hint_range(0.0, 10.0) = 2.0;
uniform float edge_intensity : hint_range(0.0, 10.0) = 1.0;
uniform int posterization : hint_range(0, 6) = 2;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float lum(vec4 c) {
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	return dot(rgb, vec3(0.2126, 0.7152, 0.0722));
}

#define L(o) lum(texture(TEXTURE, UV + (o)))

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	float ps = max(px_scale, 0.0001);
	vec2 dims = max(tex_size, vec2(1.0));
	vec2 d = vec2((0.6 + edge_thickness * 0.45) * ps) / dims;
	float tl = L(vec2(-d.x, -d.y));
	float tc = L(vec2(0.0, -d.y));
	float tr = L(vec2(d.x, -d.y));
	float ml = L(vec2(-d.x, 0.0));
	float mr = L(vec2(d.x, 0.0));
	float bl = L(vec2(-d.x, d.y));
	float bc = L(vec2(0.0, d.y));
	float br = L(vec2(d.x, d.y));
	float gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
	float gy = (bl + 2.0 * bc + br) - (tl + 2.0 * tc + tr);
	float g = length(vec2(gx, gy)) * 0.25;
	float grit = (hash12(floor(UV * dims / ps)) - 0.5) * 0.04;
	float ink = smoothstep(0.05, 0.17, g * (0.5 + edge_intensity * 0.5) + grit);
	float n = float(clamp(posterization, 0, 6) + 3);
	vec3 q = min(floor(clamp(rgb, 0.0, 1.0) * n), vec3(n - 1.0)) / (n - 1.0);
	vec3 outc = q * (1.0 - ink * 0.95);
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
