shader_type canvas_item;
render_mode blend_disabled;

uniform float pencil_width : hint_range(1.0, 24.0) = 4.0;
uniform float stroke_pressure : hint_range(0.0, 15.0) = 8.0;
uniform float paper_brightness : hint_range(0.0, 50.0) = 25.0;
uniform float angle : hint_range(-180.0, 180.0) = 45.0;
uniform vec4 paper : source_color = vec4(0.97, 0.96, 0.93, 1.0);
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

vec3 unpremul(vec4 c) {
	return c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
}

float hatch(vec2 p, float w, float ang, vec2 so) {
	vec2 dir = vec2(cos(ang), -sin(ang));
	float along = dot(p, dir);
	float across = dot(p, vec2(-dir.y, dir.x));
	float s = across / w;
	float lane = floor(s);
	float f = fract(s);
	float prof = 1.0 - smoothstep(0.18, 0.46, abs(f - 0.5));
	float seg = value_noise(vec2(along / (w * 7.0) + hash12(vec2(lane, so.x)) * 37.0, lane * 1.37 + so.y));
	float grain = value_noise(vec2(along / 1.6, across / 0.8) + so * 0.5);
	return prof * smoothstep(0.15, 0.75, seg) * (0.7 + 0.3 * grain);
}

void fragment() {
	vec2 dims = max(tex_size, vec2(1.0));
	float ps = max(px_scale, 0.0001);
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec2 so = seed_offset(seed);
	vec2 pix = UV * dims / ps;
	float ang = radians(angle);
	vec2 dir = vec2(cos(ang), -sin(ang));
	vec2 step_uv = dir * pencil_width * ps / dims;
	vec3 sc = vec3(0.0);
	for (int i = -2; i <= 2; i++) {
		sc += unpremul(texture(TEXTURE, UV + step_uv * float(i) * 0.6));
	}
	sc /= 5.0;
	vec3 wl = vec3(0.2126, 0.7152, 0.0722);
	vec2 e = vec2(ps * 1.5) / dims;
	float gx = dot(unpremul(texture(TEXTURE, UV + vec2(e.x, 0.0))) - unpremul(texture(TEXTURE, UV - vec2(e.x, 0.0))), wl);
	float gy = dot(unpremul(texture(TEXTURE, UV + vec2(0.0, e.y))) - unpremul(texture(TEXTURE, UV - vec2(0.0, e.y))), wl);
	float edge = smoothstep(0.06, 0.3, length(vec2(gx, gy)));
	float lum = dot(sc, wl);
	float dk = 1.0 - lum;
	float press = 0.35 + stroke_pressure / 15.0 * 1.5;
	float w = max(pencil_width, 1.0);
	float h1 = hatch(pix, w, ang, so);
	float h2 = hatch(pix + 0.5 * w, w * 0.9, ang - 1.5708 + 0.35, so + 17.0);
	float cov1 = smoothstep(0.1, 0.6, h1 * (dk * press + 0.22));
	float cov2 = smoothstep(0.1, 0.6, h2 * max(dk - 0.4, 0.0) * 1.6 * press);
	float cov = clamp(cov1 + cov2 * (1.0 - cov1), 0.0, 1.0);
	vec3 pencil = clamp(mix(vec3(lum), sc, 1.25) * mix(1.0, 0.82, dk), 0.0, 1.0);
	float tooth = value_noise(pix / 1.2 + so);
	vec3 paper_c = paper.rgb * mix(0.7, 1.0, paper_brightness / 50.0) * (0.97 + 0.03 * tooth);
	vec3 outc = mix(paper_c, pencil, cov);
	float outline = edge * smoothstep(0.2, 0.7, h1 + 0.35);
	outc = mix(outc, pencil * 0.55, outline * 0.75);
	COLOR = vec4(clamp(outc, 0.0, 1.0) * a, a);
}
