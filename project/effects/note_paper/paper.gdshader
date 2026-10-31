shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform float image_balance : hint_range(0.0, 50.0) = 25.0;
uniform float graininess : hint_range(0.0, 20.0) = 10.0;
uniform float relief : hint_range(0.0, 25.0) = 11.0;
uniform vec4 ink : source_color = vec4(0.42, 0.42, 0.43, 1.0);
uniform vec4 paper : source_color = vec4(0.94, 0.93, 0.9, 1.0);
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

float tone(sampler2D tex, vec2 uv) {
	vec4 s = texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
	return s.g > 0.0001 ? clamp(s.r / s.g, 0.0, 1.0) : 1.0;
}

float raised(sampler2D tex, vec2 uv, float t, float w) {
	return 1.0 - smoothstep(t - w, t + w, tone(tex, uv));
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float fs = float(seed);
	vec2 so = vec2(mod(fs * 12.9898, 997.0), mod(fs * 78.233, 991.0));
	vec2 P = UV * dims / ps + so;
	vec4 o = texture(effect_tex, UV);
	float a = o.a;
	float t = clamp(image_balance / 50.0, 0.02, 0.98);
	vec2 ex = vec2(ps / dims.x, 0.0);
	vec2 ey = vec2(0.0, ps / dims.y);
	float gl = length(vec2(tone(TEXTURE, UV + ex) - tone(TEXTURE, UV - ex), tone(TEXTURE, UV + ey) - tone(TEXTURE, UV - ey))) * 0.5;
	float w = max(gl * 0.75, 0.002);
	float h = raised(TEXTURE, UV, t, w);
	float rk = clamp(relief / 25.0, 0.0, 1.0);
	float b = 1.0 + rk * 2.0;
	vec2 bx = ex * b;
	vec2 by = ey * b;
	vec2 g = vec2(raised(TEXTURE, UV + bx, t, w) - raised(TEXTURE, UV - bx, t, w), raised(TEXTURE, UV + by, t, w) - raised(TEXTURE, UV - by, t, w)) * 0.5;
	vec2 to_light = vec2(-0.7071, -0.7071);
	float shade = -dot(g, to_light) * rk * 1.1;
	vec2 sd = to_light * (1.0 + rk * 2.5) * ps / dims;
	float drop = max(raised(TEXTURE, UV + sd, t, w) - h, 0.0) * rk * 0.35;
	vec3 col = mix(paper.rgb, ink.rgb, h);
	col *= 1.0 + shade;
	col *= 1.0 - drop;
	float gk = clamp(graininess / 20.0, 0.0, 1.0);
	float grain = (h12(floor(P)) - 0.5) * 0.6 + (vn(P / 2.5 + 31.0) - 0.5) * 0.4;
	col += grain * gk * 0.12;
	COLOR = vec4(clamp(col, 0.0, 1.0) * a, a);
}
