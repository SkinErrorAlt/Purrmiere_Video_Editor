shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float clip_time = 0.0;
uniform int shape = 0;
uniform float size : hint_range(0.02, 0.5) = 0.09;
uniform float shape_size : hint_range(0.05, 1.0) = 0.5;
uniform float angle : hint_range(-180.0, 180.0) = 15.0;
uniform vec4 colour_a : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 colour_b : source_color = vec4(0.98, 0.44, 0.6, 1.0);
uniform float scroll_angle : hint_range(-180.0, 180.0) = 135.0;
uniform float speed : hint_range(0.0, 3.0) = 0.4;
uniform float softness : hint_range(0.0, 1.0) = 0.0;
uniform int blend : hint_range(0, 7) = 0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

vec3 blend_colour(vec3 base, vec3 over_c, int how) {
	if (how == 1) { return base * over_c; }
	if (how == 2) { return 1.0 - (1.0 - base) * (1.0 - over_c); }
	if (how == 3) { return mix(2.0 * base * over_c, 1.0 - 2.0 * (1.0 - base) * (1.0 - over_c), step(0.5, base)); }
	if (how == 4) { return base + over_c; }
	if (how == 5) { return (1.0 - 2.0 * over_c) * base * base + 2.0 * over_c * base; }
	return over_c;
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
	if (how == 7) {
		float w = k * s * (1.0 - pic_a);
		return vec4(pc * pic_a + g * w, pic_a + w);
	}
	vec3 o = mix(pc, blend_colour(pc, g, how), k * s);
	return vec4(clamp(o, 0.0, 1.0) * pic_a, pic_a);
}

float box_sd(vec2 p, vec2 b) {
	vec2 q = abs(p) - b;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
}

float tri_sd(vec2 p, float r) {
	float k = sqrt(3.0);
	p.x = abs(p.x) - r;
	p.y = p.y + r / k;
	if (p.x + k * p.y > 0.0) {
		p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
	}
	p.x -= clamp(p.x, -2.0 * r, 0.0);
	return -length(p) * sign(p.y);
}

float star_sd(vec2 p, float r, float rf) {
	vec2 k1 = vec2(0.809016994375, -0.587785252292);
	vec2 k2 = vec2(-k1.x, k1.y);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

void fragment() {
	vec4 pic = texture(TEXTURE, UV);
	float asp = max(tex_size.x, 1.0) / max(tex_size.y, 1.0);
	vec2 p = (UV - 0.5) * vec2(asp, 1.0);
	float a = radians(angle);
	vec2 r = vec2(cos(a) * p.x + sin(a) * p.y, -sin(a) * p.x + cos(a) * p.y);
	float sa = radians(scroll_angle);
	vec2 dir = vec2(sin(sa), -cos(sa));
	vec2 dir_r = vec2(cos(a) * dir.x + sin(a) * dir.y, -sin(a) * dir.x + cos(a) * dir.y);
	vec2 g = r / max(size, 0.001) - dir_r * clip_time * clamp(speed, 0.0, 3.0);
	float aa = max(length(fwidth(g)) * 0.7071, 0.00001) + clamp(softness, 0.0, 1.0) * 0.3;
	float s = clamp(shape_size, 0.05, 1.0);
	float d = 1.0;
	if (shape == 0 || shape == 9) {
		vec2 gg = g;
		if (mod(floor(gg.y), 2.0) > 0.5) {
			gg.x += 0.5;
		}
		vec2 c = fract(gg) - 0.5;
		d = shape == 0 ? length(c) - s * 0.5 : star_sd(vec2(c.x, -c.y), s * 0.5, 0.45);
	} else if (shape == 1) {
		float f = sin(3.14159265 * g.x) * sin(3.14159265 * g.y);
		d = -f / max(length(fwidth(g)) * 3.14159265 * 0.7071, 0.00001) * aa;
	} else if (shape == 2) {
		float y = g.y + abs(fract(g.x) - 0.5);
		d = (abs(fract(y) - 0.5) - s * 0.25) * 0.7071;
	} else if (shape == 3) {
		float y = g.y + 0.25 * sin(6.2831853 * g.x);
		d = (abs(fract(y) - 0.5) - s * 0.25) * 0.8;
	} else if (shape == 4) {
		vec2 gg = g;
		if (mod(floor(gg.y), 2.0) > 0.5) {
			gg.x += 0.5;
		}
		vec2 c = fract(gg) - 0.5;
		d = tri_sd(vec2(c.x, -c.y + 0.06), s * 0.5);
	} else if (shape == 5) {
		vec2 c = fract(g) - 0.5;
		d = (abs(c.x) + abs(c.y) - s * 0.5) * 0.7071;
	} else if (shape == 6) {
		vec2 c = fract(g) - 0.5;
		d = min(box_sd(c, vec2(s * 0.5, s * 0.14)), box_sd(c, vec2(s * 0.14, s * 0.5)));
	} else if (shape == 7) {
		vec2 rr = vec2(1.0, 1.7320508);
		vec2 h = rr * 0.5;
		vec2 ha = mod(g, rr) - h;
		vec2 hb = mod(g - h, rr) - h;
		vec2 gv = dot(ha, ha) < dot(hb, hb) ? ha : hb;
		vec2 ag = abs(gv);
		float hd = max(dot(ag, normalize(vec2(1.0, 1.7320508))), ag.x);
		d = hd - 0.5 * mix(0.3, 0.97, s);
	} else {
		vec2 f = abs(fract(g) - 0.5);
		float thin = 0.5 - max(f.x, f.y);
		float lw = s * 0.06 + 0.01;
		vec2 f5 = abs(fract(g / 5.0) - 0.5) * 5.0;
		float thick = 2.5 - max(f5.x, f5.y);
		d = min(thin - lw, thick - lw * 2.2);
	}
	float cov = clamp(0.5 - d / aa, 0.0, 1.0);
	vec3 gen = mix(colour_b.rgb, colour_a.rgb, cov * colour_a.a);
	float gen_a = mix(colour_b.a, 1.0, cov * colour_a.a);
	vec3 rgb = pic.a > 0.0001 ? pic.rgb / pic.a : vec3(0.0);
	COLOR = mix_in(rgb, pic.a, gen, gen_a, blend, strength);
}
