shader_type canvas_item;
render_mode blend_disabled;

uniform float received : hint_range(0.0, 1.0) = 1.0;
uniform int mode : hint_range(0, 1) = 0;
uniform int lines : hint_range(120, 496) = 256;
uniform float slant : hint_range(-1.0, 1.0) = 0.12;
uniform float signal : hint_range(0.0, 1.0) = 0.72;
uniform float fading : hint_range(0.0, 1.0) = 0.4;
uniform float carrier : hint_range(0.0, 1.0) = 0.25;
uniform float slips : hint_range(0.0, 1.0) = 0.3;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size;
uniform float px_scale;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float line_noise(float l, float x, float ch) {
	float n = 170.0;
	float fx = x * n;
	float i = floor(fx);
	float f = fx - i;
	float a = hash12(vec2(i, l * 3.0 + ch * 977.0 + float(seed)));
	float b = hash12(vec2(i + 1.0, l * 3.0 + ch * 977.0 + float(seed)));
	float v = mix(a, b, f * f * (3.0 - 2.0 * f));
	float spike = step(0.985, hash12(vec2(floor(x * 110.0), l + ch * 31.0 + float(seed) * 1.3)));
	return (v - 0.5) * 2.0 + spike * (hash12(vec2(l, ch + 5.0)) > 0.5 ? 2.5 : -2.5);
}

vec3 fetch(sampler2D tex, vec2 uv, float px) {
	vec3 c = vec3(0.0);
	float w = 0.0;
	for (int i = -2; i <= 2; i++) {
		float k = i == 0 ? 0.36 : (abs(i) == 1 ? 0.24 : 0.08);
		vec4 s = texture(tex, vec2(fract(uv.x + float(i) * px), clamp(uv.y, 0.0, 1.0)));
		c += (s.a > 0.0001 ? s.rgb / s.a : vec3(0.0)) * k;
		w += k;
	}
	return c / w;
}

void fragment() {
	vec4 here = texture(TEXTURE, UV);
	float a = here.a;
	vec2 size = max(tex_size, vec2(1.0));
	float nl = float(lines);
	float l = floor(UV.y * nl);
	float lv = l / nl;
	float x = UV.x;
	float shift = slant * lv;
	int count = int(floor(slips * 6.0 + 0.0001));
	for (int i = 0; i < 6; i++) {
		if (i >= count) {
			break;
		}
		float at = floor(hash12(vec2(float(i) * 7.1, 3.0 + float(seed))) * nl);
		float amt = (hash12(vec2(float(i) * 3.3, 11.0 + float(seed))) - 0.5) * 0.3;
		shift += step(at, l) * amt;
	}
	float xs = fract(x - shift);
	float porch = 0.022;
	float in_porch = step(xs, porch);
	vec2 suv = vec2(fract((xs - porch) / (1.0 - porch)), (l + 0.5) / nl);
	float hpx = 1.6 / 320.0;
	float noise_level = pow(1.0 - signal, 1.4) * 0.9;
	float band = smoothstep(0.55, 0.95, hash12(vec2(floor(l / 6.0), 41.0 + float(seed))) * 0.6 + hash12(vec2(floor(l / 23.0), 43.0 + float(seed))) * 0.4);
	float fade_l = noise_level + fading * band * (0.45 + 0.8 * (1.0 - signal));
	vec3 rgb = vec3(0.0);
	if (mode == 0) {
		float dx = 1.0 / 320.0;
		vec3 cg = fetch(TEXTURE, suv, hpx);
		vec3 cb = fetch(TEXTURE, suv + vec2(dx * 0.7, 0.0), hpx);
		vec3 cr = fetch(TEXTURE, suv - vec2(dx * 0.7, 0.0), hpx);
		rgb = vec3(cr.r, cg.g, cb.b);
		vec3 nz = vec3(line_noise(l, xs, 0.0), line_noise(l, xs, 1.0), line_noise(l, xs, 2.0));
		vec3 chan_fade = vec3(hash12(vec2(l, 61.0)), hash12(vec2(l, 62.0)), hash12(vec2(l, 63.0)));
		rgb += nz * fade_l * (0.25 + 0.75 * chan_fade) * 0.45;
		float k = 6.2832 * (xs * 41.0 + l * 0.37);
		vec3 tone = vec3(sin(k + 2.1), sin(k), sin(k + 4.2));
		rgb += tone * carrier * 0.16;
	} else {
		vec3 c = fetch(TEXTURE, suv, hpx);
		float y = dot(c, vec3(0.299, 0.587, 0.114));
		float pair = floor(l / 2.0) * 2.0;
		vec3 cc = fetch(TEXTURE, vec2(suv.x, (pair + 1.0) / nl), hpx * 2.0);
		float ry = cc.r - dot(cc, vec3(0.299, 0.587, 0.114));
		float by = cc.b - dot(cc, vec3(0.299, 0.587, 0.114));
		y += line_noise(l, xs, 0.0) * fade_l * 0.4;
		float chroma_noise = line_noise(pair, xs * 0.5, 1.0) * fade_l * 0.5;
		if (mod(l, 2.0) < 1.0) {
			ry += chroma_noise;
		} else {
			by += chroma_noise;
		}
		float k = 6.2832 * (xs * 41.0 + l * 0.37);
		y += sin(k) * carrier * 0.12;
		rgb = vec3(y + ry, y - 0.194 * by - 0.509 * ry, y + by);
	}
	float lp = fract(UV.y * nl);
	rgb *= 0.94 + 0.06 * smoothstep(0.0, 0.25, lp) * smoothstep(1.0, 0.75, lp);
	rgb = mix(rgb, vec3(0.03, 0.03, 0.035) + vec3(line_noise(l, xs, 4.0)) * 0.02, in_porch);
	float now_line = floor(received * nl);
	float now_x = fract(received * nl);
	float done = l < now_line ? 1.0 : (l > now_line ? 0.0 : step(x, now_x));
	if (received >= 1.0) {
		done = 1.0;
	}
	vec3 waiting = vec3(0.02, 0.02, 0.025);
	rgb = mix(waiting, rgb, done);
	COLOR = vec4(clamp(rgb, 0.0, 1.0) * a, a);
}
