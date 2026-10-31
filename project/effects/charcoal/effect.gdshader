shader_type canvas_item;
render_mode blend_disabled;

uniform float thickness : hint_range(1.0, 12.0) = 4.0;
uniform float detail : hint_range(0.0, 5.0) = 5.0;
uniform float balance : hint_range(0.0, 100.0) = 50.0;
uniform float angle : hint_range(-180.0, 180.0) = 45.0;
uniform vec4 charcoal_colour : source_color = vec4(0.08, 0.08, 0.09, 1.0);
uniform vec4 paper : source_color = vec4(0.95, 0.94, 0.9, 1.0);
uniform int seed : hint_range(0, 9999) = 0;
uniform vec2 tex_size = vec2(1.0, 1.0);
uniform float px_scale = 1.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 seed_offset(int s) {
	float f = float(s);
	return vec2(mod(f * 12.9898, 997.0), mod(f * 78.233, 991.0));
}

float lum(vec4 c) {
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	return dot(rgb, vec3(0.2126, 0.7152, 0.0722));
}

#define L(o) lum(texture(TEXTURE, UV + (o)))

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	float a = texture(TEXTURE, UV).a;
	vec2 so = seed_offset(seed);
	vec2 pix = UV * dims / ps;
	float t = max(thickness, 1.0);
	float ang = radians(angle);
	vec2 dir = vec2(cos(ang), -sin(ang));
	vec2 su = dir * t * ps / dims;
	float tone = 0.0;
	for (int i = -3; i <= 3; i++) {
		tone += L(su * float(i) * 0.9);
	}
	tone /= 7.0;
	vec2 d = vec2(max(t * 0.5, 1.0) * ps) / dims;
	float gx = L(vec2(d.x, 0.0)) - L(vec2(-d.x, 0.0));
	float gy = L(vec2(0.0, d.y)) - L(vec2(0.0, -d.y));
	float edge = smoothstep(0.08, 0.35, length(vec2(gx, gy)) * (0.2 + detail * 0.2));
	float along = dot(pix, dir);
	float across = dot(pix, vec2(-dir.y, dir.x));
	float streak = value_noise(vec2(along / (t * 7.0), across / (t * 0.4)) + so) * 0.65 + value_noise(vec2(along / (t * 3.0), across / (t * 0.3)) + so.yx + 7.3) * 0.35;
	float tooth = value_noise(pix / 1.4 + so * 0.3) * 0.6 + value_noise(pix / 3.5 + 11.0) * 0.4;
	float thr = 0.12 + balance / 100.0 * 0.5;
	float dark = smoothstep(0.3, 0.85, (thr - tone) * 1.8 + streak * 0.75 + tooth * 0.2);
	float line = edge * smoothstep(0.15, 0.55, streak * 0.6 + tooth * 0.5);
	float cover = clamp(max(dark, line), 0.0, 1.0);
	cover *= mix(0.55, 1.0, smoothstep(0.25, 0.65, tooth * 0.6 + streak * 0.4 + cover * 0.25));
	vec3 paper_c = paper.rgb * (0.96 + 0.04 * tooth);
	vec3 outc = mix(paper_c, charcoal_colour.rgb, cover);
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
