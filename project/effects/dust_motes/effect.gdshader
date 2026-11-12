shader_type canvas_item;
render_mode blend_disabled;

uniform float density : hint_range(0.0, 1.0) = 0.4;
uniform float size : hint_range(1.0, 20.0) = 4.0;
uniform int layers : hint_range(1, 4) = 3;
uniform float drift : hint_range(0.0, 1.0) = 0.3;
uniform float direction : hint_range(-180.0, 180.0) = -80.0;
uniform float sway : hint_range(0.0, 1.0) = 0.6;
uniform float softness : hint_range(0.0, 1.0) = 0.6;
uniform float twinkle : hint_range(0.0, 1.0) = 0.5;
uniform vec4 tint : source_color = vec4(1.0, 0.96, 0.88, 1.0);
uniform float in_light : hint_range(0.0, 1.0) = 0.6;
uniform int blend : hint_range(0, 6) = 4;
uniform float strength : hint_range(0.0, 1.0) = 0.75;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

vec4 hash42(vec2 p) {
	vec4 p4 = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	p4 += dot(p4, p4.wzxy + 33.33);
	return fract((p4.xxyz + p4.yzzw) * p4.zywx);
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
	float t = clip_time;
	vec2 pos = UV * sz;
	float sd = float(seed) * 1.37 + 7.0;
	float luma = dot(rgb, vec3(0.299, 0.587, 0.114));
	float lightgate = mix(1.0, 0.25 + 1.5 * luma, clamp(in_light, 0.0, 1.0));

	float ang = radians(direction);
	vec2 dir = vec2(cos(ang), -sin(ang));
	int nl = clamp(layers, 1, 4);
	float acc = 0.0;
	for (int li = 0; li < 4; li++) {
		if (li >= nl) {
			break;
		}
		float fl = float(li);
		float depth = 1.0 - fl * 0.26;
		float r = max(size * ps * (0.5 + 0.7 * depth), 0.5);
		float cell = max(r * 15.0, 5.0 * ps);
		vec2 vel = dir * drift * 0.12 * sz.y * (0.4 + 0.9 * depth);
		vec2 q = pos - mod(vel * t, vec2(cell * 2048.0));
		vec2 g = q / cell + hash42(vec2(fl * 5.1, 2.3) + sd).xy * 90.0;
		vec2 cid = floor(g);
		vec2 f = g - cid;
		vec4 h = hash42(mod(cid, 2048.0) + vec2(fl * 821.0, 0.0) + sd);
		if (h.x >= clamp(density, 0.0, 1.0) * 0.55) {
			continue;
		}
		vec2 ctr = 0.28 + 0.44 * h.yz;
		float sw = clamp(sway, 0.0, 1.0);
		ctr.x += sw * 0.1 * sin(t * (0.5 + 0.8 * h.y) + 6.2831853 * h.z);
		ctr.y += sw * 0.08 * sin(t * (0.7 + 0.6 * h.w) + 6.2831853 * h.y);
		vec2 local = (f - ctr) * cell;
		float dist = length(local);
		float edge = mix(r * 0.9, r * 0.25, clamp(softness, 0.0, 1.0));
		float disc = 1.0 - smoothstep(edge, r * 1.15, dist);
		float halo = exp(-dist / max(r * (1.2 + 2.0 * softness), 0.5)) * 0.55;
		float bright = (disc + halo) * (0.5 + 0.7 * depth);
		float tw = 0.55 + 0.45 * sin(t * (1.0 + 2.5 * h.w) + h.y * 33.0);
		bright *= mix(1.0, clamp(tw, 0.0, 1.0), clamp(twinkle, 0.0, 1.0));
		acc += bright;
	}
	acc *= lightgate * tint.a;
	float cov = clamp(acc, 0.0, 1.0);
	vec3 gen = tint.rgb;
	COLOR = mix_in(rgb, a, gen, cov, blend, strength);
}
