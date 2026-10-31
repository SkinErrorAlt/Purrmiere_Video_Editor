shader_type canvas_item;
render_mode blend_disabled;

uniform float image_balance : hint_range(0.0, 50.0) = 25.0;
uniform float smoothness : hint_range(1.0, 15.0) = 11.0;
uniform float contrast : hint_range(1.0, 25.0) = 17.0;
uniform vec4 ink : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 paper : source_color = vec4(1.0, 1.0, 1.0, 1.0);
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

float lum_at(sampler2D tex, vec2 uv) {
	vec4 c = texture(tex, clamp(uv, vec2(0.0), vec2(1.0)));
	vec3 rgb = c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
	return dot(rgb, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float fs = float(seed);
	vec2 so = vec2(mod(fs * 12.9898, 997.0), mod(fs * 78.233, 991.0));
	vec2 P = UV * dims / ps + so;
	float sm = clamp(smoothness, 1.0, 15.0);
	float rough = (16.0 - sm) / 15.0;
	vec2 tear = vec2(vn(P / 6.0) * 0.5 + vn(P / 2.5 + 7.1) * 0.3 + vn(P / 1.1 + 3.3) * 0.2, vn(P / 6.0 + 19.0) * 0.5 + vn(P / 2.5 + 29.1) * 0.3 + vn(P / 1.1 + 13.3) * 0.2) - 0.5;
	vec2 uv = UV + tear * (2.0 + rough * 14.0) * ps / dims;
	vec2 r = vec2((0.8 + sm * 0.12) * ps) / dims;
	float l = lum_at(TEXTURE, uv) * 0.4 + (lum_at(TEXTURE, uv + vec2(r.x, 0.0)) + lum_at(TEXTURE, uv - vec2(r.x, 0.0)) + lum_at(TEXTURE, uv + vec2(0.0, r.y)) + lum_at(TEXTURE, uv - vec2(0.0, r.y))) * 0.15;
	float blot = vn(P / 14.0 + 71.0) * 0.6 + vn(P / 6.0 + 23.0) * 0.4 - 0.5;
	float fib = blot * (0.1 + rough * 0.12) + (vn(P / 0.8 + 51.0) - 0.5) * 0.025 * (0.4 + rough);
	float t = clamp(image_balance / 50.0, 0.0, 1.0);
	float edge = 1.0 - clamp((contrast - 1.0) / 24.0, 0.0, 1.0);
	float soft = 0.004 + edge * edge * 0.22;
	float k = smoothstep(t - soft, t + soft, l + fib);
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 col = mix(ink.rgb, paper.rgb, k);
	COLOR = vec4(clamp(col, 0.0, 1.0) * a, a);
}
