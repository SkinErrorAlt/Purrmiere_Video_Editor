shader_type canvas_item;
render_mode blend_disabled;

uniform vec4 tint : source_color = vec4(0.35, 0.85, 1.0, 1.0);
uniform float line_density : hint_range(20.0, 1000.0) = 240.0;
uniform float speed : hint_range(0.0, 5.0) = 1.0;
uniform float flicker : hint_range(0.0, 1.0) = 0.3;
uniform float glitch : hint_range(0.0, 1.0) = 0.3;
uniform float transparency : hint_range(0.0, 1.0) = 0.35;
uniform float fringe : hint_range(0.0, 20.0) = 3.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

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

float noise1(float x, float salt, vec2 so) {
	float i = floor(x);
	float f = x - i;
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash12(vec2(i, salt) + so), hash12(vec2(i + 1.0, salt) + so), f);
}

float luma_of(vec4 s) {
	vec3 c = s.a > 0.0001 ? s.rgb / s.a : vec3(0.0);
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

float edge_value(vec4 s) {
	return dot(s.rgb, vec3(0.2126, 0.7152, 0.0722)) * 0.6 + s.a * 0.4;
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	vec2 so = seed_offset(seed);
	float t = max(clip_time, 0.0);
	float tick = floor(t * 12.0);
	float slice_h = 0.015 + 0.06 * hash12(vec2(tick, 3.0) + so);
	float slice = floor(UV.y / slice_h);
	float burst = step(1.0 - glitch * 0.7, hash12(vec2(tick, 11.0) + so));
	float hit = step(0.72, hash12(vec2(slice, tick) + so)) * burst * step(0.001, glitch);
	float dx = (hash12(vec2(slice, tick + 5.0) + so) - 0.5) * 0.1 * glitch * hit;
	vec2 uv = vec2(UV.x + dx, UV.y);
	float fr = fringe * px_scale / dims.x * (1.0 + 2.0 * hit);
	vec4 cg = TAP(uv);
	vec4 cr = TAP(uv + vec2(fr, 0.0));
	vec4 cb = TAP(uv - vec2(fr, 0.0));
	vec3 lum3 = vec3(luma_of(cr), luma_of(cg), luma_of(cb));
	float src_a = max(cg.a, max(cr.a, cb.a));
	vec2 e = vec2(max(1.5 * px_scale, 1.0)) / dims;
	float gx = edge_value(TAP(uv + vec2(e.x, 0.0))) - edge_value(TAP(uv - vec2(e.x, 0.0)));
	float gy = edge_value(TAP(uv + vec2(0.0, e.y))) - edge_value(TAP(uv - vec2(0.0, e.y)));
	float edge = clamp(length(vec2(gx, gy)) * 2.0, 0.0, 1.0);
	float lines = 0.5 + 0.5 * sin((UV.y * line_density - t * speed * 10.0) * 6.2831853);
	float bd = fract(UV.y - fract(t * speed * 0.2) + 0.5) - 0.5;
	float bar = exp(-bd * bd * 200.0);
	float fl = 1.0 - flicker * 0.35 * noise1(t * 14.0, 21.0, so) - flicker * 0.4 * step(0.93, hash12(vec2(tick, 23.0) + so));
	vec3 rgb = tint.rgb * (0.2 + 1.1 * lum3) + pow(lum3, vec3(3.0)) * 0.35;
	rgb += tint.rgb * edge * 1.2;
	rgb *= 0.72 + 0.28 * lines;
	rgb += tint.rgb * bar * 0.35;
	rgb *= fl;
	float body = clamp(0.35 + 0.65 * lum3.g + edge + bar * 0.3, 0.0, 1.0);
	float alpha = src_a * mix(1.0, body * (0.75 + 0.25 * lines), clamp(transparency, 0.0, 1.0)) * mix(1.0, fl, 0.5);
	alpha = clamp(alpha, 0.0, 1.0);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * alpha, alpha);
}
