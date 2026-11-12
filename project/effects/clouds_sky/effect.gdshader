shader_type canvas_item;
render_mode blend_disabled;

uniform int style : hint_range(0, 3) = 0;
uniform float coverage : hint_range(0.0, 1.0) = 0.55;
uniform float softness : hint_range(0.0, 1.0) = 0.45;
uniform float detail : hint_range(0.0, 1.0) = 0.6;
uniform float height : hint_range(0.0, 1.0) = 0.72;
uniform float depth : hint_range(0.0, 1.0) = 0.6;
uniform vec2 sun = vec2(0.72, 0.3);
uniform float sun_size : hint_range(0.0, 1.0) = 0.35;
uniform vec4 sun_colour : source_color = vec4(1.0, 0.93, 0.78, 1.0);
uniform vec4 sky_colour : source_color = vec4(0.25, 0.47, 0.85, 1.0);
uniform vec4 haze_colour : source_color = vec4(0.78, 0.84, 0.92, 1.0);
uniform float wind : hint_range(-2.0, 2.0) = 0.35;
uniform float drift : hint_range(0.0, 4.0) = 1.0;
uniform float brightness : hint_range(0.0, 2.0) = 1.0;
uniform int blend : hint_range(0, 6) = 6;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = h21(i);
	float b = h21(i + vec2(1.0, 0.0));
	float c = h21(i + vec2(0.0, 1.0));
	float d = h21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p, int steps) {
	float s = 0.0;
	float amp = 0.5;
	mat2 m = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6));
	for (int i = 0; i < 7; i++) {
		if (i >= steps) {
			break;
		}
		s += amp * vnoise(p);
		p = m * p;
		amp *= 0.5;
	}
	return s;
}

vec3 blend_colour(vec3 base, vec3 over, int how) {
	if (how == 1) {
		return base * over;
	}
	if (how == 2) {
		return 1.0 - (1.0 - base) * (1.0 - clamp(over, 0.0, 1.0));
	}
	if (how == 3) {
		vec3 lo = 2.0 * base * over;
		vec3 hi = 1.0 - 2.0 * (1.0 - base) * (1.0 - clamp(over, 0.0, 1.0));
		return mix(lo, hi, step(vec3(0.5), base));
	}
	if (how == 4) {
		return base + over;
	}
	if (how == 5) {
		vec3 o = clamp(over, 0.0, 1.0);
		vec3 lo = base - (1.0 - 2.0 * o) * base * (1.0 - base);
		vec3 hi = base + (2.0 * o - 1.0) * (sqrt(max(base, vec3(0.0))) - base);
		return mix(lo, hi, step(vec3(0.5), o));
	}
	return clamp(over, 0.0, 1.0);
}

vec4 mix_in(vec3 pic, float pic_a, vec3 gen, float cov, int how, float amt) {
	vec3 pc = clamp(pic, 0.0, 1.0);
	vec3 g = clamp(gen, 0.0, 4.0);
	float s = clamp(amt, 0.0, 1.0);
	float k = clamp(cov, 0.0, 1.0);
	if (how == 0) {
		return mix(vec4(pc * pic_a, pic_a), vec4(clamp(g, 0.0, 1.0) * k, k), s);
	}
	if (how == 6) {
		float w = k * s;
		return vec4(clamp(g, 0.0, 1.0) * w + pc * pic_a * (1.0 - w), w + pic_a * (1.0 - w));
	}
	vec3 o = mix(pc, blend_colour(pc, g, how), k * s);
	return vec4(clamp(o, 0.0, 1.0) * pic_a, pic_a);
}

