shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D effect_tex : filter_linear, repeat_disable;
uniform int stock : hint_range(0, 2) = 0;
uniform float development : hint_range(0.0, 1.0) = 1.0;
uniform float softness : hint_range(0.0, 1.0) = 0.45;
uniform float fade : hint_range(0.0, 1.0) = 0.4;
uniform float chemistry : hint_range(0.0, 1.0) = 0.5;
uniform int pod : hint_range(0, 3) = 0;
uniform float rollers : hint_range(0.0, 1.0) = 0.3;
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

float vn1(float x, float k) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(h12(vec2(i, k)), h12(vec2(i + 1.0, k)), f);
}

vec3 straight(vec4 c) {
	return c.a > 0.0001 ? clamp(c.rgb / c.a, 0.0, 1.0) : vec3(0.0);
}

void fragment() {
	vec4 sharp = texture(effect_tex, UV);
	float alpha = sharp.a;
	vec3 s_rgb = straight(sharp);
	vec3 b_rgb = straight(texture(TEXTURE, UV));
	vec2 out_size = vec2(textureSize(effect_tex, 0));
	float ps = max(px_scale * 2.0, 0.0001);
	vec2 src = out_size / ps;
	vec2 P = UV * src;
	float sd = float(seed);
	vec3 v = mix(s_rgb, b_rgb, softness * 0.75);
	v += max(b_rgb - 0.62, vec3(0.0)) * softness * 0.55;
	float l = dot(v, vec3(0.2126, 0.7152, 0.0722));
	float sat = stock == 0 ? 0.8 : (stock == 1 ? 0.95 : 0.68);
	v = mix(vec3(l), v, sat);
	vec3 sh_tint = stock == 0 ? vec3(0.06, 0.2, 0.24) : (stock == 1 ? vec3(0.12, 0.06, 0.1) : vec3(0.3, 0.17, 0.06));
	vec3 hi_tint = stock == 0 ? vec3(1.0, 0.965, 0.87) : (stock == 1 ? vec3(0.97, 0.98, 1.0) : vec3(1.04, 0.9, 0.66));
	float contrast = stock == 1 ? 1.12 : (stock == 0 ? 1.0 : 0.85);
	v = clamp((v - 0.5) * contrast + 0.5, 0.0, 1.0);
	v = v * mix(vec3(1.0), hi_tint, smoothstep(0.25, 1.0, l));
	float lift = fade * (stock == 2 ? 0.75 : 0.5);
	v = sh_tint * lift * (1.0 - smoothstep(0.0, 0.7, l) * 0.6) + v * (1.0 - lift * 0.22);
	v = 1.0 - pow(1.0 - clamp(v, 0.0, 1.0), vec3(1.12));
	vec2 cc = (UV - 0.5) * vec2(1.0, out_size.y / out_size.x) * 2.0;
	v *= 1.0 - (stock == 2 ? 0.3 : 0.17) * smoothstep(0.35, 1.25, length(cc));
	v += (h12(floor(P * 0.8) + sd) - 0.5) * 0.02;
	vec3 lin = pow(clamp(v, vec3(0.002), vec3(1.0)), vec3(2.2));
	vec3 dens = -log(lin);
	float dv = development;
	vec3 dye = vec3(smoothstep(0.0, 0.55, dv), smoothstep(0.08, 0.75, dv), smoothstep(0.2, 1.0, dv));
	vec3 col = pow(exp(-dens * dye), vec3(1.0 / 2.2));
	float haze = 1.0 - smoothstep(0.0, 0.8, dv);
	col = mix(col, vec3(0.55, 0.66, 0.65) * mix(vec3(1.0), col, 0.25), haze * 0.92);
	float s = 1.0 - UV.y;
	float u = UV.x;
	float ls = src.y;
	float lu = src.x;
	if (pod == 1) {
		s = UV.y;
	} else if (pod == 2) {
		s = UV.x;
		u = UV.y;
		ls = src.x;
		lu = src.y;
	} else if (pod == 3) {
		s = 1.0 - UV.x;
		u = UV.y;
		ls = src.x;
		lu = src.y;
	}
	float up = u * lu;
	float wave = vn1(up / 140.0, sd) * 0.6 + vn1(up / 48.0, sd + 3.0) * 0.32 + vn1(up / 16.0, sd + 7.0) * 0.08;
	float corner = pow(max(1.0 - u / 0.2, 0.0), 2.0) * (0.6 + 0.8 * h12(vec2(sd, 1.0))) + pow(max(1.0 - (1.0 - u) / 0.2, 0.0), 2.0) * (0.6 + 0.8 * h12(vec2(sd, 2.0)));
	float front = 1.0 - chemistry * (0.006 + 0.06 * wave * wave * wave + 0.08 * corner);
	float edge_px = 1.5 / ls;
	float blank = smoothstep(front - edge_px, front + edge_px, s) * step(0.001, chemistry);
	float rim = exp(-pow((s - front + 4.0 / ls) * ls / 4.0, 2.0)) * chemistry;
	vec3 undev = stock == 2 ? vec3(0.95, 0.72, 0.42) : vec3(0.93, 0.89, 0.74);
	undev *= 0.97 + 0.06 * vn(P * 0.05 + sd);
	float streak = (vn(vec2(up / 2.2, s * ls / 160.0) + sd * 2.0) - 0.5) * smoothstep(0.55, 1.0, vn1(up / 40.0, sd + 11.0));
	col *= 1.0 + streak * chemistry * 0.14;
	col = mix(col, col * vec3(0.78, 0.7, 0.66), rim * 0.8 * (1.0 - blank));
	col = mix(col, col + (1.0 - col) * 0.25, chemistry * 0.12 * smoothstep(0.55, 1.0, s));
	float period = 0.31;
	for (int k = 0; k < 2; k++) {
		float kf = float(k);
		float uc = 0.15 + 0.7 * h12(vec2(sd * 1.3 + kf, 5.0));
		float s0 = h12(vec2(sd * 0.7 + kf, 9.0)) * period;
		float sk = s0 + period * floor((s - s0) / period + 0.5);
		vec2 dd = vec2((u - uc) * lu / 6.0, (s - sk) * ls / 2.8);
		float r2 = dot(dd, dd);
		float spot = exp(-r2);
		float ring = exp(-pow(sqrt(r2) - 1.4, 2.0) / 0.12);
		col = mix(col, col + (1.0 - col) * 0.55, spot * rollers);
		col *= 1.0 - ring * rollers * 0.3;
		float line_band = exp(-pow((s - sk - 0.5 * period) * ls / 1.6, 2.0)) * (0.5 + 0.5 * vn1(up / 60.0, sd + kf * 13.0));
		col *= 1.0 - line_band * rollers * 0.1 * (1.0 - kf);
	}
	col = mix(col, undev, blank);
	COLOR = vec4(clamp(col, 0.0, 1.0) * alpha, alpha);
}
