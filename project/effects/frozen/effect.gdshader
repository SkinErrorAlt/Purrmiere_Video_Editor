shader_type canvas_item;
render_mode blend_disabled;

uniform float amount : hint_range(0.0, 1.0) = 0.5;
uniform float grow_time : hint_range(0.0, 10.0) = 0.0;
uniform float crystal_size : hint_range(4.0, 300.0) = 60.0;
uniform vec4 tint : source_color = vec4(0.8, 0.92, 1.0, 1.0);
uniform float frost : hint_range(0.0, 1.0) = 0.75;
uniform float refraction : hint_range(0.0, 40.0) = 8.0;
uniform float cold : hint_range(0.0, 1.0) = 0.4;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec2 w = mod(i, 512.0);
	return mix(mix(hash12(w), hash12(w + vec2(1.0, 0.0)), f.x), mix(hash12(w + vec2(0.0, 1.0)), hash12(w + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		sum += value_noise(p) * amp;
		p = mat2(vec2(1.6, -1.2), vec2(1.2, 1.6)) * p + vec2(7.3, 3.1);
		amp *= 0.5;
	}
	return sum / 0.9375;
}

float ridged(vec2 p) {
	float sum = 0.0;
	float amp = 0.6;
	float prev = 1.0;
	for (int i = 0; i < 6; i++) {
		float n = 1.0 - abs(value_noise(p) * 2.0 - 1.0);
		n = n * n;
		sum += n * amp * prev;
		prev = clamp(n * 1.25, 0.0, 1.0);
		p = mat2(vec2(1.7, -0.9), vec2(0.9, 1.7)) * p + vec2(3.7, 11.9);
		amp *= 0.55;
	}
	return sum;
}

float needles(vec2 p) {
	float best = 0.0;
	for (int k = 0; k < 3; k++) {
		float ang = float(k) * 1.0471976 + 0.35;
		vec2 dir = vec2(cos(ang), sin(ang));
		vec2 q = vec2(dot(p, dir), dot(p, vec2(-dir.y, dir.x))) * vec2(0.55, 3.0);
		float n = 1.0 - abs(value_noise(q + float(k) * 17.0) * 2.0 - 1.0);
		float n2 = 1.0 - abs(value_noise(q * 2.3 + float(k) * 5.0 + 40.0) * 2.0 - 1.0);
		best = max(best, pow(n, 14.0) + 0.6 * pow(n2, 16.0));
	}
	return best;
}

vec4 fetch(sampler2D tex, vec2 pix, vec2 sz) {
	return texture(tex, clamp(pix / sz, vec2(0.0), vec2(1.0)));
}

void fragment() {
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 pix = UV * sz;
	vec2 sk = vec2(mod(float(seed), 997.0) * 0.673 + 5.0, mod(float(seed), 991.0) * 0.419 + 1.0);
	float grow = grow_time > 0.0001 ? smoothstep(0.0, 1.0, max(clip_time, 0.0) / grow_time) : 1.0;
	float reach = clamp(amount, 0.0, 1.0) * grow;
	vec2 q = abs(UV - 0.5) * 2.0;
	vec2 q4 = q * q * q * q;
	float d_edge = 1.0 - pow(q4.x + q4.y, 0.25);
	vec2 p = pix / max(crystal_size * ps, 1.0) + sk;
	float n1 = fbm(p * 0.45);
	float front = reach * 0.62;
	float dm = d_edge + (n1 - 0.5) * 0.45;
	float m = (1.0 - smoothstep(front - 0.16, front + 0.05, dm)) * smoothstep(0.0, 0.06, reach);
	float reach_out = (1.0 - smoothstep(front, front + 0.16, dm)) * smoothstep(0.0, 0.06, reach);
	vec3 rgb;
	float a;
	if (reach_out <= 0.0005) {
		vec4 c = texture(TEXTURE, UV);
		a = c.a;
		rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	} else {
		vec2 warp = vec2(fbm(p * 0.8 + vec2(5.2, 1.3)), fbm(p * 0.8 + vec2(1.7, 9.2))) - 0.5;
		float cr = ridged(p * 1.1 + warp * 1.8);
		float nd = needles(p * 2.2 + warp * 0.8);
		float lines = max(smoothstep(0.7, 1.1, cr) * 0.7, smoothstep(0.35, 0.9, nd));
		vec2 off = warp * 2.0 * max(refraction, 0.0) * ps * m;
		float br = 4.0 * ps * m;
		vec4 c = fetch(TEXTURE, pix + off, sz) * 0.2;
		for (int i = 0; i < 8; i++) {
			float ang = float(i) * 0.78539816 + 0.3;
			c += fetch(TEXTURE, pix + off + vec2(cos(ang), sin(ang)) * br, sz) * 0.1;
		}
		a = c.a;
		rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
		float f = clamp(frost, 0.0, 1.0) * tint.a;
		float body = m * m * (0.4 + 0.3 * n1) * f;
		vec3 ice = tint.rgb * (0.78 + 0.3 * dot(rgb, LUMA));
		rgb = mix(rgb, ice, body);
		float crystal = lines * mix(reach_out * 0.8, 1.0, m) * f;
		rgb += (tint.rgb * 1.05 - rgb) * clamp(crystal * 0.85, 0.0, 1.0);
		vec2 gcell = floor(pix / max(5.0 * ps, 1.0));
		float glint = step(0.985, hash12(mod(gcell, 2048.0) + sk)) * m * f;
		rgb += vec3(glint * 0.6);
		a = max(a, clamp(body + crystal, 0.0, 1.0));
	}
	float cg = clamp(cold, 0.0, 1.0);
	vec3 icy = mix(rgb, vec3(dot(rgb, LUMA)), 0.35) * vec3(0.86, 0.97, 1.12) + vec3(0.0, 0.01, 0.03);
	rgb = mix(rgb, icy, cg);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
