shader_type canvas_item;
render_mode blend_disabled;

uniform int placement : hint_range(0, 1) = 0;
uniform float threshold : hint_range(0.0, 1.0) = 0.7;
uniform float density : hint_range(0.0, 1.0) = 0.2;
uniform float size : hint_range(2.0, 200.0) = 40.0;
uniform float size_spread : hint_range(0.0, 1.0) = 0.6;
uniform float twinkle : hint_range(0.0, 10.0) = 1.2;
uniform int shape : hint_range(0, 3) = 0;
uniform float turn : hint_range(0.0, 360.0) = 25.0;
uniform vec4 colour : source_color = vec4(1.0, 0.96, 0.85, 1.0);
uniform float colour_spread : hint_range(0.0, 1.0) = 0.2;
uniform int seed : hint_range(0, 9999) = 0;
uniform int blend : hint_range(0, 6) = 4;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

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

float star(vec2 d, float s, float ps) {
	float r = length(d) / s;
	float core = exp(-r * r * 60.0) * 1.3 + exp(-r * r * 9.0) * 0.3;
	if (shape == 3) {
		return core + exp(-r * r * 3.0) * 0.25;
	}
	int pairs = shape == 0 ? 2 : (shape == 1 ? 3 : 4);
	float w = max(0.7 * ps, s * 0.035);
	float rays = 0.0;
	for (int i = 0; i < 4; i++) {
		if (i >= pairs) {
			break;
		}
		float th = float(i) * 3.14159265 / float(pairs);
		vec2 dir = vec2(cos(th), sin(th));
		float reach = (shape == 2 && i % 2 == 1) ? s * 0.55 : s;
		float along = abs(dot(d, dir));
		float perp = abs(dot(d, vec2(-dir.y, dir.x)));
		float taper = max(1.0 - along / reach, 0.0);
		rays += exp(-perp / (w * (0.4 + 0.6 * taper))) * taper * taper * taper;
	}
	return core + rays * 0.9;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 size_px = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float base = max(size * ps, 1.0);
	float cell = max(base * 1.5, 4.0);
	vec2 pix = UV * size_px;
	vec2 cid = floor(pix / cell);
	vec2 sk = vec2(mod(float(seed), 997.0) * 1.311 + 2.0, mod(float(seed), 991.0) * 0.557 + 13.0);
	vec3 glow = vec3(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 id = cid + vec2(float(x), float(y));
			vec4 h = hash42(mod(id, 1024.0) + sk);
			if (h.x > density) {
				continue;
			}
			vec2 ctr = (id + 0.2 + 0.6 * h.yz) * cell;
			float s = base * mix(1.0, 0.3 + 0.7 * h.w, clamp(size_spread, 0.0, 1.0));
			float b = 1.0;
			if (twinkle > 0.0) {
				float tw = sin(6.2831853 * (clip_time * twinkle * (0.6 + 0.8 * h.y) + h.z));
				b = pow(max(tw, 0.0), 1.5);
			}
			if (placement == 1) {
				vec4 under = texture(TEXTURE, clamp(ctr / size_px, vec2(0.0), vec2(1.0)));
				float lu = under.a > 0.0001 ? dot(under.rgb / under.a, LUMA) : 0.0;
				b *= smoothstep(threshold - 0.08, threshold + 0.08, lu);
			}
			if (b <= 0.001) {
				continue;
			}
			vec2 d = pix - ctr;
			float ang = radians(turn) * clip_time * (h.w > 0.5 ? 1.0 : -1.0) + h.x * 6.2831853;
			float cs = cos(ang);
			float sn = sin(ang);
			d = vec2(cs * d.x - sn * d.y, sn * d.x + cs * d.y);
			vec3 hue = 0.5 + 0.5 * cos(6.2831853 * (h.w * 3.0 + vec3(0.0, 0.33, 0.67)));
			vec3 col = mix(colour.rgb, hue, clamp(colour_spread, 0.0, 1.0));
			glow += col * star(d, s, ps) * b;
		}
	}
	glow *= colour.a;
	float peak = max(glow.r, max(glow.g, glow.b));
	vec3 gen = peak > 0.0001 ? glow / peak : colour.rgb;
	float cov = clamp(peak, 0.0, 1.0);
	COLOR = mix_in(rgb, a, gen, cov, blend, strength);
}
