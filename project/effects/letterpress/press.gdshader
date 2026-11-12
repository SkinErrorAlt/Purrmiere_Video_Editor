shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform sampler2D plate_tex : filter_linear, repeat_disable;
uniform float depth : hint_range(0.0, 1.0) = 0.6;
uniform float bite : hint_range(1.0, 16.0) = 5.0;
uniform float light_angle : hint_range(-180.0, 180.0) = -135.0;
uniform float squeeze : hint_range(0.0, 1.0) = 0.6;
uniform float coverage : hint_range(0.0, 1.0) = 0.72;
uniform float tooth : hint_range(0.0, 1.0) = 0.5;
uniform vec4 ink : source_color = vec4(0.1, 0.12, 0.2, 1.0);
uniform vec4 paper : source_color = vec4(0.95, 0.93, 0.88, 1.0);
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

float fibres(vec2 p, vec2 off) {
	float a = vn(vec2(p.x * 0.55, p.y * 0.14) + off);
	float b = vn(vec2(p.x * 0.12 + p.y * 0.4, p.y * 0.12 - p.x * 0.4) + off * 1.7);
	float c = vn(p * 0.9 + off * 2.3);
	float d = vn(p * 0.18 + off * 0.7);
	return a * 0.3 + b * 0.25 + c * 0.2 + d * 0.25;
}

float height(sampler2D tex, vec2 uv) {
	return texture(tex, uv).r;
}

void fragment() {
	vec4 src = texture(effect_tex, UV);
	float alpha = src.a;
	vec2 size = max(tex_size, vec2(1.0));
	vec2 texel = 1.0 / size;
	float ps = max(px_scale, 0.0001);
	vec2 src_size = size / ps;
	vec2 P = UV * src_size;
	vec2 off = vec2(float(seed) * 17.13, float(seed) * 5.71);
	float hx = height(TEXTURE, UV + vec2(texel.x, 0.0)) - height(TEXTURE, UV - vec2(texel.x, 0.0));
	float hy = height(TEXTURE, UV + vec2(0.0, texel.y)) - height(TEXTURE, UV - vec2(0.0, texel.y));
	vec2 grad = vec2(hx, hy) * ps * 0.5;
	float h = height(TEXTURE, UV);
	float rad = radians(light_angle);
	vec3 L = normalize(vec3(cos(rad), sin(rad), 0.9));
	float drop = depth * bite * 2.2;
	float t0 = fibres(P, off);
	float tx = fibres(P + vec2(1.0, 0.0), off) - t0;
	float ty = fibres(P + vec2(0.0, 1.0), off) - t0;
	vec2 tgrad = vec2(tx, ty) * tooth * 2.4;
	vec3 n = normalize(vec3(drop * grad - tgrad * (1.0 - 0.5 * h * depth), 1.0));
	float shade = dot(n, L) / L.z;
	shade = mix(1.0, shade, 0.8);
	vec2 pt = 1.0 / max(vec2(textureSize(plate_tex, 0)), vec2(1.0));
	float m = texture(plate_tex, UV).r;
	float ring = 0.0;
	float rr = 1.6 * ps * 2.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		ring += texture(plate_tex, UV + vec2(cos(a), sin(a)) * pt * rr).r;
	}
	ring /= 8.0;
	float rim = m * clamp((1.0 - ring) * 2.2, 0.0, 1.0);
	float spill = (1.0 - m) * clamp(ring * 1.6, 0.0, 1.0) * smoothstep(0.15, 0.6, h);
	float grit = vn(P * 0.75 + off * 3.1) * 0.55 + (1.0 - t0) * 0.45;
	float press_loss = smoothstep(0.9, 1.0, h) * 0.08;
	float bare_at = mix(0.42, 0.92, coverage) - press_loss;
	float bare = smoothstep(bare_at, bare_at + 0.06, grit + (vn(P * 0.03 + off) - 0.5) * 0.12);
	float speck = step(0.997 - (1.0 - coverage) * 0.01, h12(floor(P * 0.7) + off));
	float mottle = vn(P * 0.02 + off * 0.3) * 0.6 + vn(vec2(P.x * 0.004, P.y * 0.05) + off) * 0.4;
	float dens = m * (1.0 - bare * 0.85) * (1.0 - speck) * mix(mix(0.7, 0.86, coverage), 1.0, mottle) * (1.0 - squeeze * 0.14 * smoothstep(0.85, 1.0, h));
	dens = clamp(dens + rim * squeeze * 0.6 * m + spill * squeeze * 0.4, 0.0, 1.0);
	dens = clamp(dens + rim * squeeze * (1.0 - dens) * 0.9, 0.0, 1.0);
	vec3 base = paper.rgb * (0.96 + 0.06 * (t0 - 0.5) * tooth * 2.0);
	vec3 inked = base * mix(vec3(1.0), ink.rgb, dens);
	float sink = 1.0 - 0.05 * depth * smoothstep(0.3, 1.0, h);
	vec3 col = inked * shade * sink;
	COLOR = vec4(clamp(col, 0.0, 1.0) * alpha, alpha);
}
