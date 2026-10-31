shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;
uniform float clip_time = 0.0;
uniform float horizon : hint_range(0.2, 0.9) = 0.56;
uniform float speed : hint_range(0.0, 4.0) = 0.8;
uniform vec4 grid_colour : source_color = vec4(1.0, 0.2, 0.85, 1.0);
uniform float line_width : hint_range(0.5, 6.0) = 1.6;
uniform float glow : hint_range(0.0, 1.0) = 0.6;
uniform float sun_size : hint_range(0.0, 0.5) = 0.22;
uniform vec4 sun_top : source_color = vec4(1.0, 0.88, 0.25, 1.0);
uniform vec4 sun_bottom : source_color = vec4(1.0, 0.18, 0.55, 1.0);
uniform vec4 sky_top : source_color = vec4(0.04, 0.0, 0.1, 1.0);
uniform vec4 sky_bottom : source_color = vec4(0.42, 0.05, 0.36, 1.0);
uniform vec4 floor_colour : source_color = vec4(0.03, 0.0, 0.07, 1.0);
uniform float stars : hint_range(0.0, 1.0) = 0.4;
uniform int blend : hint_range(0, 7) = 0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
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
	if (how == 7) {
		float w = k * s * (1.0 - pic_a);
		return vec4(pc * pic_a + g * w, pic_a + w);
	}
	vec3 o = mix(pc, blend_colour(pc, g, how), k * s);
	return vec4(clamp(o, 0.0, 1.0) * pic_a, pic_a);
}

float grid_line(float v, float px_w) {
	float f = abs(fract(v - 0.5) - 0.5);
	float w = max(px_w, 0.0001);
	return 1.0 - smoothstep(w * 0.5, w * 0.5 + max(fwidth(v), 0.0001), f);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 sz = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float asp = sz.x / sz.y;
	float h = clamp(horizon, 0.05, 0.95);
	float y = UV.y;
	vec3 gen = vec3(0.0);
	float gl = clamp(glow, 0.0, 1.0);
	float lw = max(line_width, 0.1) * ps;
	if (y < h) {
		float k = clamp(y / h, 0.0, 1.0);
		gen = mix(sky_top.rgb, sky_bottom.rgb, k * k);
		vec2 cell = floor(UV * sz / (3.0 * ps));
		float st = hash12(cell);
		float tw = 0.6 + 0.4 * sin(clip_time * 3.0 + st * 40.0);
		float star = step(1.0 - 0.004 * clamp(stars, 0.0, 1.0), st) * (1.0 - k) * tw;
		gen += vec3(star);
		float rs = max(sun_size, 0.0);
		if (rs > 0.001) {
			vec2 sc = vec2(0.5, h - rs * 0.55);
			vec2 dsun = vec2((UV.x - sc.x) * asp, UV.y - sc.y);
			float dist = length(dsun);
			float v = clamp((UV.y - (sc.y - rs)) / (2.0 * rs), 0.0, 1.0);
			vec3 sun = mix(sun_top.rgb, sun_bottom.rgb, v);
			float band_y = (UV.y - sc.y) / rs;
			float gaps = 0.0;
			if (band_y > 0.0) {
				float bf = fract(band_y * 5.0);
				float gap_w = 0.1 + 0.45 * band_y;
				gaps = step(1.0 - gap_w, bf);
			}
			float aa = 1.5 / sz.y;
			float disc = (1.0 - smoothstep(rs - aa, rs + aa, dist)) * (1.0 - gaps);
			gen = mix(gen, sun, disc);
			gen += sun_bottom.rgb * gl * 0.35 * exp(-max(dist - rs, 0.0) * 14.0) * (1.0 - disc);
		}
	} else {
		float dy = max(y - h, 0.0001);
		float z = 0.18 / dy;
		float wx = (UV.x - 0.5) * asp * z * 2.2;
		float wz = z + clip_time * speed * 2.0;
		float px_w = lw / sz.y;
		float lx = grid_line(wx, px_w * z * 2.2);
		float lz = grid_line(wz, px_w * z * z / 0.18);
		float line = max(lx, lz);
		float fade = exp(-z * 0.12);
		gen = floor_colour.rgb;
		gen += grid_colour.rgb * line * (0.4 + 0.6 * fade);
		float halo = max(grid_line(wx, px_w * z * 9.0), grid_line(wz, px_w * z * z * 5.0));
		gen += grid_colour.rgb * halo * gl * 0.25 * fade;
	}
	gen += grid_colour.rgb * gl * 0.6 * exp(-abs(y - h) * sz.y / (18.0 * ps + 1.0));
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	COLOR = mix_in(rgb, c.a, gen, 1.0, blend, strength);
}
