shader_type canvas_item;
render_mode blend_disabled;

uniform float wetness : hint_range(0.0, 1.0) = 0.5;
uniform float edge_darkening : hint_range(0.0, 1.0) = 0.5;
uniform float granulation : hint_range(0.0, 1.0) = 0.4;
uniform float paper : hint_range(0.0, 1.0) = 0.5;
uniform vec4 paper_colour : source_color = vec4(0.98, 0.96, 0.92, 1.0);
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

#define TAP(p) texture(TEXTURE, clamp(p, vec2(0.0), vec2(1.0)))

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 seed_offset(int s) {
	float f = float(s);
	return vec2(mod(f * 12.9898, 997.0), mod(f * 78.233, 991.0));
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

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 so = seed_offset(seed);
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 e = vec2(max(mix(1.0, 3.0, wetness) * ps, 1.0)) / dims;
	vec4 sl = TAP(UV - vec2(e.x, 0.0));
	vec4 sr = TAP(UV + vec2(e.x, 0.0));
	vec4 su = TAP(UV - vec2(0.0, e.y));
	vec4 sd = TAP(UV + vec2(0.0, e.y));
	float g = length(sr - sl) + length(sd - su);
	float edge = smoothstep(0.03, 0.3, g);
	vec2 pp = UV * dims / ps + so;
	float gran = value_noise(pp / 1.5) * 0.6 + value_noise(pp / 4.0 + 13.1) * 0.4;
	float fibre = value_noise(pp / 5.0 + 41.7) * 0.5 + value_noise(pp / 13.0 + 3.3) * 0.3 + value_noise(vec2(pp.x / 40.0, pp.y / 9.0) + 77.0) * 0.2;
	float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	float pigment = 1.0 - luma * 0.6;
	float density = 1.0 + edge_darkening * edge * 1.2 + granulation * (gran - 0.5) * 1.2 * pigment + paper * (fibre - 0.5) * 0.6;
	rgb = clamp(rgb, 0.0, 1.0);
	rgb = rgb - (rgb - rgb * rgb) * (density - 1.0);
	rgb *= paper_colour.rgb;
	rgb += (fibre - 0.5) * paper * 0.06;
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
