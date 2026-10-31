shader_type canvas_item;
render_mode blend_disabled;

uniform float amount : hint_range(0.0, 1.0) = 0.5;
uniform float size : hint_range(0.5, 30.0) = 4.0;
uniform float speed : hint_range(0.0, 4.0) = 1.0;
uniform float wind : hint_range(-2.0, 2.0) = 0.3;
uniform float sway : hint_range(0.0, 1.0) = 0.5;
uniform float blur_far : hint_range(0.0, 1.0) = 0.5;
uniform vec4 colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform int seed : hint_range(0, 9999) = 0;
uniform int blend : hint_range(0, 6) = 6;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 hash32(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yzz) * p3.zyx);
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

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec2 pos = UV * sz;
	vec2 skey = floor(hash22(vec2(float(seed) * 0.7123 + 3.1, 11.7)) * 997.0);
	float clear = 1.0;
	for (int li = 0; li < 4; li++) {
		float fl = float(li);
		float depth = 1.0 - fl * 0.2;
		float farness = fl / 3.0;
		float r = max(size * ps * depth, 0.5);
		float soft = mix(1.0, 1.0 + r * 1.5, clamp(blur_far, 0.0, 1.0) * farness);
		float cell = max((r + soft) * 9.0, 6.0);
		vec2 vel = vec2(wind * 0.12, 0.15 * speed) * sz.y * (0.35 + 0.65 * depth);
		vec2 q = pos - mod(vel * clip_time, vec2(cell * 1024.0));
		vec2 g = q / cell + hash22(vec2(fl * 3.7, 1.9) + skey) * 50.0;
		vec2 cid = floor(g);
		vec2 f = g - cid;
		vec3 h = hash32(mod(cid, vec2(1024.0)) + vec2(fl * 1031.0, 0.0) + skey);
		if (h.x < amount) {
			vec2 ctr = vec2(0.3 + 0.4 * h.y, 0.3 + 0.4 * h.z);
			ctr.x += clamp(sway, 0.0, 1.0) * 0.18 * sin(clip_time * (0.7 + 0.8 * h.y) + 6.2831853 * h.z);
			float d = length((f - ctr) * cell);
			float flake = 1.0 - smoothstep(r - 0.5 * soft, r + 0.5 * soft, d);
			flake *= (0.55 + 0.45 * depth) * clamp(r / 0.5, 0.0, 1.0);
			clear *= 1.0 - clamp(flake, 0.0, 1.0);
		}
	}
	float cov = (1.0 - clear) * colour.a;
	COLOR = mix_in(rgb, a, colour.rgb, cov, blend, strength);
}
