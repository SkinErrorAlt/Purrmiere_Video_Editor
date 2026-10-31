shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 start_point = vec2(0.15, 0.2);
uniform vec2 end_point = vec2(0.8, 0.75);
uniform int bolts : hint_range(1, 4) = 2;
uniform float jaggedness : hint_range(0.0, 1.0) = 0.5;
uniform float forks : hint_range(0.0, 1.0) = 0.5;
uniform float width : hint_range(0.5, 12.0) = 2.2;
uniform float glow : hint_range(0.0, 1.0) = 0.6;
uniform vec4 colour : source_color = vec4(0.62, 0.72, 1.0, 1.0);
uniform float rate : hint_range(0.0, 30.0) = 10.0;
uniform float flash : hint_range(0.0, 1.0) = 0.15;
uniform int seed : hint_range(0, 9999) = 0;
uniform int blend : hint_range(0, 6) = 4;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise1(float x, float key) {
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	float w = mod(i, 1024.0);
	return mix(hash12(vec2(w, key)), hash12(vec2(w + 1.0, key)), u) * 2.0 - 1.0;
}

float fbm1(float x, float key) {
	float sum = 0.0;
	float amp = 0.55;
	float fx = x;
	for (int i = 0; i < 5; i++) {
		sum += noise1(fx, key + float(i) * 13.1) * amp;
		fx *= 2.1;
		amp *= 0.5;
	}
	return sum;
}

vec3 blend_colour(vec3 base, vec3 over, int how) {
	if (how == 1) { return base * over; }
	if (how == 2) { return 1.0 - (1.0 - base) * (1.0 - over); }
	if (how == 3) { return mix(2.0 * base * over, 1.0 - 2.0 * (1.0 - base) * (1.0 - over), step(0.5, base)); }
	if (how == 4) { return base + over; }
	if (how == 5) { return (1.0 - 2.0 * over) * base * base + 2.0 * over * base; }
	return over;
}

vec4 mix_in(vec3 pic, float pic_a, vec3 gen, float cov, int how, float amt) {
	vec3 pc = clamp(pic, 0.0, 1.0);
	vec3 g = clamp(gen, 0.0, 1.0);
	float s = clamp(amt, 0.0, 1.0);
	float k = clamp(cov, 0.0, 1.0);
	if (how == 0) {
		return mix(vec4(pc * pic_a, pic_a), vec4(g * k, k), s);
	}
	if (how == 6) {
		float w = k * s;
		return vec4(g * w + pc * pic_a * (1.0 - w), w + pic_a * (1.0 - w));
	}
	vec3 o = mix(pc, blend_colour(pc, g, how), k * s);
	return vec4(clamp(o, 0.0, 1.0) * pic_a, pic_a);
}

float bolt_offset(float t, float len, float key) {
	float tc = clamp(t, 0.0, 1.0);
	float env = pow(max(sin(3.14159265 * tc), 0.0), 0.7);
	return fbm1(tc * 7.0 + key * 0.37, key) * clamp(jaggedness, 0.0, 1.0) * len * 0.22 * env;
}

vec2 bolt(vec2 pix, vec2 a, vec2 b, float key, float w, float ps) {
	vec2 ab = b - a;
	float len = length(ab);
	if (len < 1.0) {
		return vec2(0.0);
	}
	vec2 dir = ab / len;
	vec2 nrm = vec2(-dir.y, dir.x);
	float t = dot(pix - a, dir) / len;
	float s = dot(pix - a, nrm);
	float tc = clamp(t, 0.0, 1.0);
	float off = bolt_offset(t, len, key);
	float dist = length(vec2((t - tc) * len, s - off));
	float core = 1.0 - smoothstep(w * 0.5, w * 0.5 + ps, dist);
	float halo = exp(-dist / max(w * 5.0, 1.0));
	return vec2(core, halo);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 pix = UV * sz;
	float beat = rate > 0.0 ? clip_time * rate : 0.0;
	float strike = mod(floor(beat), 4096.0);
	float env = rate > 0.0 ? 1.0 - 0.55 * fract(beat) : 1.0;
	float sk = mod(float(seed), 997.0) * 3.17 + strike * 1.37;
	vec2 pa = start_point * sz;
	vec2 pb = end_point * sz;
	float w = max(width, 0.1) * ps;
	float core = 0.0;
	float halo = 0.0;
	for (int i = 0; i < 4; i++) {
		if (i >= bolts) {
			break;
		}
		float key = sk + float(i) * 29.3;
		vec2 main_bolt = bolt(pix, pa, pb, key, w * (i == 0 ? 1.0 : 0.7), ps);
		core = max(core, main_bolt.x);
		halo += main_bolt.y * (i == 0 ? 1.0 : 0.6);
		vec2 ab = pb - pa;
		float len = length(ab);
		if (len >= 1.0) {
			vec2 dir = ab / len;
			vec2 nrm = vec2(-dir.y, dir.x);
			for (int f = 0; f < 2; f++) {
				float h1 = hash12(vec2(key, float(f) + 3.0));
				float h2 = hash12(vec2(key, float(f) + 7.0));
				if (h1 > clamp(forks, 0.0, 1.0)) {
					continue;
				}
				float tf = 0.18 + 0.6 * h2;
				vec2 sp = pa + dir * tf * len + nrm * bolt_offset(tf, len, key);
				float turn = (f == 0 ? 1.0 : -1.0) * (0.35 + 0.6 * h1);
				vec2 fd = vec2(dir.x * cos(turn) - dir.y * sin(turn), dir.x * sin(turn) + dir.y * cos(turn));
				vec2 ep = sp + fd * len * (0.15 + 0.25 * h2);
				vec2 fb = bolt(pix, sp, ep, key + 51.0 + float(f) * 7.0, w * 0.55, ps);
				core = max(core, fb.x * 0.85);
				halo += fb.y * 0.45;
			}
		}
	}
	float gl = clamp(glow, 0.0, 1.0);
	float intensity = (core + halo * gl * 0.9) * env * colour.a;
	vec3 gen = mix(colour.rgb, vec3(1.0), clamp(core * 0.75, 0.0, 1.0));
	rgb = rgb + (1.0 - rgb) * colour.rgb * clamp(flash, 0.0, 1.0) * env * 0.35 * colour.a * clamp(strength, 0.0, 1.0);
	COLOR = mix_in(rgb, a, gen, clamp(intensity, 0.0, 1.0), blend, strength);
}