float cloud_field(vec2 q, float sd, float warp, int octaves, float lift) {
	vec2 w = vec2(fbm(q * 1.7 + vec2(sd, 0.0), 4), fbm(q * 1.7 + vec2(5.2 - sd, 1.3), 4));
	vec2 p = q + (w - 0.5) * warp;
	float base = fbm(p + vec2(sd * 0.7, 0.0), octaves);
	return clamp(base * (1.0 + lift) - lift * 0.5, 0.0, 1.0);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 rgb = a > 0.0001 ? c.rgb / a : vec3(0.0);
	vec2 sz = max(tex_size, vec2(1.0));
	float ar = sz.x / sz.y;
	float sd = float(seed) * 1.31 + 3.7;
	float t = clip_time * drift;

	float horizon = clamp(height, 0.001, 0.999);
	float up = clamp((horizon - UV.y) / max(horizon, 0.001), 0.0, 1.0);

	vec3 zenith = sky_colour.rgb;
	vec3 haze = haze_colour.rgb;
	float sky_mix = pow(up, mix(0.55, 1.6, clamp(depth, 0.0, 1.0)));
	vec3 sky = mix(haze, zenith, sky_mix);

	vec2 sunp = vec2(sun.x, sun.y);
	float sun_d = length((UV - sunp) * vec2(ar, 1.0));
	float sun_r = 0.012 + 0.05 * clamp(sun_size, 0.0, 1.0);
	float disc = 1.0 - smoothstep(sun_r * 0.85, sun_r, sun_d);
	float glow = pow(clamp(1.0 - sun_d / max(sun_r * 14.0, 0.001), 0.0, 1.0), 3.0);
	sky += sun_colour.rgb * (glow * 0.55 + disc * 2.2) * sun_colour.a;

	float flat_y = 1.0 / max(up + 0.055, 0.055);
	vec2 q = vec2((UV.x - 0.5) * ar * flat_y * 0.55, flat_y * 0.42);
	q += vec2(t * wind * 0.5, -t * wind * 0.08);

	int octaves = 4 + int(round(clamp(detail, 0.0, 1.0) * 2.0));
	float warp = 0.3 + 0.55 * clamp(detail, 0.0, 1.0);
	float scale = 1.0;
	float lift = 0.0;
	float base_dark = 0.22;
	float top_light = 1.0;
	if (style == 1) {
		scale = 0.55;
		lift = 0.55;
		base_dark = 0.42;
		top_light = 0.6;
	} else if (style == 2) {
		scale = 0.8;
		lift = 0.3;
		base_dark = 0.62;
		top_light = 0.85;
	} else if (style == 3) {
		scale = 2.6;
		lift = -0.25;
		base_dark = 0.08;
		top_light = 1.1;
	}

	float field = cloud_field(q * scale, sd, warp, octaves, lift);
	float cover = clamp(coverage, 0.0, 1.0);
	float edge = mix(0.03, 0.38, clamp(softness, 0.0, 1.0));
	float thr = mix(0.78, 0.26, cover);
	float den = smoothstep(thr, thr + edge, field);

	float step_px = 0.012 + 0.02 * clamp(softness, 0.0, 1.0);
	vec2 to_sun = normalize(vec2((sunp.x - UV.x) * ar, sunp.y - UV.y) + vec2(0.0001, 0.0001));
	float lit_field = cloud_field((q + vec2(to_sun.x, -to_sun.y) * step_px * 9.0) * scale, sd, warp, octaves, lift);
	float lit = smoothstep(thr, thr + edge, lit_field);
	float shade = clamp(den - lit, -1.0, 1.0);

	vec3 cloud_lit = mix(vec3(0.92, 0.94, 0.97), sun_colour.rgb, 0.55) * top_light;
	vec3 cloud_dark = mix(vec3(0.42, 0.45, 0.52), haze, 0.35) * mix(1.0, 0.55, base_dark);
	float light_mix = clamp(0.62 - shade * 1.5 + glow * 0.4, 0.0, 1.0);
	vec3 cloud = mix(cloud_dark, cloud_lit, light_mix);
	cloud += sun_colour.rgb * pow(clamp(1.0 - sun_d / max(sun_r * 10.0, 0.001), 0.0, 1.0), 2.0) * den * 0.25;

	float thin = mix(1.0, 0.45, float(style == 3));
	float cov_px = den * thin;
	vec3 out_rgb = mix(sky, cloud, cov_px);
	out_rgb = mix(out_rgb, haze, (1.0 - up) * 0.28);
	out_rgb *= brightness;

	float lip = 0.004 + 0.02 * clamp(softness, 0.0, 1.0);
	float shown = smoothstep(horizon + lip, horizon - lip, UV.y);

	COLOR = mix_in(rgb, a, out_rgb, shown, blend, strength);
}
