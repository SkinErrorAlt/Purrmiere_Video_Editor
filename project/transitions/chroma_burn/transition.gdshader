shader_type canvas_item;
render_mode blend_disabled;
#include "res://transitions/_lib/transition.gdshaderinc"

uniform int map = 0;
uniform int order = 0;
uniform float width : hint_range(0.02, 0.5) = 0.12;
uniform float glow : hint_range(0.0, 3.0) = 0.9;
uniform float fringe : hint_range(0.0, 1.0) = 0.6;
uniform float char : hint_range(0.0, 1.0) = 0.6;
uniform float softness : hint_range(0.0, 1.0) = 0.3;
uniform float noise : hint_range(0.0, 0.5) = 0.15;

vec3 to_linear(vec3 c) {
	vec3 lo = c / 12.92;
	vec3 hi = pow((max(c, vec3(0.0)) + 0.055) / 1.055, vec3(2.4));
	return mix(lo, hi, step(vec3(0.04045), c));
}

vec3 to_srgb(vec3 c) {
	vec3 lo = c * 12.92;
	vec3 hi = 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055;
	return mix(lo, hi, step(vec3(0.0031308), c));
}

vec4 lin_premul(vec4 c) {
	if (c.a <= 0.0) {
		return vec4(0.0);
	}
	return vec4(to_linear(c.rgb / c.a) * c.a, c.a);
}

vec4 srgb_premul(vec4 c) {
	if (c.a <= 0.0) {
		return vec4(0.0);
	}
	return vec4(to_srgb(c.rgb / c.a) * c.a, c.a);
}

float luma_at(vec2 uv) {
	vec2 c = clamp(uv, vec2(0.0), vec2(1.0));
	float a = dot(texture(from_tex, c).rgb, vec3(0.2126, 0.7152, 0.0722));
	float b = dot(texture(to_tex, c).rgb, vec3(0.2126, 0.7152, 0.0722));
	return map == 0 ? a : (map == 1 ? b : 0.5 * (a + b));
}

float soft_noise(vec2 p) {
	float v = tr_noise(p) * 0.6;
	v += tr_noise(p * 2.07 + vec2(13.1, 7.7)) * 0.3;
	v += tr_noise(p * 4.13 + vec2(3.3, 21.9)) * 0.1;
	return v;
}

vec2 rank_of(float v) {
	float r = 0.0;
	float dr = 0.0;
	float h = 0.1;
	for (int j = 0; j < 6; j++) {
		for (int i = 0; i < 10; i++) {
			vec2 at = (vec2(float(i), float(j)) + vec2(0.5 + 0.23 * float(j % 2), 0.5)) / vec2(10.0, 6.0);
			float k = luma_at(at);
			float x = clamp((v - k + h) / (2.0 * h), 0.0, 1.0);
			r += x * x * (3.0 - 2.0 * x);
			dr += 6.0 * x * (1.0 - x) / (2.0 * h);
		}
	}
	return vec2(r, dr) / 60.0;
}

vec3 key_at(vec2 uv) {
	float r = (2.5 + softness * 12.0) * px_scale;
	vec2 px = r / frame_px;
	float c = luma_at(uv);
	float l = luma_at(uv - vec2(px.x, 0.0));
	float rr = luma_at(uv + vec2(px.x, 0.0));
	float u = luma_at(uv - vec2(0.0, px.y));
	float d = luma_at(uv + vec2(0.0, px.y));
	float ul = luma_at(uv - px);
	float dr = luma_at(uv + px);
	float ur = luma_at(uv + vec2(px.x, -px.y));
	float dl = luma_at(uv + vec2(-px.x, px.y));
	float v = c * 0.28 + (l + rr + u + d) * 0.12 + (ul + dr + ur + dl) * 0.06;
	vec2 g = vec2((rr - l) * 2.0 + (dr - dl) + (ur - ul), (d - u) * 2.0 + (dr - ur) + (dl - ul)) / (8.0 * r);
	vec2 rk = rank_of(v);
	float key = rk.x;
	g *= rk.y;
	vec2 wp = tr_world(uv) * 4.0;
	float n0 = soft_noise(wp);
	float step_w = 4.0 / frame_px.y * 4.0;
	float nx = soft_noise(wp + vec2(step_w, 0.0));
	float ny = soft_noise(wp + vec2(0.0, step_w));
	float amp = noise * 2.6;
	key += (n0 - 0.5) * amp;
	g += vec2(nx - n0, -(ny - n0)) / 4.0 * amp;
	if (order == 1) {
		return vec3(1.0 - key, -g);
	}
	return vec3(key, g);
}

vec4 transition(vec2 uv) {
	float p = clamp(progress, 0.0, 1.0);
	vec4 a = from_at(uv);
	vec4 b = to_at(uv);
	if (p <= 0.0) {
		return a;
	}
	if (p >= 1.0) {
		return b;
	}
	vec3 kg = key_at(uv);
	float key = clamp(kg.x, 0.0, 1.0);
	float h = 0.25 + softness * 0.3;
	float split = 0.45 * fringe;
	float margin = (h + split + 0.02) * width;
	float thr = mix(1.0 + margin, -margin, p);
	vec2 grad = kg.yz;
	float band = (28.0 + 90.0 * width) * px_scale;
	float scale = min(width, max(length(grad) * band, width * 0.3));
	float s = (key - thr) / scale;
	float ends = smoothstep(0.0, 0.05, p) * smoothstep(0.0, 0.05, 1.0 - p);
	vec3 m = vec3(smoothstep(-h, h, s + split), smoothstep(-h, h, s), smoothstep(-h, h, s - split));
	vec4 la = lin_premul(a);
	vec4 lb = lin_premul(b);
	float scorch = char * exp(-pow((s + 0.75) / 0.45, 2.0)) * ends;
	la.rgb *= 1.0 - 0.9 * scorch;
	vec3 rgb = mix(la.rgb, lb.rgb, m);
	float alpha = mix(la.a, lb.a, m.g);
	vec3 hot = vec3(1.0, 0.82, 0.55) * exp(-s * s * 7.0) * 1.6;
	hot += vec3(1.0, 0.32, 0.04) * exp(-pow((s + 0.4) / 0.32, 2.0)) * (0.6 + 0.8 * fringe);
	hot += vec3(0.1, 0.45, 1.0) * exp(-pow((s - 0.45) / 0.3, 2.0)) * 1.1 * fringe;
	float steep = length(grad) * band / max(width * 0.6, 0.0001);
	float moving = 1.0 / (1.0 + steep * steep);
	vec3 light = hot * glow * ends * mix(0.15, 1.0, moving);
	vec3 lit = rgb + (vec3(1.0) - min(rgb, vec3(1.0))) * (vec3(1.0) - exp(-light));
	float out_a = clamp(max(alpha, max(lit.r, max(lit.g, lit.b))), 0.0, 1.0);
	return srgb_premul(vec4(min(lit, vec3(out_a)), out_a));
}

void fragment() {
	COLOR = transition(UV);
}
