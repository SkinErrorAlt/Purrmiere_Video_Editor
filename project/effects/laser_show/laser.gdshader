shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform int emitters : hint_range(1, 4) = 2;
uniform int placement = 0;
uniform int beams : hint_range(1, 16) = 8;
uniform int palette = 0;
uniform float fan : hint_range(2.0, 140.0) = 55.0;
uniform float speed : hint_range(0.0, 3.0) = 0.6;
uniform float blink : hint_range(0.0, 8.0) = 1.5;
uniform float thickness : hint_range(0.5, 6.0) = 1.6;
uniform float glow : hint_range(0.0, 1.0) = 0.5;
uniform float haze : hint_range(0.0, 1.0) = 0.5;
uniform int seed = 11;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

vec3 hue(float h) {
	vec3 k = clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return k;
}

vec3 laser_colour(int i, int n) {
	if (palette == 1) {
		return vec3(1.0, 0.06, 0.05);
	}
	if (palette == 2) {
		return vec3(0.18, 0.32, 1.0);
	}
	if (palette == 3) {
		return hue(float(i) / float(max(n, 1)));
	}
	return vec3(0.12, 1.0, 0.2);
}

void fragment() {
	vec4 o = texture(TEXTURE, UV);
	vec2 size = max(tex_size, vec2(1.0));
	vec2 pp = UV * size;
	float ps = max(px_scale, 0.0001);
	float t = clip_time;
	vec2 sd = vec2(float(seed % 877) * 2.71, float(seed % 653) * 1.37);
	float fog = vnoise(UV * vec2(size.x / size.y, 1.0) * 3.0 + sd + vec2(t * 0.07, -t * 0.03)) * 0.6 + vnoise(UV * vec2(size.x / size.y, 1.0) * 8.0 + sd * 1.3 + vec2(-t * 0.12, t * 0.05)) * 0.4;
	float hz = mix(1.0, 0.35 + 1.3 * fog, clamp(haze, 0.0, 1.0));
	float th = max(thickness * ps, 0.35);
	float gw = clamp(glow, 0.0, 1.0);
	int ne = clamp(emitters, 1, 4);
	int nb = clamp(beams, 1, 16);
	vec3 sum = vec3(0.0);
	for (int e = 0; e < 4; e++) {
		if (e >= ne) {
			break;
		}
		float fe = float(e);
		float h1 = hash12(vec2(fe * 5.13, 1.7) + sd);
		float h2 = hash12(vec2(fe * 3.71, 9.1) + sd);
		bool bottom = placement == 1 || (placement == 2 && e % 2 == 1);
		float ex = (fe + 0.5) / float(ne);
		vec2 s = vec2(ex * size.x, bottom ? size.y + 2.0 * ps : -2.0 * ps);
		float sweep = radians(28.0) * sin(t * speed * (1.1 + 0.5 * h1) + h2 * 6.2831853);
		float centre = (0.5 - ex) * 0.7 + sweep;
		float open = 0.55 + 0.45 * sin(t * speed * 0.8 * (0.8 + 0.4 * h2) + h1 * 6.2831853);
		float spread = radians(fan) * open;
		for (int j = 0; j < 16; j++) {
			if (j >= nb) {
				break;
			}
			float fj = float(j);
			float th_j = centre + (nb > 1 ? spread * (fj / float(nb - 1) - 0.5) : 0.0);
			vec2 dir = vec2(sin(th_j), bottom ? -cos(th_j) : cos(th_j));
			vec2 v = pp - s;
			float a = dot(v, dir);
			if (a <= 0.0) {
				continue;
			}
			float on = 1.0;
			if (blink > 0.0) {
				float slot = floor(t * blink + hash12(vec2(fe, fj) + sd) * 3.0);
				on = step(0.3, hash12(vec2(slot * 1.31 + fe * 17.0, fj * 7.7) + sd));
			}
			if (on <= 0.0) {
				continue;
			}
			float dist = abs(v.x * dir.y - v.y * dir.x);
			float core = clamp(th * 0.5 + 0.5 - dist, 0.0, 1.0) * min(th, 1.0) / max(min(th, 1.0), 0.35);
			float halo = exp(-dist / (th * 1.5 + 1.5 * ps)) * 0.55 + exp(-dist / (22.0 * ps)) * 0.12;
			float fade = exp(-a / (size.y * 2.2));
			float sparkle = 0.0;
			if (dist < 14.0 * ps) {
				float sn = vnoise(vec2(a / (6.0 * ps) + fj * 31.0 + fe * 7.0, t * 2.5 + fj));
				sparkle = pow(sn, 10.0) * 6.0 * clamp(haze, 0.0, 1.0) * exp(-dist / (3.0 * ps));
			}
			vec3 col = laser_colour(e * nb + j, ne * nb);
			sum += col * (core * 1.8 + (halo * gw * hz + sparkle) * 1.0) * fade;
		}
	}
	vec3 light = 1.0 - exp(-sum * 1.4);
	vec3 rgb = o.rgb + light * o.a;
	COLOR = vec4(min(rgb, vec3(o.a)), o.a);
}
