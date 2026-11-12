shader_type canvas_item;
render_mode blend_disabled;

uniform float print_density : hint_range(-1.0, 1.0) = 0.0;
uniform float development : hint_range(0.0, 1.0) = 0.5;
uniform float pepper : hint_range(0.0, 1.0) = 0.6;
uniform float grain : hint_range(0.5, 4.0) = 1.4;
uniform float warmth : hint_range(0.0, 1.0) = 0.75;
uniform vec4 highlight : source_color = vec4(0.94, 0.76, 0.65, 1.0);
uniform vec4 shadow : source_color = vec4(0.09, 0.09, 0.085, 1.0);
uniform vec4 paper : source_color = vec4(0.97, 0.95, 0.91, 1.0);
uniform int seed : hint_range(0, 999) = 7;
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

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float alpha = src.a;
	vec3 rgb = alpha > 0.0001 ? clamp(src.rgb / alpha, 0.0, 1.0) : vec3(0.0);
	vec2 size = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 P = UV * size / ps;
	vec2 off = vec2(float(seed) * 11.3, float(seed) * 4.9);
	float l = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	float x = clamp((1.0 - l) * (1.0 + 0.55 * print_density) + 0.12 * print_density, 0.0, 1.0);
	float ds = pow(x, 1.25) * 0.95;
	float gs = max(grain, 0.3);
	vec2 g = P / gs;
	float clump = vn(g * 0.45 + off) * 0.45 + vn(g + off * 1.3) * 0.35 + h12(floor(g * 1.6) + off) * 0.2;
	float big = vn(g * 0.12 + off * 0.6);
	float t = mix(0.98, 0.38, development);
	float band = exp(-pow((x - t) / 0.28, 2.0));
	float n = (clump - 0.5) * pepper * 0.7 + (big - 0.5) * pepper * 0.12;
	float w = mix(0.07, 0.14, 1.0 - pepper);
	float di = smoothstep(t - w, t + w, x + n * (0.35 + 0.65 * band));
	float specks = step(1.0 - pepper * 0.35 * band * smoothstep(t - 0.45, t, x), clump * 0.6 + h12(floor(g * 2.0) + off * 2.0) * 0.4);
	di = max(di, specks * 0.85);
	vec3 a_warm = -log(clamp(highlight.rgb, vec3(0.02), vec3(1.0)));
	vec3 a_grey = vec3(dot(a_warm, vec3(0.333)));
	vec3 absorb = mix(a_grey, a_warm, warmth);
	vec3 soft = exp(-absorb * ds * 3.2);
	vec3 hard = mix(vec3(1.0), shadow.rgb / max(paper.rgb, vec3(0.05)), di);
	vec3 col = paper.rgb * soft * hard;
	COLOR = vec4(clamp(col, 0.0, 1.0) * alpha, alpha);
}
